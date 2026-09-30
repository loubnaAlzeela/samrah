import { describe, expect, it } from 'vitest';
import {
  type Card,
  type GameState,
  type Seat,
  act,
  advance,
  autoAction,
  fullDeck,
  legalCards,
  longestSuit,
  newGame,
  startHand,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(99);
const MIXED: Card[][] = [0, 1, 2, 3].map((i) => fullDeck().filter((_, k) => k % 4 === i));

/** A playing-phase state with a chosen hand for `seat`, a trump and the cards already on the table. */
function playing(hand: Card[], trick: { seat: Seat; card: Card }[], trump: 'S' | 'H' | 'D' | 'C' | null, seat: Seat = 0): GameState {
  const g = newGame({ variant: 'tarneeb', target: 41, dealer: 3 }, rng);
  return { ...g, phase: 'playing', trump, trick, turn: seat, hands: g.hands.map((h, i) => (i === seat ? hand : h)) };
}

describe('autopilot: bidding and trump', () => {
  it('tarneeb: always passes', () => {
    const g = newGame({ variant: 'tarneeb', target: 41, dealer: 3 }, rng);
    expect(autoAction(g, g.turn)).toEqual({ type: 'bid', value: 'pass' });
  });
  it('trump = longest suit', () => {
    expect(longestSuit(['S2', 'S3', 'S4', 'H14', 'H13', 'D2'])).toBe('S');
  });
  it('trump tie -> stronger suit (higher rank sum)', () => {
    expect(longestSuit(['S2', 'S3', 'H14', 'H13', 'D2'])).toBe('H');
  });
  it('as winning bidder picks trump through autoAction', () => {
    let s = newGame({ variant: 'tarneeb', target: 41, dealer: 3 }, rng);
    s = (act(s, 0, { type: 'bid', value: 7 }) as { state: GameState }).state;
    for (const seat of [1, 2, 3] as Seat[]) s = (act(s, seat, { type: 'bid', value: 'pass' }) as { state: GameState }).state;
    const a = autoAction(s, 0);
    expect(a).toEqual({ type: 'trump', suit: longestSuit(s.hands[0]) });
    expect(act(s, 0, a).ok).toBe(true);
  });
  it('syrian: aces + Q/K of trump, at least 2', () => {
    const g = newGame({ variant: 'syrian41', dealer: 3 }, rng);
    const hands = g.hands.map((h) => h.slice());
    hands[0] = ['S14', 'H14', 'D13', 'D12', 'D14', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9'];
    const s = startHand({ ...g, handNo: 0 }, rng, 3, { hands: [hands[0], ...MIXED.slice(1)] as Card[][], lastCardOfDealer: 'H5' }); // trump D
    expect(autoAction(s, 0)).toEqual({ type: 'bid', value: 5 }); // 3 aces + DK + DQ = 5 (max 5)
    const weak = { ...s, hands: s.hands.map((h, i) => (i === 0 ? ['C2', 'C3'] : h)) };
    expect(autoAction(weak, 0)).toEqual({ type: 'bid', value: 2 });
  });
  it('syrian: last bidder tops up to reach 11 (no endless redeals)', () => {
    let s = startHand({ ...newGame({ variant: 'syrian41', dealer: 3 }, rng), handNo: 0 }, rng, 3, { hands: MIXED, lastCardOfDealer: 'H5' });
    for (const [seat, v] of [[0, 2], [1, 3], [2, 2]] as [Seat, number][]) s = (act(s, seat, { type: 'bid', value: v }) as { state: GameState }).state;
    expect(autoAction(s, 3)).toEqual({ type: 'bid', value: 4 });
  });
});

describe('autopilot: play', () => {
  it('leading: cheapest card, non-trump first', () => {
    expect(autoAction(playing(['S2', 'H3', 'H14'], [], 'S'), 0)).toEqual({ type: 'play', card: 'H3' });
  });
  it('partner currently winning: cheapest legal card', () => {
    // seat 2 (partner of 0) leads H14; seat 3 plays H5; seat 0 must follow hearts -> plays lowest heart
    const s = playing(['H13', 'H4', 'S2'], [{ seat: 2, card: 'H14' }, { seat: 3, card: 'H5' }], 'S');
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'H4' });
  });
  it('opponent winning and can beat it: cheapest winning card', () => {
    const s = playing(['H13', 'H12', 'H4', 'S2'], [{ seat: 1, card: 'H11' }], 'S');
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'H12' });
  });
  it('cannot beat it: cheapest legal card', () => {
    const s = playing(['H3', 'H4', 'S2'], [{ seat: 1, card: 'H11' }], 'S');
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'H3' });
  });
  it('void in led suit: cuts with the lowest trump that wins', () => {
    const s = playing(['S5', 'S9', 'D2'], [{ seat: 1, card: 'H14' }], 'S');
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'S5' });
  });
  it('void, opponent already cut higher than all my trumps: throws cheapest (non-trump) card', () => {
    const s = playing(['S5', 'S9', 'D2'], [{ seat: 3, card: 'H14' }, { seat: 1, card: 'S12' }], 'S', 0);
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'D2' });
  });
  it('over-trumps with the cheapest trump that still wins', () => {
    const s = playing(['S5', 'S13', 'S14', 'D2'], [{ seat: 3, card: 'H14' }, { seat: 1, card: 'S12' }], 'S', 0);
    expect(autoAction(s, 0)).toEqual({ type: 'play', card: 'S13' });
  });
  it('deterministic: same state -> same move', () => {
    const s = playing(['H13', 'H12', 'H4', 'S2'], [{ seat: 1, card: 'H11' }], 'S');
    expect(autoAction(s, 0)).toEqual(autoAction(structuredClone(s), 0));
  });
});

describe('autopilot: full games are always legal and finish', () => {
  it('syrian41: 4 autopilots play 20 full games', { timeout: 60_000 }, () => {
    const r = seeded(5);
    for (let n = 0; n < 20; n++) {
      let s = newGame({ variant: 'syrian41' }, r);
      for (let steps = 0; s.phase !== 'gameOver'; steps++) {
        if (steps > 50_000) throw new Error('did not finish');
        if (s.phase === 'trickDone' || s.phase === 'handOver') {
          s = advance(s, r);
          continue;
        }
        const res = act(s, s.turn, autoAction(s, s.turn));
        if (!res.ok) throw new Error(res.error);
        s = res.state;
      }
      expect(s.winner).not.toBeNull();
    }
  });
  it('tarneeb: autopilot trump + play (random bids) over 30 games, every move legal', { timeout: 60_000 }, () => {
    const r = seeded(6);
    for (let n = 0; n < 30; n++) {
      let s = newGame({ variant: 'tarneeb', target: 31 }, r);
      for (let steps = 0; s.phase !== 'gameOver'; steps++) {
        if (steps > 50_000) throw new Error('did not finish');
        if (s.phase === 'trickDone' || s.phase === 'handOver') {
          s = advance(s, r);
          continue;
        }
        let a = autoAction(s, s.turn);
        if (s.phase === 'bidding') {
          const min = s.highBid ? s.highBid.value + 1 : 7;
          a = { type: 'bid', value: min > 9 || r(3) === 0 ? 'pass' : min };
        }
        if (a.type === 'play') expect(legalCards(s.hands[s.turn], s.trick)).toContain(a.card);
        const res = act(s, s.turn, a);
        if (!res.ok) throw new Error(res.error);
        s = res.state;
      }
      expect(s.winner).not.toBeNull();
    }
  });
});
