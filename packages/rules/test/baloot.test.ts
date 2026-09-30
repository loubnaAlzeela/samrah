import { describe, expect, it } from 'vitest';
import {
  type BalootAction,
  type BalootState,
  type Card,
  type Seat,
  BALOOT_TARGET,
  actBaloot,
  advanceBaloot,
  autoBalootAction,
  balootDeck,
  balootLegal,
  balootPower,
  balootTrickWinner,
  balootValue,
  balootViewFor,
  findProjects,
  hokmPoints,
  newBalootGame,
  scoreBaloot,
  startBalootHand,
  sunPoints,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(152);

function must(s: BalootState, seat: Seat, a: BalootAction): BalootState {
  const r = actBaloot(s, seat, a);
  if (!r.ok) throw new Error(r.error);
  return r.state;
}

/**
 * Dealer 3, so the auction goes 0, 1, 2, 3. `first` = the 5 cards of seats 0..3, `flipped` the face-up card;
 * the other cards follow in deck order (the buyer gets the next 2, then 3 each for the others from seat 0).
 */
function preset(first: Card[][], flipped: Card, scores: [number, number] = [0, 0]): BalootState {
  const used = [...first.flat(), flipped];
  const rest = balootDeck().filter((c) => !used.includes(c));
  const g = newBalootGame({ dealer: 3 }, rng);
  return startBalootHand({ ...g, handNo: 0, teamScores: scores }, rng, { dealer: 3, deck: [...first.flat(), flipped, ...rest] });
}

const HANDS: Card[][] = [
  ['S14', 'S13', 'S12', 'H7', 'H8'],
  ['D14', 'D10', 'C7', 'C8', 'C9'],
  ['H11', 'H9', 'H14', 'S7', 'S8'],
  ['D7', 'D8', 'D9', 'C14', 'C10'],
];

describe('baloot: cards', () => {
  it('orders sun and hokm as the rules say (weakest to strongest)', () => {
    const sun = ['S7', 'S8', 'S9', 'S11', 'S12', 'S13', 'S10', 'S14'];
    expect(sun.map((c) => balootPower(c, null))).toEqual([0, 1, 2, 3, 4, 5, 6, 7]);
    const trump = ['H7', 'H8', 'H12', 'H13', 'H10', 'H14', 'H9', 'H11'];
    const p = trump.map((c) => balootPower(c, 'H'));
    expect(p).toEqual([...p].sort((a, b) => a - b));
    expect(balootPower('H7', 'H')).toBeGreaterThan(balootPower('S14', 'H'));
  });
  it('card points add up to 120 in sun and 152 in hokm (plus 10 for the last trick)', () => {
    const deck = balootDeck();
    expect(deck).toHaveLength(32);
    expect(deck.reduce((a, c) => a + balootValue(c, null), 0)).toBe(120);
    expect(deck.reduce((a, c) => a + balootValue(c, 'S'), 0)).toBe(152);
  });
  it('trick winner: trump beats the led suit, off-suit never wins', () => {
    const t = [
      { seat: 0 as Seat, card: 'S14' },
      { seat: 1 as Seat, card: 'D14' },
      { seat: 2 as Seat, card: 'S10' },
      { seat: 3 as Seat, card: 'H7' },
    ];
    expect(balootTrickWinner(t, null)).toBe(0);
    expect(balootTrickWinner(t, 'H')).toBe(3);
    expect(balootTrickWinner(t, 'D')).toBe(1);
  });
});

describe('baloot: deal and auction', () => {
  it('5 cards each, one face up, the auction starts right of the dealer', () => {
    const g = newBalootGame({ dealer: 2 }, seeded(3));
    expect(g.hands.map((h) => h.length)).toEqual([5, 5, 5, 5]);
    expect(g.stock).toHaveLength(11);
    expect(g.flipped).not.toBeNull();
    expect(g.turn).toBe(3);
    expect(g.phase).toBe('bidding');
  });
  it('sun ends the auction at once; the buyer takes the face-up card + 2, the others 3', () => {
    const s = must(preset(HANDS, 'H10'), 0, { type: 'call', call: 'sun' });
    expect(s.mode).toBe('sun');
    expect(s.buyer).toBe(0);
    expect(s.hands.map((h) => h.length)).toEqual([8, 8, 8, 8]);
    expect(s.hands[0]).toContain('H10');
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(0);
  });
  it('hokm in round 1: the round goes on, and a later sun beats it', () => {
    let s = must(preset(HANDS, 'H10'), 0, { type: 'call', call: 'hokm', suit: 'H' });
    expect(s.phase).toBe('bidding');
    expect(s.turn).toBe(1);
    expect(actBaloot(s, 1, { type: 'call', call: 'hokm', suit: 'H' })).toEqual({ ok: false, error: 'badCall' });
    s = must(s, 1, { type: 'call', call: 'pass' });
    s = must(s, 2, { type: 'call', call: 'sun' });
    expect(s.mode).toBe('sun');
    expect(s.buyer).toBe(2);
  });
  it('hokm then everyone passes: the caller confirms hokm (or turns it to sun)', () => {
    let s = preset(HANDS, 'H10');
    expect(actBaloot(s, 0, { type: 'call', call: 'hokm', suit: 'S' })).toEqual({ ok: false, error: 'badSuit' });
    s = must(s, 0, { type: 'call', call: 'pass' });
    s = must(s, 1, { type: 'call', call: 'hokm', suit: 'H' });
    s = must(s, 2, { type: 'call', call: 'pass' });
    s = must(s, 3, { type: 'call', call: 'pass' });
    expect(s.confirming).toBe(true);
    expect(s.turn).toBe(1);
    const sun = must(s, 1, { type: 'call', call: 'sun' });
    expect(sun.mode).toBe('sun');
    const hokm = must(s, 1, { type: 'call', call: 'hokm' });
    expect(hokm.mode).toBe('hokm');
    expect(hokm.trump).toBe('H');
    expect(hokm.hands[1]).toContain('H10');
    expect(hokm.phase).toBe('double'); // the defenders may double
    expect(hokm.turn).toBe(2);
  });
  it('ashkal: only the dealer and the player on their left; the face-up card goes to the partner', () => {
    const s = preset(HANDS, 'H10');
    expect(actBaloot(s, 0, { type: 'call', call: 'ashkal' })).toEqual({ ok: false, error: 'badCall' });
    let t = must(s, 0, { type: 'call', call: 'pass' });
    t = must(t, 1, { type: 'call', call: 'pass' });
    t = must(t, 2, { type: 'call', call: 'ashkal' });
    expect(t.mode).toBe('sun');
    expect(t.buyer).toBe(2);
    expect(t.ashkal).toBe(true);
    expect(t.hands[0]).toContain('H10');
    expect(t.turn).toBe(2);
  });
  it('round 2: hokm on another suit («حكم ثاني»); all «ولا» redeals with the next dealer', () => {
    let s = preset(HANDS, 'H10');
    for (const seat of [0, 1, 2, 3] as Seat[]) s = must(s, seat, { type: 'call', call: 'pass' });
    expect(s.bidRound).toBe(2);
    expect(actBaloot(s, 0, { type: 'call', call: 'hokm', suit: 'H' })).toEqual({ ok: false, error: 'badSuit' });
    const h2 = must(s, 0, { type: 'call', call: 'hokm', suit: 'S' });
    expect(h2.hokmCall).toEqual({ seat: 0, suit: 'S' });
    for (const seat of [0, 1, 2, 3] as Seat[]) s = must(s, seat, { type: 'call', call: 'pass' });
    expect(s.phase).toBe('handOver');
    expect(s.lastResult?.kind).toBe('redeal');
    const next = advanceBaloot(s, rng);
    expect(next.dealer).toBe(0);
    expect(next.turn).toBe(1);
    expect(next.teamScores).toEqual([0, 0]);
  });
});

describe('baloot: raises', () => {
  function hokmBy1(): BalootState {
    let s = preset(HANDS, 'H10');
    s = must(s, 0, { type: 'call', call: 'pass' });
    s = must(s, 1, { type: 'call', call: 'hokm', suit: 'H' });
    s = must(s, 2, { type: 'call', call: 'pass' });
    s = must(s, 3, { type: 'call', call: 'pass' });
    return must(s, 1, { type: 'call', call: 'hokm' });
  }
  it('double -> triple -> four -> qahwa, each side in turn', () => {
    let s = hokmBy1();
    expect(s.raiseStep).toBe('double');
    s = must(s, 2, { type: 'raise', raise: false });
    expect(s.turn).toBe(0);
    s = must(s, 0, { type: 'raise', raise: true, closed: true });
    expect([s.level, s.closed, s.raiseStep, s.turn]).toEqual([2, true, 'triple', 1]);
    s = must(s, 1, { type: 'raise', raise: true });
    expect([s.level, s.raiseStep, s.turn]).toEqual([3, 'four', 0]);
    s = must(s, 0, { type: 'raise', raise: true, closed: false });
    expect([s.level, s.closed, s.raiseStep, s.turn]).toEqual([4, false, 'qahwa', 1]);
    s = must(s, 1, { type: 'raise', raise: true });
    expect(s.qahwa).toBe(true);
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(1);
  });
  it('closed: no trump lead while holding another suit', () => {
    let s = hokmBy1();
    s = must(s, 2, { type: 'raise', raise: true, closed: true });
    s = must(s, 1, { type: 'raise', raise: false });
    expect(s.phase).toBe('playing');
    const legal = balootLegal(s, 1);
    expect(legal.length).toBeGreaterThan(0);
    expect(legal.every((c) => c[0] !== 'H')).toBe(true);
    const trump = s.hands[1].find((c) => c[0] === 'H')!;
    expect(actBaloot(s, 1, { type: 'play', card: trump })).toEqual({ ok: false, error: 'closedTrump' });
  });
  it('sun: the defenders may double only when the buyer is above 100 and they are below', () => {
    expect(must(preset(HANDS, 'H10', [110, 80]), 0, { type: 'call', call: 'sun' }).phase).toBe('double');
    expect(must(preset(HANDS, 'H10', [90, 80]), 0, { type: 'call', call: 'sun' }).phase).toBe('playing');
    let s = must(preset(HANDS, 'H10', [110, 80]), 0, { type: 'call', call: 'sun' });
    s = must(s, 1, { type: 'raise', raise: true });
    expect(s.level).toBe(2);
    expect(s.phase).toBe('playing');
  });
});

describe('baloot: projects', () => {
  it('sequences: sira (3), fifty (4); hundred (5) only in hokm', () => {
    expect(findProjects(['S7', 'S8', 'S9', 'H10', 'D12', 'C7', 'C9', 'H14'], 'sun', null).map((p) => p.kind)).toEqual(['sira']);
    expect(findProjects(['S10', 'S11', 'S12', 'S13', 'D12', 'C7', 'C9', 'H14'], 'sun', null).map((p) => p.kind)).toEqual(['fifty']);
    const five = ['S9', 'S10', 'S11', 'S12', 'S13', 'D7', 'C9', 'H14'];
    expect(findProjects(five, 'hokm', 'D').map((p) => p.kind)).toEqual(['hundred']);
    expect(findProjects(five, 'sun', null).map((p) => p.kind)).toEqual(['fifty']);
  });
  it('four aces: 400 in sun, 100 in hokm; four kings: 100 in hokm only', () => {
    const aces = ['S14', 'H14', 'D14', 'C14', 'S7', 'H9', 'D11', 'C8'];
    expect(findProjects(aces, 'sun', null).map((p) => p.kind)).toEqual(['fourHundred']);
    expect(findProjects(aces, 'hokm', 'C').map((p) => p.kind)).toEqual(['hundred']);
    const kings = ['S13', 'H13', 'D13', 'C13', 'S7', 'H9', 'D11', 'C8'];
    expect(findProjects(kings, 'sun', null)).toEqual([]);
    expect(findProjects(kings, 'hokm', 'C').map((p) => p.kind)).toEqual(['hundred']);
  });
  it('at most two projects, no shared card; baloot comes on top', () => {
    const hand = ['S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14'];
    const p = findProjects(hand, 'hokm', 'S').map((x) => x.kind);
    expect(p).toEqual(['sira', 'hundred', 'baloot']);
  });
  it('only the team with the highest project scores its projects (baloot always scores)', () => {
    // seat 0: sira in spades (7 8 9) · seat 1: fifty in clubs (7 8 9 10)
    const hands: Card[][] = [
      ['S7', 'S8', 'S9', 'H12', 'D11'],
      ['C7', 'C8', 'C9', 'C10', 'H13'],
      ['S13', 'S10', 'H14', 'D7', 'D8'],
      ['S14', 'D9', 'D13', 'D14', 'C13'],
    ];
    const s = must(preset(hands, 'H11'), 0, { type: 'call', call: 'sun' });
    const byKind = s.projects.filter((p) => p.kind !== 'baloot').map((p) => [p.seat, p.kind, p.counts]);
    expect(byKind).toContainEqual([1, 'fifty', true]);
    expect(byKind.filter(([seat]) => seat === 0 || seat === 2).every(([, , counts]) => counts === false)).toBe(true);
  });
});

describe('baloot: scoring', () => {
  it('sun conversion: nearest ten x2 / 10, a 5 is just doubled', () => {
    expect([sunPoints(64), sunPoints(66), sunPoints(65), sunPoints(130), sunPoints(0)]).toEqual([12, 14, 13, 26, 0]);
    for (let a = 0; a <= 130; a++) expect(sunPoints(a) + sunPoints(130 - a)).toBe(26);
  });
  it('hokm conversion: / 10, a half rounds down', () => {
    expect([hokmPoints(85), hokmPoints(86), hokmPoints(81), hokmPoints(162)]).toEqual([8, 9, 8, 16]);
  });
  const base = { mode: 'hokm' as const, buyerTeam: 0 as const, teamTricks: [5, 3] as [number, number], projects: [0, 0] as [number, number], baloot: [0, 0] as [number, number], level: 1, qahwa: false };
  it('buyer makes it: each team keeps its points', () => {
    expect(scoreBaloot({ ...base, abnat: [100, 62] }).teamDelta).toEqual([10, 6]);
  });
  it('buyer fails: 0 for them, 16 (hokm) + projects for the others', () => {
    const r = scoreBaloot({ ...base, abnat: [70, 92], projects: [0, 2] });
    expect(r.success).toBe(false);
    expect(r.teamDelta).toEqual([0, 18]);
    expect(scoreBaloot({ ...base, mode: 'sun', abnat: [60, 70] }).teamDelta).toEqual([0, 26]);
  });
  it('a tie is a failure for the buyer', () => {
    expect(scoreBaloot({ ...base, abnat: [81, 81] }).teamDelta).toEqual([0, 16]);
  });
  it('kaboot: 44 plus projects, nothing for the others', () => {
    expect(scoreBaloot({ ...base, abnat: [162, 0], teamTricks: [8, 0], projects: [5, 0] }).teamDelta).toEqual([49, 0]);
  });
  it('raised: the winner takes everything times the level', () => {
    expect(scoreBaloot({ ...base, abnat: [100, 62], level: 2 }).teamDelta).toEqual([32, 0]);
    expect(scoreBaloot({ ...base, abnat: [60, 102], level: 3 }).teamDelta).toEqual([0, 48]);
  });
});

describe('baloot: views', () => {
  it('shows only my hand, never the stock; projects stay hidden until play', () => {
    const s = preset(HANDS, 'H10');
    const v = balootViewFor(s, 1);
    expect(v.myHand).toEqual(s.hands[1]);
    expect(v.handCounts).toEqual([5, 5, 5, 5]);
    expect(JSON.stringify(v)).not.toMatch(/"hands"|"stock"/);
    expect(v.callOptions).toEqual([]);
    expect(balootViewFor(s, 0).callOptions).toEqual(['pass', 'sun', 'hokm']);
    expect(balootViewFor(s, 0).hokmSuits).toEqual(['H']);
  });
});

describe('baloot: full games (autopilot)', () => {
  it('plays to the end, every move legal, winner at 152 or by qahwa', { timeout: 60_000 }, () => {
    for (let n = 0; n < 10; n++) {
      const r = seeded(500 + n);
      let s = newBalootGame({}, r);
      for (let steps = 0; s.phase !== 'gameOver'; steps++) {
        if (steps > 50_000) throw new Error('did not finish');
        if (s.phase === 'trickDone' || s.phase === 'handOver') {
          s = advanceBaloot(s, r);
          continue;
        }
        const a = autoBalootAction(s, s.turn);
        if (a.type === 'play') expect(balootLegal(s, s.turn)).toContain(a.card);
        s = must(s, s.turn, a);
        if (s.phase === 'playing' && s.trick.length === 0 && s.trickNo === 0) expect(s.hands.every((h) => h.length === 8)).toBe(true);
      }
      expect(s.winner).not.toBeNull();
      expect(s.qahwa || Math.max(...s.teamScores) >= BALOOT_TARGET).toBe(true);
      expect(s.teamScores[s.winner!]).toBeGreaterThanOrEqual(s.teamScores[1 - s.winner!]);
    }
  });
});
