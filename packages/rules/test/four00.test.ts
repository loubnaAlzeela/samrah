import { describe, expect, it } from 'vitest';
import {
  type Card,
  type GameState,
  type Seat,
  act,
  advance,
  autoAction,
  four00MinBid,
  four00MinTotal,
  fullDeck,
  hasTeams,
  isVariant,
  mergeSettings,
  DEFAULT_SETTINGS,
  minBid,
  newAnyGame,
  newGame,
  scoreFour00Seat,
  startHand,
  syrianAutoBid,
  viewFor,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(400);
const MIXED: Card[][] = [0, 1, 2, 3].map((i) => fullDeck().filter((_, k) => k % 4 === i));

function ok(r: ReturnType<typeof act>): GameState {
  if (!r.ok) throw new Error(r.error);
  return r.state;
}
function err(r: ReturnType<typeof act>): string {
  return r.ok ? 'ok' : r.error;
}

/** a 400 hand dealt by `dealer` with exact hands and running scores */
function game400(dealer: Seat = 3, seatScores = [0, 0, 0, 0], hands = MIXED): GameState {
  const g = newGame({ variant: 'tarneeb400', dealer }, rng);
  return startHand({ ...g, handNo: 0, seatScores: seatScores as GameState['seatScores'] }, rng, dealer, {
    hands,
    lastCardOfDealer: hands[dealer][12],
  });
}

describe('400: scoring table', () => {
  it('under 30: 2,3,4 at face value; 5→10, 6→12, 7→14, 8→16, 9→27, 10..13→40', () => {
    const expected: Record<number, number> = { 2: 2, 3: 3, 4: 4, 5: 10, 6: 12, 7: 14, 8: 16, 9: 27, 10: 40, 11: 40, 12: 40, 13: 40 };
    for (const [bid, value] of Object.entries(expected)) {
      expect(scoreFour00Seat(Number(bid), Number(bid), 0)).toBe(value); // made exactly
      expect(scoreFour00Seat(Number(bid), 13, 29)).toBe(value); // made with extra tricks: still the bid's value
      expect(scoreFour00Seat(Number(bid), Number(bid) - 1, 0)).toBe(-value); // failed: minus the same value
    }
  });
  it('from 30 points (the player himself): 5 and 6 score at face value, the rest unchanged', () => {
    expect(scoreFour00Seat(5, 5, 30)).toBe(5);
    expect(scoreFour00Seat(6, 7, 35)).toBe(6);
    expect(scoreFour00Seat(5, 4, 30)).toBe(-5);
    expect(scoreFour00Seat(7, 7, 30)).toBe(14);
    expect(scoreFour00Seat(9, 9, 45)).toBe(27);
    expect(scoreFour00Seat(10, 10, 50)).toBe(40);
    // a player still under 30 keeps the full table even when others are above it
    expect(scoreFour00Seat(5, 5, 29)).toBe(10);
  });
  it('rejects impossible bids', () => {
    expect(() => scoreFour00Seat(1, 0, 0)).toThrow();
    expect(() => scoreFour00Seat(14, 13, 0)).toThrow();
  });
});

describe('400: bidding limits', () => {
  it('minimum bid by the player\'s own score: 2, then 3 (30–39), 4 (40–49), 5 (50+)', () => {
    expect([0, 29, 30, 39, 40, 49, 50, 80, -10].map(four00MinBid)).toEqual([2, 2, 3, 3, 4, 4, 5, 5, 2]);
  });
  it('minimum total by the highest score at the table: 11, then 12 (30+), 13 (40+), 14 (50+)', () => {
    expect(four00MinTotal([0, 0, 0, 0])).toBe(11);
    expect(four00MinTotal([10, 29, -5, 0])).toBe(11);
    expect(four00MinTotal([10, 31, -5, 0])).toBe(12);
    expect(four00MinTotal([45, 31, -5, 0])).toBe(13);
    expect(four00MinTotal([45, 31, 52, 0])).toBe(14);
  });
  it('a seat may not bid under its own minimum; others keep theirs', () => {
    // dealer 3 -> seat 0 bids first; seat 0 has 42 (min 4), seat 1 has 12 (min 2)
    let s = game400(3, [42, 12, 0, 0]);
    expect(s.turn).toBe(0);
    expect(minBid(s)).toBe(4);
    expect(err(act(s, 0, { type: 'bid', value: 3 }))).toBe('badBid');
    s = ok(act(s, 0, { type: 'bid', value: 4 }));
    expect(minBid(s)).toBe(2);
    s = ok(act(s, 1, { type: 'bid', value: 2 }));
    expect(s.turn).toBe(2);
  });
  it('the minimum is shown to the bidder in their view', () => {
    const s = game400(3, [33, 0, 0, 0]);
    expect(viewFor(s, 0).minBid).toBe(3);
    expect(viewFor(s, 1).minBid).toBeNull(); // not their turn
  });
  it('bids under the table minimum total are redealt (12 when someone has 30+)', () => {
    let s = game400(3, [31, 0, 0, 0]);
    for (const [seat, v] of [[0, 3], [1, 3], [2, 2], [3, 3]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    expect(s.phase).toBe('handOver');
    expect(s.lastResult?.note).toBe('lowBids');
    expect(advance(s, rng).dealer).toBe(0); // the deal moves on
    // the same bids plus one reach 12 and are played
    s = game400(3, [31, 0, 0, 0]);
    for (const [seat, v] of [[0, 3], [1, 3], [2, 3], [3, 3]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(0); // the player right of the dealer leads
  });
});

describe('400: the hand', () => {
  it('hearts are always trump, with no turned-up card; target is 41', () => {
    for (let n = 0; n < 5; n++) {
      const g = newGame({ variant: 'tarneeb400', target: 61 }, seeded(n));
      expect(g.trump).toBe('H');
      expect(g.revealed).toBeNull();
      expect(g.target).toBe(41);
      expect(g.hands.every((h) => h.length === 13)).toBe(true);
    }
  });
  it('scores each seat with the 400 table after the last trick', () => {
    // seat 0 holds every heart: it takes 13 tricks; everyone else takes none
    const hearts = fullDeck().filter((c) => c.startsWith('H'));
    const rest = fullDeck().filter((c) => !c.startsWith('H'));
    const hands = [hearts, rest.slice(0, 13), rest.slice(13, 26), rest.slice(26, 39)];
    let s = game400(3, [0, 0, 0, 0], hands);
    // seat 0 bids 5 (made: +10), the others 2 each (failed: −2): total 11
    for (const [seat, v] of [[0, 5], [1, 2], [2, 2], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    while (s.phase !== 'handOver' && s.phase !== 'gameOver') {
      s = s.phase === 'trickDone' ? advance(s, rng) : ok(act(s, s.turn, autoAction(s, s.turn)));
    }
    expect(s.tricks).toEqual([13, 0, 0, 0]);
    expect(s.lastResult?.seatDelta).toEqual([10, -2, -2, -2]);
    expect(s.seatScores).toEqual([10, -2, -2, -2]);
    expect(s.teamScores).toEqual([8, -4]);
  });
  it('a team wins when one player reaches 41 and the partner is above 0', () => {
    // seat 0 on 35 bids 6 (worth 6 from 30) and makes it -> 41; partner (seat 2) on 3 -> team 0 wins
    const hearts = fullDeck().filter((c) => c.startsWith('H'));
    const rest = fullDeck().filter((c) => !c.startsWith('H'));
    const hands = [hearts, rest.slice(0, 13), rest.slice(13, 26), rest.slice(26, 39)];
    let s = game400(3, [35, 0, 5, 0], hands);
    for (const [seat, v] of [[0, 6], [1, 2], [2, 2], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    while (s.phase !== 'handOver' && s.phase !== 'gameOver') {
      s = s.phase === 'trickDone' ? advance(s, rng) : ok(act(s, s.turn, autoAction(s, s.turn)));
    }
    expect(s.seatScores).toEqual([41, -2, 3, -2]);
    expect(s.phase).toBe('gameOver');
    expect(s.winner).toBe(0);
  });
  it('no win while the partner is at 0 or below', () => {
    const hearts = fullDeck().filter((c) => c.startsWith('H'));
    const rest = fullDeck().filter((c) => !c.startsWith('H'));
    const hands = [hearts, rest.slice(0, 13), rest.slice(13, 26), rest.slice(26, 39)];
    let s = game400(3, [35, 0, 2, 0], hands); // partner will drop to 0
    for (const [seat, v] of [[0, 6], [1, 2], [2, 2], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    while (s.phase !== 'handOver' && s.phase !== 'gameOver') {
      s = s.phase === 'trickDone' ? advance(s, rng) : ok(act(s, s.turn, autoAction(s, s.turn)));
    }
    expect(s.seatScores).toEqual([41, -2, 0, -2]);
    expect(s.winner).toBeNull();
    expect(s.phase).toBe('handOver');
  });
});

describe('400: autopilot and wiring', () => {
  it('the autopilot never bids under the seat\'s minimum and tops up to the table minimum', () => {
    let s = game400(3, [52, 0, 0, 0]); // seat 0 must bid 5+, the total must reach 14
    expect(syrianAutoBid(s, 0)).toBeGreaterThanOrEqual(5);
    for (const seat of [0, 1, 2] as Seat[]) s = ok(act(s, seat, autoAction(s, seat)));
    const sum = (s.seatBids as number[]).slice(0, 3).reduce((a, b) => a + b, 0);
    expect(sum + syrianAutoBid(s, 3)).toBeGreaterThanOrEqual(14);
  });
  it('4 autopilots play 20 full games, every move legal', { timeout: 60_000 }, () => {
    const r = seeded(4000);
    for (let n = 0; n < 20; n++) {
      let s = newGame({ variant: 'tarneeb400' }, r);
      for (let steps = 0; s.phase !== 'gameOver'; steps++) {
        if (steps > 80_000) throw new Error('did not finish');
        if (s.phase === 'trickDone' || s.phase === 'handOver') {
          s = advance(s, r);
          expect(s.trump === 'H' || s.phase === 'gameOver').toBe(true);
          continue;
        }
        const res = act(s, s.turn, autoAction(s, s.turn));
        if (!res.ok) throw new Error(res.error);
        s = res.state;
      }
      expect(s.winner).not.toBeNull();
    }
  });
  it('is a known variant with teams, created through the common entry point, target fixed at 41', () => {
    expect(isVariant('tarneeb400')).toBe(true);
    expect(hasTeams('tarneeb400')).toBe(true);
    const g = newAnyGame({ variant: 'tarneeb400', target: 61 }, rng) as GameState;
    expect(g.variant).toBe('tarneeb400');
    expect(g.target).toBe(41);
    expect(mergeSettings(DEFAULT_SETTINGS, { target: 61 }, 'tarneeb400')!.target).toBe(41);
  });
});
