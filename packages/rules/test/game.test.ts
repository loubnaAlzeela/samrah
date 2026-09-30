import { describe, expect, it } from 'vitest';
import {
  type Card,
  type GameState,
  type Seat,
  act,
  advance,
  fullDeck,
  legalCards,
  newGame,
  startHand,
  viewFor,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(42);

/** seat0 = all spades, seat1 = all hearts, seat2 = all diamonds, seat3 = all clubs */
const SUITED: Card[][] = ['S', 'H', 'D', 'C'].map((s) => fullDeck().filter((c) => c[0] === s));
/** dealt round-robin from an ordered deck: every seat holds mixed suits */
const MIXED: Card[][] = [0, 1, 2, 3].map((i) => fullDeck().filter((_, k) => k % 4 === i));

function ok(r: ReturnType<typeof act>): GameState {
  if (!r.ok) throw new Error('expected ok, got ' + r.error);
  return r.state;
}
function err(r: ReturnType<typeof act>): string {
  if (r.ok) throw new Error('expected an error');
  return r.error;
}
function tarneebWith(hands: Card[][], dealer: Seat = 3, scores: [number, number] = [0, 0], target = 41): GameState {
  const g = newGame({ variant: 'tarneeb', target, dealer }, rng);
  return startHand({ ...g, handNo: 0, teamScores: scores }, rng, dealer, { hands, lastCardOfDealer: hands[dealer][0] });
}
/** Play the rest of the hand choosing the first legal card each time. */
function playOut(s: GameState): GameState {
  let guard = 0;
  while (s.phase === 'playing' || s.phase === 'trickDone') {
    if (guard++ > 200) throw new Error('loop');
    if (s.phase === 'trickDone') {
      s = advance(s, rng);
      continue;
    }
    const legal = legalCards(s.hands[s.turn], s.trick);
    s = ok(act(s, s.turn, { type: 'play', card: legal[0] }));
  }
  return s;
}

describe('Tarneeb: bidding', () => {
  it('bidding starts with the player to the right of the dealer', () => {
    expect(tarneebWith(MIXED, 3).turn).toBe(0);
    expect(tarneebWith(MIXED, 1).turn).toBe(2);
  });
  it('rejects out-of-turn, below 7, above 13 and non-increasing bids', () => {
    let s = tarneebWith(MIXED, 3);
    expect(err(act(s, 1, { type: 'bid', value: 7 }))).toBe('notYourTurn');
    expect(err(act(s, 0, { type: 'bid', value: 6 }))).toBe('badBid');
    expect(err(act(s, 0, { type: 'bid', value: 14 }))).toBe('badBid');
    expect(err(act(s, 0, { type: 'bid', value: 7.5 }))).toBe('badBid');
    s = ok(act(s, 0, { type: 'bid', value: 8 }));
    expect(err(act(s, 1, { type: 'bid', value: 8 }))).toBe('badBid');
    expect(err(act(s, 1, { type: 'bid', value: 7 }))).toBe('badBid');
    s = ok(act(s, 1, { type: 'bid', value: 9 }));
    expect(s.highBid).toEqual({ seat: 1, value: 9 });
  });
  it('a pass is final: the passed player is skipped afterwards', () => {
    let s = tarneebWith(MIXED, 3);
    s = ok(act(s, 0, { type: 'bid', value: 7 }));
    s = ok(act(s, 1, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 2, { type: 'bid', value: 8 }));
    s = ok(act(s, 3, { type: 'bid', value: 9 }));
    expect(s.turn).toBe(0);
    s = ok(act(s, 0, { type: 'bid', value: 10 }));
    expect(s.turn).toBe(2); // seat 1 skipped
  });
  it('auction ends when everyone else has passed; winner picks trump and leads', () => {
    let s = tarneebWith(MIXED, 3);
    s = ok(act(s, 0, { type: 'bid', value: 7 }));
    s = ok(act(s, 1, { type: 'bid', value: 8 }));
    s = ok(act(s, 2, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 3, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 0, { type: 'bid', value: 'pass' }));
    expect(s.phase).toBe('trump');
    expect(s.turn).toBe(1);
    expect(err(act(s, 1, { type: 'play', card: s.hands[1][0] }))).toBe('wrongPhase');
    expect(err(act(s, 1, { type: 'trump', suit: 'X' as never }))).toBe('badSuit');
    s = ok(act(s, 1, { type: 'trump', suit: 'H' }));
    expect(s.trump).toBe('H');
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(1);
  });
  it('a bid of 13 closes the auction immediately', () => {
    let s = tarneebWith(MIXED, 3);
    s = ok(act(s, 0, { type: 'bid', value: 13 }));
    expect(s.phase).toBe('trump');
    expect(s.turn).toBe(0);
  });
  it('all four pass: redeal, scores unchanged, deal moves to the next dealer', () => {
    let s = tarneebWith(MIXED, 3, [5, 9]);
    for (const seat of [0, 1, 2, 3] as Seat[]) s = ok(act(s, seat, { type: 'bid', value: 'pass' }));
    expect(s.phase).toBe('handOver');
    expect(s.lastResult?.kind).toBe('redeal');
    expect(s.lastResult?.note).toBe('allPass');
    const n = advance(s, rng);
    expect(n.dealer).toBe(0);
    expect(n.turn).toBe(1);
    expect(n.handNo).toBe(s.handNo + 1);
    expect(n.teamScores).toEqual([5, 9]);
    expect(n.phase).toBe('bidding');
    expect(n.hands.map((h) => h.length)).toEqual([13, 13, 13, 13]);
  });
});

describe('Tarneeb: play', () => {
  it('must follow suit when able; card must be in hand; only the player to act may play', () => {
    let s = tarneebWith(MIXED, 3);
    s = ok(act(s, 0, { type: 'bid', value: 13 }));
    s = ok(act(s, 0, { type: 'trump', suit: 'C' }));
    expect(err(act(s, 0, { type: 'play', card: s.hands[1][0] }))).toBe('notInHand');
    expect(err(act(s, 0, { type: 'play', card: 'ZZ' }))).toBe('badCard');
    s = ok(act(s, 0, { type: 'play', card: 'S14' }));
    expect(err(act(s, 2, { type: 'play', card: s.hands[2][0] }))).toBe('notYourTurn');
    const offSuit = s.hands[1].find((c) => c[0] !== 'S')!;
    expect(err(act(s, 1, { type: 'play', card: offSuit }))).toBe('mustFollowSuit');
    const spade = s.hands[1].find((c) => c[0] === 'S')!;
    s = ok(act(s, 1, { type: 'play', card: spade }));
    expect(s.turn).toBe(2);
  });
  it('trick winner leads the next trick; trump cuts', () => {
    // seat1 bids, trump = spades (held only by seat0, a defender). seat1 leads hearts, seat0 cuts every time.
    let s = tarneebWith(SUITED, 0);
    s = ok(act(s, 1, { type: 'bid', value: 7 }));
    for (const seat of [2, 3, 0] as Seat[]) s = ok(act(s, seat, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 1, { type: 'trump', suit: 'S' }));
    s = ok(act(s, 1, { type: 'play', card: 'H14' }));
    s = ok(act(s, 2, { type: 'play', card: 'D14' }));
    s = ok(act(s, 3, { type: 'play', card: 'C14' }));
    s = ok(act(s, 0, { type: 'play', card: 'S2' }));
    expect(s.phase).toBe('trickDone');
    expect(err(act(s, 0, { type: 'play', card: 'S3' }))).toBe('wrongPhase');
    s = advance(s, rng);
    expect(s.lastTrick?.winner).toBe(0);
    expect(s.turn).toBe(0);
    expect(s.tricks).toEqual([1, 0, 0, 0]);
    // finish: defenders take all 13 -> bidders -7, defenders +13
    s = playOut(s);
    expect(s.tricks).toEqual([13, 0, 0, 0]);
    expect(s.teamScores).toEqual([13, -7]);
    expect(s.lastResult?.note).toBe('fail');
    expect(s.phase).toBe('handOver');
  });
  it('bid 13 and take all 13: +26', () => {
    let s = tarneebWith(SUITED, 0);
    s = ok(act(s, 1, { type: 'bid', value: 13 }));
    s = ok(act(s, 1, { type: 'trump', suit: 'H' }));
    s = playOut(s);
    expect(s.teamScores).toEqual([0, 26]);
    expect(s.lastResult?.note).toBe('kaboot13');
  });
  it('kaboot after bidding 8: +16 and reaching the target ends the game', () => {
    let s = tarneebWith(SUITED, 3, [30, 0], 41);
    s = ok(act(s, 0, { type: 'bid', value: 8 }));
    for (const seat of [1, 2, 3] as Seat[]) s = ok(act(s, seat, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 0, { type: 'trump', suit: 'S' }));
    s = playOut(s);
    expect(s.lastResult?.note).toBe('kaboot');
    expect(s.teamScores).toEqual([46, 0]);
    expect(s.phase).toBe('gameOver');
    expect(s.winner).toBe(0);
    expect(err(act(s, s.turn, { type: 'bid', value: 7 }))).toBe('gameOver');
    expect(advance(s, rng)).toBe(s);
  });
  it('partner cuts every trick: team takes all 13 after bidding 7 -> kaboot +16', () => {
    // seat0 bids 7 with trump D (seat2 = partner holds all diamonds). seat0 leads spades; seat2 cuts.
    let s = tarneebWith(SUITED, 3);
    s = ok(act(s, 0, { type: 'bid', value: 7 }));
    for (const seat of [1, 2, 3] as Seat[]) s = ok(act(s, seat, { type: 'bid', value: 'pass' }));
    s = ok(act(s, 0, { type: 'trump', suit: 'D' }));
    s = playOut(s);
    expect(s.tricks[0] + s.tricks[2]).toBe(13);
    expect(s.teamScores).toEqual([16, 0]); // 13 tricks without bidding 13 -> kaboot bonus
  });
  it('bid 13 and fail: -16, defenders get their tricks', () => {
    // seat1 bids 13 but names spades as trump, which only defender seat0 holds: seat0 wins every trick.
    let s = tarneebWith(SUITED, 0);
    s = ok(act(s, 1, { type: 'bid', value: 13 }));
    s = ok(act(s, 1, { type: 'trump', suit: 'S' }));
    s = playOut(s);
    expect(s.lastResult?.note).toBe('fail13');
    expect(s.teamScores).toEqual([13, -16]);
  });
  it('next hand: dealer moves to the right, scores carry over', () => {
    let s = tarneebWith(SUITED, 0);
    s = ok(act(s, 1, { type: 'bid', value: 13 }));
    s = ok(act(s, 1, { type: 'trump', suit: 'H' }));
    s = playOut(s);
    const n = advance(s, rng);
    expect(n.dealer).toBe(1);
    expect(n.turn).toBe(2);
    expect(n.teamScores).toEqual([0, 26]);
    expect(n.trump).toBeNull();
    expect(n.tricks).toEqual([0, 0, 0, 0]);
  });
});

describe('Syrian 41', () => {
  function syrianWith(hands: Card[][], revealed: Card, dealer: Seat = 3, seatScores = [0, 0, 0, 0]): GameState {
    const g = newGame({ variant: 'syrian41', dealer }, rng);
    return startHand({ ...g, handNo: 0, seatScores: seatScores as GameState['seatScores'] }, rng, dealer, {
      hands,
      lastCardOfDealer: revealed,
    });
  }
  it('target is always 41 and the revealed card sets the sister-suit trump', () => {
    const g = newGame({ variant: 'syrian41', target: 61 }, rng);
    expect(g.target).toBe(41);
    expect(g.revealed).not.toBeNull();
    expect(g.hands[g.dealer]).toContain(g.revealed);
    const s = syrianWith(MIXED, 'H5');
    expect(s.trump).toBe('D');
    expect(syrianWith(MIXED, 'C9').trump).toBe('S');
  });
  it('each player bids once, 2..13, no pass; starts right of the dealer', () => {
    let s = syrianWith(MIXED, 'H5', 3);
    expect(s.turn).toBe(0);
    expect(err(act(s, 0, { type: 'bid', value: 'pass' }))).toBe('badBid');
    expect(err(act(s, 0, { type: 'bid', value: 1 }))).toBe('badBid');
    expect(err(act(s, 0, { type: 'bid', value: 14 }))).toBe('badBid');
    expect(err(act(s, 0, { type: 'trump', suit: 'S' }))).toBe('wrongPhase');
    s = ok(act(s, 0, { type: 'bid', value: 2 }));
    s = ok(act(s, 1, { type: 'bid', value: 2 })); // bids need not increase
    expect(s.turn).toBe(2);
  });
  it('total bids below 11: redeal', () => {
    let s = syrianWith(MIXED, 'H5', 3);
    for (const [seat, v] of [[0, 2], [1, 3], [2, 2], [3, 3]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    expect(s.phase).toBe('handOver');
    expect(s.lastResult?.note).toBe('lowBids');
    expect(advance(s, rng).dealer).toBe(0);
  });
  it('total exactly 11: play starts with the player right of the dealer; per-player scoring', () => {
    let s = syrianWith(SUITED, 'H5', 3); // trump D -> seat2 holds every trump
    for (const [seat, v] of [[0, 3], [1, 3], [2, 3], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(0);
    s = playOut(s);
    expect(s.tricks).toEqual([0, 0, 13, 0]);
    expect(s.seatScores).toEqual([-3, -3, 3, -2]);
    expect(s.lastResult?.seatDelta).toEqual([-3, -3, 3, -2]);
  });
  it('reaching 41 with a partner at or below 0 does NOT end the game', () => {
    let s = syrianWith(SUITED, 'H5', 3, [0, 0, 39, 0]);
    for (const [seat, v] of [[0, 3], [1, 3], [2, 3], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    s = playOut(s);
    expect(s.seatScores[2]).toBe(42);
    expect(s.seatScores[0]).toBe(-3);
    expect(s.phase).toBe('handOver');
    expect(s.winner).toBeNull();
  });
  it('reaching 41 with a positive partner wins', () => {
    let s = syrianWith(SUITED, 'H5', 3, [5, 0, 39, 0]);
    for (const [seat, v] of [[0, 3], [1, 3], [2, 3], [3, 2]] as [Seat, number][]) s = ok(act(s, seat, { type: 'bid', value: v }));
    s = playOut(s);
    expect(s.phase).toBe('gameOver');
    expect(s.winner).toBe(0);
  });
});

describe('random full games (invariants + no hidden-card leak in views)', () => {
  for (const variant of ['tarneeb', 'syrian41'] as const) {
    it(`${variant}: 40 random games finish with consistent scores`, { timeout: 90_000 }, () => {
      const r = seeded(variant === 'tarneeb' ? 7 : 8);
      for (let g = 0; g < 40; g++) {
        let s = newGame({ variant, target: 31 }, r);
        let steps = 0;
        while (s.phase !== 'gameOver') {
          if (steps++ > 100000) throw new Error('game did not finish');
          if (s.phase === 'trickDone' || s.phase === 'handOver') {
            s = advance(s, r);
            continue;
          }
          // leak check: each seat's view must not contain any card from another seat's hand
          for (const seat of [0, 1, 2, 3] as Seat[]) {
            const json = JSON.stringify(viewFor(s, seat));
            expect(json).not.toContain('"hands"');
            const seen = new Set(json.match(/"[SHDC](?:[2-9]|1[0-4])"/g)?.map((x) => x.slice(1, -1)) ?? []);
            for (const other of [0, 1, 2, 3] as Seat[]) {
              if (other === seat) continue;
              for (const c of s.hands[other]) {
                if (c === s.revealed) continue; // Syrian: the dealer's revealed card is public by rule
                if (seen.has(c)) throw new Error(`seat ${seat} view leaks ${c} of seat ${other}`);
              }
            }
          }
          const seat = s.turn;
          if (s.phase === 'bidding') {
            let v: number | 'pass';
            if (variant === 'tarneeb') {
              const min = s.highBid ? s.highBid.value + 1 : 7;
              // conservative random bidder so random games drift upward and finish
              v = min > 9 || r(3) === 0 ? 'pass' : min + r(Math.min(2, 10 - min));
            } else v = 2 + r(3);
            s = (act(s, seat, { type: 'bid', value: v }) as { state: GameState }).state;
          } else if (s.phase === 'trump') {
            s = (act(s, seat, { type: 'trump', suit: (['S', 'H', 'D', 'C'] as const)[r(4)] }) as { state: GameState }).state;
          } else {
            const legal = legalCards(s.hands[seat], s.trick);
            const res = act(s, seat, { type: 'play', card: legal[r(legal.length)] });
            if (!res.ok) throw new Error(res.error);
            s = res.state;
          }
          expect(s.hands.flat().length + s.trick.length + s.tricks.reduce((a, b) => a + b, 0) * 4).toBe(52);
        }
        expect(s.winner).not.toBeNull();
        if (variant === 'tarneeb') expect(s.teamScores[s.winner!]).toBeGreaterThanOrEqual(31);
        else expect(s.teamScores).toEqual([s.seatScores[0] + s.seatScores[2], s.seatScores[1] + s.seatScores[3]]);
      }
    });
  }
});
