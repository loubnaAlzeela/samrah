import { describe, expect, it } from 'vitest';
import {
  type HandAction,
  type HandCard,
  type HandState,
  type Meld,
  DEFAULT_SETTINGS,
  HAND_ROUNDS,
  actHand,
  advanceHand,
  arrangeMeld,
  autoHandAction,
  findMelds,
  handCardPoints,
  handDeck,
  handViewFor,
  layoffCard,
  meldValue,
  mergeSettings,
  newHandGame,
  seatCount,
  startHandRound,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(51);

function must(s: HandState, seat: number, a: HandAction): HandState {
  const r = actHand(s, seat, a);
  if (!r.ok) throw new Error(r.error);
  return r.state;
}

/** A game where each seat holds exactly `hands[i]` (seat 1 = first player, it also holds the 15th card), mid-turn. */
function table(hands: HandCard[][], opts: { turn?: number; drew?: HandState['drew']; fire?: HandCard[]; melds?: Meld[]; opened?: boolean[] } = {}): HandState {
  const g = newHandGame({ players: hands.length, dealer: 0 }, rng);
  const used = new Set([...hands.flat(), ...(opts.fire ?? [])]);
  return {
    ...g,
    hands: hands.map((h) => h.slice()),
    stock: handDeck().filter((c) => !used.has(c)),
    fire: opts.fire ?? [],
    melds: opts.melds ?? [],
    nextMeldId: 100,
    opened: opts.opened ?? hands.map(() => false),
    turn: opts.turn ?? 1,
    phase: opts.drew === null ? 'draw' : 'playing',
    drew: opts.drew === undefined ? 'stock' : opts.drew,
    fireCard: null,
    openAtTurnStart: (opts.opened ?? [])[opts.turn ?? 1] ?? false,
    laidOffThisTurn: false,
    actedThisTurn: false,
  };
}

const kinds = (m: ReturnType<typeof arrangeMeld>) => m && { kind: m.kind, ranks: m.cards.map((c) => c.rank) };

describe('hand: deck and deal', () => {
  it('106 cards: two decks + 2 jokers', () => {
    const d = handDeck();
    expect(d).toHaveLength(106);
    expect(new Set(d).size).toBe(106);
  });
  it('14 cards each, 15 for the player right of the dealer, who starts by discarding', () => {
    for (const players of [2, 3, 4, 5]) {
      const g = newHandGame({ players, dealer: 0 }, seeded(players));
      expect(g.hands.map((h) => h.length)).toEqual(Array.from({ length: players }, (_, i) => (i === 1 ? 15 : 14)));
      expect(g.stock).toHaveLength(106 - 14 * players - 1);
      expect([g.turn, g.phase, g.drew]).toEqual([1, 'playing', 'start']);
    }
  });
  it('the player count is a room setting (2..5), only for Hand', () => {
    expect(mergeSettings(DEFAULT_SETTINGS, { players: 3 }, 'hand')?.players).toBe(3);
    expect(mergeSettings(DEFAULT_SETTINGS, { players: 6 }, 'hand')).toBeNull();
    expect(mergeSettings(DEFAULT_SETTINGS, { players: 3 }, 'tarneeb')).toBeNull();
    expect(mergeSettings(DEFAULT_SETTINGS, { players: 5 }, 'b187')?.players).toBe(5);
    expect(mergeSettings(DEFAULT_SETTINGS, { players: 3 }, 'b187')).toBeNull();
    expect(seatCount('b187', 5)).toBe(5);
    expect(seatCount('hand', 2)).toBe(2);
    expect(seatCount('hand')).toBe(4);
  });
});

describe('hand: melds', () => {
  it('sets: 3-4 of a rank in different suits', () => {
    expect(kinds(arrangeMeld(['S7a', 'H7b', 'D7a']))).toEqual({ kind: 'set', ranks: [7, 7, 7] });
    expect(arrangeMeld(['S7a', 'S7b', 'D7a'])).toBeNull();
    expect(arrangeMeld(['S7a', 'H7a', 'D7a', 'C7a', 'Xa'])).toBeNull();
  });
  it('runs: one suit in sequence, ace low (A-2-3) or high (Q-K-A)', () => {
    expect(kinds(arrangeMeld(['H5a', 'H3b', 'H4a']))).toEqual({ kind: 'run', ranks: [3, 4, 5] });
    expect(kinds(arrangeMeld(['H14a', 'H2a', 'H3a']))).toEqual({ kind: 'run', ranks: [1, 2, 3] });
    expect(kinds(arrangeMeld(['H14a', 'H13a', 'H12a']))).toEqual({ kind: 'run', ranks: [12, 13, 14] });
    expect(arrangeMeld(['H13a', 'H14a', 'H2a'])).toBeNull();
    expect(arrangeMeld(['H5a', 'H6a', 'S7a'])).toBeNull();
  });
  it('jokers fill gaps, then extend; at least two real cards', () => {
    expect(kinds(arrangeMeld(['H5a', 'Xa', 'H7a']))).toEqual({ kind: 'run', ranks: [5, 6, 7] });
    expect(kinds(arrangeMeld(['H13a', 'H14a', 'Xa']))).toEqual({ kind: 'run', ranks: [12, 13, 14] });
    expect(kinds(arrangeMeld(['S9a', 'H9a', 'Xb']))).toEqual({ kind: 'set', ranks: [9, 9, 9] });
    expect(arrangeMeld(['S9a', 'Xa', 'Xb'])).toBeNull();
  });
  it('values: joker = the card it replaces, ace 11 (1 in A-2-3), J/Q/K 10', () => {
    expect(meldValue(arrangeMeld(['H14a', 'H2a', 'H3a'])!)).toBe(6);
    expect(meldValue(arrangeMeld(['H12a', 'H13a', 'H14a'])!)).toBe(31);
    expect(meldValue(arrangeMeld(['S10a', 'Xa', 'S12a'])!)).toBe(30);
    expect([handCardPoints('S14a'), handCardPoints('Xa'), handCardPoints('D12b'), handCardPoints('C7a')]).toEqual([11, 15, 10, 7]);
  });
  it('adding to a run; a real card takes back the joker it stands for', () => {
    const m: Meld = { id: 1, owner: 0, kind: 'run', cards: arrangeMeld(['H5a', 'Xa', 'H7a'])!.cards };
    expect(layoffCard(m, 'H8b')!.cards.map((c) => c.rank)).toEqual([5, 6, 7, 8]);
    expect(layoffCard(m, 'H4b')!.cards.map((c) => c.rank)).toEqual([4, 5, 6, 7]);
    const swap = layoffCard(m, 'H6b')!;
    expect(swap.freed).toBe('Xa');
    expect(swap.cards.map((c) => c.card)).toEqual(['H5a', 'H6b', 'H7a']);
    expect(layoffCard(m, 'S8a')).toBeNull();
  });
  it('a joker in a set comes back only when the four suits are complete', () => {
    const m: Meld = { id: 1, owner: 0, kind: 'set', cards: arrangeMeld(['S9a', 'H9a', 'Xa'])!.cards };
    const three = layoffCard(m, 'D9a')!;
    expect(three.freed).toBeNull();
    expect(three.cards).toHaveLength(4);
    const four = layoffCard({ ...m, cards: three.cards }, 'C9b')!;
    expect(four.freed).toBe('Xa');
    expect(four.cards.map((c) => c.card).sort()).toEqual(['C9b', 'D9a', 'H9a', 'S9a']);
  });
});

describe('hand: turns', () => {
  const HANDS: HandCard[][] = [
    ['S2a', 'S3a', 'S4a', 'H9a', 'H10a'],
    ['S12a', 'S13a', 'S14a', 'H12a', 'D12a', 'C12a', 'D5a', 'D6a'],
    ['C2a', 'C4a', 'C6a', 'C8a', 'C10a'],
  ];
  it('first lay-down must reach 51, the next opener must beat it', () => {
    let s = table(HANDS);
    expect(actHand(s, 1, { type: 'meld', groups: [['S12a', 'S13a', 'S14a']] })).toEqual({ ok: false, error: 'openTooLow' });
    s = must(s, 1, { type: 'meld', groups: [['S12a', 'S13a', 'S14a'], ['H12a', 'D12a', 'C12a']] });
    expect(s.opened[1]).toBe(true);
    expect(s.openMin).toBe(62);
    expect(s.melds).toHaveLength(2);
    // once opened, any meld goes
    expect(s.hands[1]).toEqual(['D5a', 'D6a']);
  });
  it('must discard to end the turn; the next player draws', () => {
    let s = table(HANDS);
    s = must(s, 1, { type: 'discard', card: 'D5a' });
    expect([s.turn, s.phase, s.fire]).toEqual([2, 'draw', ['D5a']]);
    s = must(s, 2, { type: 'draw', from: 'stock' });
    expect(s.hands[2]).toHaveLength(6);
    expect(s.phase).toBe('playing');
  });
  it('a card taken from the discard pile must go into the next lay-down (or be put back)', () => {
    let s = table(HANDS, { drew: null, fire: ['S5b'], turn: 0 });
    s = must(s, 0, { type: 'draw', from: 'fire' });
    expect(s.fireCard).toBe('S5b');
    expect(actHand(s, 0, { type: 'discard', card: 'H9a' })).toEqual({ ok: false, error: 'mustUseFire' });
    const back = must(s, 0, { type: 'undoFire' });
    expect([back.phase, back.fire, back.hands[0]]).toEqual(['draw', ['S5b'], HANDS[0]]);
  });
  it('adding to melds needs an opening first', () => {
    const melds: Meld[] = [{ id: 7, owner: 1, kind: 'run', cards: arrangeMeld(['H5a', 'H6a', 'H7a'])!.cards }];
    const s = table([['H8a', 'C2a'], ['S2a', 'S3a'], ['D2a', 'D3a']], { turn: 0, melds });
    expect(actHand(s, 0, { type: 'layoff', card: 'H8a', meld: 7 })).toEqual({ ok: false, error: 'notOpened' });
    const o = table([['H8a', 'C2a'], ['S2a', 'S3a'], ['D2a', 'D3a']], { turn: 0, melds, opened: [true, true, false] });
    expect(must(o, 0, { type: 'layoff', card: 'H8a', meld: 7 }).melds[0].cards).toHaveLength(4);
  });
});

describe('hand: scoring', () => {
  it('going out: −30 for the winner, the cards left for the opened, 100 for the rest', () => {
    const melds: Meld[] = [{ id: 7, owner: 1, kind: 'run', cards: arrangeMeld(['H5a', 'H6a', 'H7a'])!.cards }];
    let s = table([['H8a', 'C2a'], ['S14a', 'Xa'], ['D2a', 'D3a']], { turn: 0, melds, opened: [true, true, false] });
    s = must(s, 0, { type: 'layoff', card: 'H8a', meld: 7 });
    s = must(s, 0, { type: 'discard', card: 'C2a' });
    expect(s.phase).toBe('handOver');
    expect(s.lastResult).toMatchObject({ winner: 0, hand: false, delta: [-30, 26, 100] });
    expect(s.scores).toEqual([-30, 26, 100]);
  });
  it('«هاند»: everything laid down at once doubles the points', () => {
    let s = table([['S2a', 'S3a', 'S4a', 'H9a', 'H10a', 'H11a', 'H12a', 'D14a', 'C14a', 'S14b', 'H14a', 'C9a'], ['D5a', 'D6a'], ['C3a']], { turn: 0, opened: [false, true, false] });
    s = must(s, 0, { type: 'meld', groups: [['S2a', 'S3a', 'S4a'], ['H9a', 'H10a', 'H11a', 'H12a'], ['D14a', 'C14a', 'S14b', 'H14a']] });
    s = must(s, 0, { type: 'discard', card: 'C9a' });
    expect(s.lastResult).toMatchObject({ winner: 0, hand: true, delta: [-60, 22, 200] });
  });
  it('five rounds, the lowest total wins; the dealer moves on', () => {
    let s = table([['H8a'], ['S2a', 'S3a'], ['D2a', 'D3a']], { turn: 0, opened: [true, false, false] });
    s = { ...s, handNo: HAND_ROUNDS - 1 };
    const first = must(s, 0, { type: 'discard', card: 'H8a' });
    expect(first.phase).toBe('handOver');
    const r = advanceHand({ ...first, handNo: 1 }, rng);
    expect([r.dealer, r.handNo]).toEqual([1, 2]);
    s = { ...s, handNo: HAND_ROUNDS };
    const end = must(s, 0, { type: 'discard', card: 'H8a' });
    expect(end.phase).toBe('gameOver');
    expect(end.winners).toEqual([0]);
  });
});

describe('hand: views', () => {
  it('shows only my hand; the discard-pile card and undo only to the player on turn', () => {
    const g = newHandGame({ players: 3, dealer: 0 }, seeded(9));
    const v = handViewFor(g, 2);
    expect(v.myHand).toEqual(g.hands[2]);
    expect(v.handCounts).toEqual([14, 15, 14]);
    expect(JSON.stringify(v)).not.toMatch(/"hands"|"stock"/);
    expect(v.drew).toBeNull();
    expect(handViewFor(g, 1).drew).toBe('start');
  });
});

describe('hand: autopilot', () => {
  it('finds runs, sets and joker melds', () => {
    const g = findMelds(['S5a', 'S6a', 'S7a', 'H9a', 'D9a', 'C9b', 'H2a', 'H3a', 'Xa', 'D13a']);
    expect(g.every((x) => arrangeMeld(x) !== null)).toBe(true);
    expect(g.flat()).toEqual(expect.arrayContaining(['S5a', 'S6a', 'S7a', 'H9a', 'D9a', 'C9b', 'H2a', 'H3a', 'Xa']));
  });
  it('full games for 2..5 players: every move legal, 5 rounds, lowest total wins', { timeout: 120_000 }, () => {
    for (const players of [2, 3, 4, 5]) {
      for (let n = 0; n < 3; n++) {
        const r = seeded(900 + players * 10 + n);
        let s = newHandGame({ players }, r);
        for (let steps = 0; s.phase !== 'gameOver'; steps++) {
          if (steps > 100_000) throw new Error('did not finish');
          if (s.phase === 'handOver') {
            s = advanceHand(s, r);
            continue;
          }
          s = must(s, s.turn, autoHandAction(s, s.turn));
          const cards = s.hands.flat().length + s.stock.length + s.fire.length + s.melds.reduce((a, m) => a + m.cards.length, 0);
          expect(cards).toBe(106);
        }
        expect(s.handNo).toBe(HAND_ROUNDS);
        expect(s.winners.every((w) => s.scores[w] === Math.min(...s.scores))).toBe(true);
      }
    }
  });
  it('a human who timed out holding the discard-pile card gets it put back', () => {
    let s = table([['S5a', 'H9a'], ['D5a', 'D6a'], ['C3a']], { turn: 0, drew: null, fire: ['C13b'] });
    s = must(s, 0, { type: 'draw', from: 'fire' });
    expect(autoHandAction(s, 0)).toEqual({ type: 'undoFire' });
  });
  it('start of a round: startHandRound keeps scores', () => {
    const g = newHandGame({ players: 2 }, rng);
    const n = startHandRound({ ...g, scores: [10, -30] }, rng, { dealer: 1 });
    expect([n.scores, n.turn, n.handNo]).toEqual([[10, -30], 0, 2]);
  });
});
