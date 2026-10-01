import { describe, expect, it } from 'vitest';
import {
  type B187Action,
  type B187State,
  B187_MATCH_LIMIT,
  B187_MIN_HAND_POINTS,
  act187,
  advance187,
  auto187Action,
  b187Deck,
  b187JustRevealed,
  b187Legal,
  b187Opponents,
  b187Points,
  b187TrickWinner,
  b187ViewFor,
  min187Bid,
  new187Game,
  start187Hand,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

function must(s: B187State, seat: number, a: B187Action): B187State {
  const r = act187(s, seat, a);
  if (!r.ok) throw new Error(r.error);
  return r.state;
}

/** Play autopilot moves until `stop` holds (or the hand needs the server to advance). */
function runUntil(s: B187State, stop: (s: B187State) => boolean, r = seeded(1)): B187State {
  for (let i = 0; i < 5000 && !stop(s); i++) {
    if (s.phase === 'trickDone' || s.phase === 'handOver') s = advance187(s, r);
    else s = must(s, s.turn, auto187Action(s, s.turn));
  }
  return s;
}

describe('187: cards and deal', () => {
  it('40 cards worth exactly 187 points (2♥ = 25)', () => {
    const deck = b187Deck();
    expect(deck).toHaveLength(40);
    expect(deck.reduce((a, c) => a + b187Points(c), 0)).toBe(187);
    expect(b187Points('H2')).toBe(25);
    expect(b187Points('S2')).toBe(10);
    expect(b187Points('D14')).toBe(11);
    expect(b187Points('C9')).toBe(0);
  });
  it('4 players: 9 each + 4 in the field; 5 players: 7 each + 5', () => {
    const four = new187Game({ players: 4 }, seeded(2));
    expect(four.hands.map((h) => h.length)).toEqual([9, 9, 9, 9]);
    expect(four.field).toHaveLength(4);
    const five = new187Game({ players: 5 }, seeded(2));
    expect(five.hands.map((h) => h.length)).toEqual([7, 7, 7, 7, 7]);
    expect(five.field).toHaveLength(5);
    expect(new Set([...five.hands.flat(), ...five.field]).size).toBe(40);
  });
  it('a deal where any hand holds under 12 points is thrown in and dealt again', () => {
    const worth = (h: string[]) => h.reduce((a, c) => a + b187Points(c as never), 0);
    let seen = 0;
    for (let seed = 0; seed < 60; seed++) {
      for (const players of [4, 5]) {
        const s = new187Game({ players }, seeded(seed));
        for (const h of s.hands) expect(worth(h)).toBeGreaterThanOrEqual(B187_MIN_HAND_POINTS);
        for (const r of s.redeals) {
          expect(r.short.length).toBeGreaterThan(0);
          for (const x of r.short) expect(x.points).toBeLessThan(B187_MIN_HAND_POINTS);
        }
        expect(b187ViewFor(s, 0).redeals).toEqual(s.redeals);
        seen += s.redeals.length;
      }
    }
    expect(seen).toBeGreaterThan(0); // some deal in 120 needed a redeal
  });
  it('the next hand forgets earlier redeals', () => {
    const s = new187Game({ players: 4 }, seeded(1));
    const next = start187Hand({ ...s, redeals: [{ short: [{ seat: 0, points: 4 }] }] }, seeded(2), 1);
    for (const r of next.redeals) expect(r.short.every((x) => x.points < 12)).toBe(true);
    expect(next.redeals).not.toContainEqual({ short: [{ seat: 0, points: 4 }] });
  });
});

describe('187: auction', () => {
  it('opens at 87, then 90, then at least +5; the player right of the dealer starts', () => {
    let s = new187Game({ players: 4, dealer: 0 }, seeded(3));
    expect(s.turn).toBe(1);
    expect(min187Bid(s)).toBe(87);
    expect(act187(s, 1, { type: 'bid', value: 86 })).toEqual({ ok: false, error: 'badBid' });
    s = must(s, 1, { type: 'bid', value: 87 });
    expect(min187Bid(s)).toBe(90);
    s = must(s, 2, { type: 'bid', value: 90 });
    expect(min187Bid(s)).toBe(95);
    expect(act187(s, 3, { type: 'bid', value: 93 })).toEqual({ ok: false, error: 'badBid' });
  });
  it('the field is face up for everyone once the bid reaches 140', () => {
    let s = new187Game({ players: 4, dealer: 0 }, seeded(4));
    s = must(s, 1, { type: 'bid', value: 135 });
    expect(b187ViewFor(s, 3).field).toEqual([]);
    s = must(s, 2, { type: 'bid', value: 140 });
    expect(b187ViewFor(s, 3).field).toEqual(s.field);    expect(b187JustRevealed(s)).toBe(true); // the table pauses on the face-up field
    s = must(s, 3, { type: 'bid', value: 'pass' });
    expect(b187JustRevealed(s)).toBe(false);
    expect(s.phase).toBe('bidding'); // reaching 140 does not end the auction
  });
  it('everyone else withdraws without a bid: the last one buys at 87 and takes the field', () => {
    let s = new187Game({ players: 4, dealer: 0 }, seeded(5));
    const field = s.field.slice();
    for (const seat of [1, 2, 3]) s = must(s, seat, { type: 'bid', value: 'pass' });
    expect(s.buyer).toBe(0);
    expect(s.highBid).toEqual({ seat: 0, value: 87 });
    expect(s.phase).toBe('give');
    expect(s.hands[0]).toHaveLength(13);
    for (const c of field) expect(s.hands[0]).toContain(c);
  });
  it('a bid of 187 ends the auction at once', () => {
    let s = new187Game({ players: 5, dealer: 0 }, seeded(6));
    s = must(s, 1, { type: 'bid', value: 187 });
    expect(s.phase).toBe('give');
    expect(s.buyer).toBe(1);
  });
});

describe('187: give back and trump', () => {
  it('the buyer gives one card to each opponent, in turn order; the player right of the dealer leads', () => {
    let s = new187Game({ players: 4, dealer: 0 }, seeded(7));
    s = must(s, 1, { type: 'bid', value: 'pass' });
    s = must(s, 2, { type: 'bid', value: 100 });
    for (const seat of [3, 0]) s = must(s, seat, { type: 'bid', value: 'pass' });
    expect(s.buyer).toBe(2);
    const give = s.hands[2].slice(0, 3);
    expect(act187(s, 2, { type: 'give', cards: give.slice(0, 2) })).toEqual({ ok: false, error: 'badGive' });
    s = must(s, 2, { type: 'give', cards: give });
    expect(b187Opponents(s)).toEqual([3, 0, 1]);
    expect(s.hands[3]).toContain(give[0]);
    expect(s.hands[0]).toContain(give[1]);
    expect(s.hands[1]).toContain(give[2]);
    expect(s.hands.map((h) => h.length)).toEqual([10, 10, 10, 10]);
    expect(s.phase).toBe('trump');
    s = must(s, 2, { type: 'trump', suit: 'S' });
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(1); // right of the dealer, not the buyer
  });
  it('5 players: the buyer ends with 8 cards like everyone else', () => {
    let s = new187Game({ players: 5, dealer: 2 }, seeded(8));
    s = must(s, 3, { type: 'bid', value: 187 });
    expect(s.hands[3]).toHaveLength(12);
    s = must(s, 3, { type: 'give', cards: s.hands[3].slice(0, 4) });
    expect(s.hands.map((h) => h.length)).toEqual([8, 8, 8, 8, 8]);
  });
});

describe('187: tricks', () => {
  it('each trick is led by the next seat in turn, whoever won the last one', () => {
    let s = new187Game({ players: 4, dealer: 3 }, seeded(11));
    s = must(s, 0, { type: 'bid', value: 187 });
    s = must(s, 0, { type: 'give', cards: s.hands[0].slice(0, 3) });
    s = must(s, 0, { type: 'trump', suit: 'H' });
    for (let t = 0; t < 10; t++) {
      expect(s.phase).toBe('playing');
      expect(s.turn).toBe(t % 4);
      for (let k = 0; k < 4; k++) s = must(s, s.turn, auto187Action(s, s.turn));
      expect(s.phase).toBe('trickDone');
      s = advance187(s, seeded(1));
    }
  });
  it('2 is the strongest card of its suit, then A, K, 10, Q, J…; trump beats the led suit', () => {
    expect(b187TrickWinner([{ seat: 0, card: 'D14' }, { seat: 1, card: 'D2' }, { seat: 2, card: 'D13' }], 'S')).toBe(1);
    expect(b187TrickWinner([{ seat: 0, card: 'D10' }, { seat: 1, card: 'D12' }], null)).toBe(0);
    expect(b187TrickWinner([{ seat: 0, card: 'D2' }, { seat: 1, card: 'S6' }], 'S')).toBe(1);
    expect(b187TrickWinner([{ seat: 0, card: 'D6' }, { seat: 1, card: 'C2' }], 'S')).toBe(0); // off-suit, no trump
  });
  it('must follow the led suit when able', () => {
    expect(b187Legal(['D6', 'S2', 'D14'], [{ seat: 3, card: 'D10' }])).toEqual(['D6', 'D14']);
    expect(b187Legal(['S2', 'C6'], [{ seat: 3, card: 'D10' }])).toEqual(['S2', 'C6']);
  });
});

describe('187: scoring', () => {
  it('a full hand hands out all 187 points; a lost buyer chooses −bid or −187', () => {
    for (let seed = 10; seed < 40; seed++) {
      let s = new187Game({ players: 4 }, seeded(seed));
      s = runUntil(s, (x) => x.phase === 'lossChoice' || x.phase === 'handOver' || x.phase === 'gameOver', seeded(seed));
      const r = s.lastResult!;
      expect(r.collected.reduce((a, b) => a + b, 0)).toBe(187);
      expect(r.lost).toBe(r.collected[r.buyer] < r.bid);
      if (s.phase === 'lossChoice') {
        const full = must(s, r.buyer, { type: 'loss', choice: 'full' });
        expect(full.lastResult!.seatDelta).toEqual(r.collected.map((_, i) => (i === r.buyer ? -187 : 0)));
        const bid = must(s, r.buyer, { type: 'loss', choice: 'bid' });
        expect(bid.lastResult!.seatDelta).toEqual(r.collected.map((p, i) => (i === r.buyer ? -r.bid : p)));
        return;
      }
      expect(r.seatDelta).toEqual(r.collected); // success: everyone scores what they collected
    }
    throw new Error('no lost hand in 30 seeds');
  });
});

describe('187: full matches (autopilot)', () => {
  for (const players of [4, 5]) {
    it(`${players} players: every move legal, ends when someone reaches ±312`, { timeout: 60_000 }, () => {
      for (let n = 0; n < 10; n++) {
        const r = seeded(200 + n);
        let s = new187Game({ players }, r);
        for (let steps = 0; s.phase !== 'gameOver'; steps++) {
          if (steps > 50_000) throw new Error('did not finish');
          if (s.phase === 'trickDone' || s.phase === 'handOver') {
            s = advance187(s, r);
            continue;
          }
          const a = auto187Action(s, s.turn);
          if (a.type === 'play') expect(b187Legal(s.hands[s.turn], s.trick)).toContain(a.card);
          s = must(s, s.turn, a);
        }
        expect(s.scores.some((v) => Math.abs(v) >= B187_MATCH_LIMIT)).toBe(true);
        expect(s.winnerSeats.every((w) => s.scores[w] === Math.max(...s.scores))).toBe(true);
      }
    });
  }
  it('views never show other hands', () => {
    const s = new187Game({ players: 5 }, seeded(9));
    const v = b187ViewFor(s, 2);
    expect(v.myHand).toEqual(s.hands[2]);
    expect(v.handCounts).toEqual([7, 7, 7, 7, 7]);
    for (const other of [0, 1, 3, 4]) for (const c of s.hands[other]) expect(JSON.stringify(v)).not.toContain(`"${c}"`);
  });
});
