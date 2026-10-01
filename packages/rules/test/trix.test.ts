import { describe, expect, it } from 'vitest';
import {
  type Card,
  type Seat,
  type TrixAction,
  type TrixState,
  FIRST_OWNER_CARD,
  type TrixVariant,
  actTrix,
  advanceTrix,
  autoTrixAction,
  card,
  newTrixGame,
  startTrixHand,
  trickPenalties,
  trixLegal,
  trixContractsOf,
  trixPlayable,
  trixViewFor,
} from '../src/index.ts';
import { seeded } from './helpers.ts';

const rng = seeded(41);
const range = (suit: 'S' | 'H' | 'D' | 'C', from: number, to: number): Card[] => {
  const out: Card[] = [];
  for (let r = from; r <= to; r++) out.push(card(suit, r));
  return out;
};

/** A hand dealt from exact cards, with `owner` owning the kingdom. */
function preset(hands: Card[][], owner: Seat = 0, variant: TrixVariant = 'trix'): TrixState {
  const g = newTrixGame({ variant, dealer: 3 }, rng);
  return startTrixHand({ ...g, kingdomOwner: owner, handNo: 0 }, rng, { hands, dealer: ((owner + 3) % 4) as Seat });
}

function must(s: TrixState, seat: Seat, a: TrixAction): TrixState {
  const r = actTrix(s, seat, a);
  if (!r.ok) throw new Error(r.error);
  return r.state;
}

// seat0: A♥ + spades 2..K · seat1: K♥ + diamonds 2..K · seat2: hearts 2..Q + A♠ + A♦ · seat3: all clubs
const KING_HANDS: Card[][] = [
  ['H14', ...range('S', 2, 13)],
  ['H13', ...range('D', 2, 13)],
  [...range('H', 2, 12), 'S14', 'D14'],
  range('C', 2, 14),
];

describe('trix: deal and kingdom', () => {
  it('the holder of 7♥ owns the first kingdom and picks the first contract', () => {
    const g = newTrixGame({ variant: 'trix' }, seeded(7));
    expect(g.hands[g.kingdomOwner]).toContain(FIRST_OWNER_CARD);
    expect(g.phase).toBe('contract');
    expect(g.turn).toBe(g.kingdomOwner);
    expect(g.hands.every((h) => h.length === 13)).toBe(true);
  });
  it('only the owner picks, and each contract once per kingdom', () => {
    const s = preset(KING_HANDS, 0);
    expect(actTrix(s, 1, { type: 'contract', contract: 'king' })).toEqual({ ok: false, error: 'notYourTurn' });
    const after = must(s, 0, { type: 'contract', contract: 'tricks' });
    const again = advanceTrix({ ...after, phase: 'handOver' }, rng);
    expect(actTrix(again, 0, { type: 'contract', contract: 'tricks' })).toEqual({ ok: false, error: 'contractUsed' });
  });
});

describe('trix: doubling', () => {
  it('king: only the K♥ holder decides, then the owner leads', () => {
    let s = must(preset(KING_HANDS, 0), 0, { type: 'contract', contract: 'king' });
    expect(s.phase).toBe('double');
    expect(s.turn).toBe(1);
    expect(actTrix(s, 1, { type: 'double', cards: ['H12'] })).toEqual({ ok: false, error: 'badDouble' });
    s = must(s, 1, { type: 'double', cards: ['H13'] });
    expect(s.doubled).toEqual([{ card: 'H13', seat: 1 }]);
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(0);
  });
  it('queens: every Queen holder in turn from the owner, each may double some of theirs', () => {
    // Queens: seat0 has Q♠ Q♥, seat1 none, seat2 Q♦, seat3 Q♣
    const hands: Card[][] = [
      [...range('S', 2, 13), 'H12'],
      [...range('C', 2, 11), 'C13', 'C14', 'S14'],
      range('D', 2, 14),
      [...range('H', 2, 11), 'H13', 'H14', 'C12'],
    ];
    let s = must(preset(hands, 0), 0, { type: 'contract', contract: 'queens' });
    expect(s.doubleQueue).toEqual([0, 2, 3]);
    s = must(s, 0, { type: 'double', cards: ['H12'] });
    s = must(s, 2, { type: 'double', cards: [] });
    s = must(s, 3, { type: 'double', cards: ['C12'] });
    expect(s.doubled.map((d) => d.card)).toEqual(['H12', 'C12']);
    expect(s.phase).toBe('playing');
  });
});

describe('trix: trick contracts', () => {
  it('king ends as soon as K♥ is taken; the doubler earns 75, the taker loses 150', () => {
    let s = must(preset(KING_HANDS, 0), 0, { type: 'contract', contract: 'king' });
    s = must(s, 1, { type: 'double', cards: ['H13'] });
    s = must(s, 0, { type: 'play', card: 'H14' });
    expect(trixLegal(s, 1)).toEqual(['H13']); // must follow hearts
    s = must(s, 1, { type: 'play', card: 'H13' });
    s = must(s, 2, { type: 'play', card: 'H2' });
    s = must(s, 3, { type: 'play', card: 'C2' });
    expect(s.phase).toBe('trickDone');
    s = advanceTrix(s, rng);
    expect(s.phase).toBe('handOver');
    expect(s.lastResult?.seatDelta).toEqual([-150, 75, 0, 0]);
    expect(s.seatScores).toEqual([-150, 75, 0, 0]);
  });
  it('penalties per contract', () => {
    const taken: Card[][] = [['S12', 'H12', 'D3'], ['D14', 'D2', 'D5'], ['H13'], []];
    const tricks = [3, 4, 5, 1];
    expect(trickPenalties('king', taken, tricks, [])).toEqual([0, 0, -75, 0]);
    expect(trickPenalties('king', taken, tricks, [{ card: 'H13', seat: 2 }])).toEqual([0, 0, -150, 0]); // own doubled card: no bonus
    expect(trickPenalties('queens', taken, tricks, [{ card: 'H12', seat: 3 }])).toEqual([-75, 0, 0, 25]);
    expect(trickPenalties('diamonds', taken, tricks, [])).toEqual([-10, -30, 0, 0]);
    expect(trickPenalties('tricks', taken, tricks, [])).toEqual([-45, -60, -75, -15]);
  });
  it('the trick goes to the highest card of the led suit (no trump)', () => {
    let s = must(preset(KING_HANDS, 3), 3, { type: 'contract', contract: 'tricks' });
    s = must(s, 3, { type: 'play', card: 'C2' });
    s = must(s, 0, { type: 'play', card: 'S13' });
    s = must(s, 1, { type: 'play', card: 'D13' });
    s = must(s, 2, { type: 'play', card: 'S14' });
    expect(s.turn).toBe(3); // nobody else followed clubs
  });
});

describe('trix: the trix contract', () => {
  it('a Jack opens a suit; then only the neighbours of the ends', () => {
    expect(trixPlayable(['S10', 'S11', 'H9'], { S: null, H: null, D: null, C: null })).toEqual(['S11']);
    expect(trixPlayable(['S10', 'S12', 'S9', 'H9'], { S: { low: 11, high: 11 }, H: null, D: null, C: null })).toEqual(['S10', 'S12']);
    expect(trixPlayable(['S9', 'S14'], { S: { low: 10, high: 13 }, H: null, D: null, C: null })).toEqual(['S9', 'S14']);
  });
  it('a seat with nothing to place is skipped (and shown as passing)', () => {
    // seat0 holds all Jacks and 10s -> seat1 (no J, nothing placeable) passes after seat0 opens spades
    const hands: Card[][] = [
      ['S11', 'H11', 'D11', 'C11', 'S10', 'H10', 'D10', 'C10', 'S2', 'H2', 'D2', 'C2', 'S3'],
      [...range('S', 4, 9), ...range('H', 3, 9)],
      [...range('D', 3, 9), ...range('C', 3, 8)],
      ['C9', ...range('S', 12, 14), ...range('H', 12, 14), ...range('D', 12, 14), ...range('C', 12, 14)],
    ];
    let s = must(preset(hands, 0), 0, { type: 'contract', contract: 'trix' });
    expect(s.turn).toBe(0);
    s = must(s, 0, { type: 'play', card: 'S11' });
    // seat1 holds S9..S4 (not adjacent to J) -> passes; seat2 has nothing; seat3 has S12
    expect(s.turn).toBe(3);
    expect(s.lastPasses).toEqual([1, 2]);
  });
  it('finishing order scores 200/150/100/50', () => {
    let s = must(preset(newTrixGame({ variant: 'trix' }, seeded(3)).hands, 0), 0, { type: 'contract', contract: 'trix' });
    while (s.phase === 'playing') s = must(s, s.turn, autoTrixAction(s, s.turn));
    expect(s.phase).toBe('handOver');
    const r = s.lastResult!;
    expect(r.finishOrder).toHaveLength(4);
    expect(new Set(r.finishOrder).size).toBe(4);
    expect(r.finishOrder.map((seat) => r.seatDelta[seat])).toEqual([200, 150, 100, 50]);
  });
});

describe('trix: view', () => {
  it('shows only my hand, and double options only to the seat deciding', () => {
    const s = must(preset(KING_HANDS, 0), 0, { type: 'contract', contract: 'king' });
    const v1 = trixViewFor(s, 1);
    const v0 = trixViewFor(s, 0);
    expect(v1.myHand).toEqual(s.hands[1]);
    expect(v1.doubleOptions).toEqual(['H13']);
    expect(v0.doubleOptions).toEqual([]);
    expect(JSON.stringify(v0)).not.toContain('"H13"'); // K♥ is in seat1's hand and not doubled yet
    expect(v0.handCounts).toEqual([13, 13, 13, 13]);
  });
});

describe('trix: full games (autopilot)', () => {
  function play(variant: TrixVariant, seed: number) {
    const r = seeded(seed);
    let s = newTrixGame({ variant }, r);
    const perKingdom: string[][] = [[], [], [], []];
    const owners: Seat[] = [];
    for (let steps = 0; s.phase !== 'gameOver'; steps++) {
      if (steps > 20_000) throw new Error('did not finish');
      if (s.phase === 'trickDone' || s.phase === 'handOver') {
        s = advanceTrix(s, r);
        continue;
      }
      const a = autoTrixAction(s, s.turn);
      if (a.type === 'contract') {
        perKingdom[s.kingdom].push(a.contract);
        owners[s.kingdom] = s.kingdomOwner;
      }
      if (a.type === 'play') expect(trixLegal(s, s.turn)).toContain(a.card);
      s = must(s, s.turn, a);
    }
    return { s, perKingdom, owners };
  }
  it('solo: 4 kingdoms x 5 contracts, owners rotate to the right, every move legal', { timeout: 60_000 }, () => {
    for (let n = 0; n < 10; n++) {
      const { s, perKingdom, owners } = play('trix', 100 + n);
      expect(s.handNo).toBe(20);
      for (const k of perKingdom) expect([...k].sort()).toEqual([...trixContractsOf('trix')].sort());
      expect(owners.map((o, i) => (o - owners[0] + 4) % 4 === i)).toEqual([true, true, true, true]);
      expect(s.winnerSeats.length).toBeGreaterThan(0);
      expect(s.winnerSeats.every((w) => s.seatScores[w] === Math.max(...s.seatScores))).toBe(true);
    }
  });
  it('partners: opposite seats add up, the winning team is decided', { timeout: 60_000 }, () => {
    const { s } = play('trixPartners', 7);
    expect(s.teamScores).toEqual([s.seatScores[0] + s.seatScores[2], s.seatScores[1] + s.seatScores[3]]);
    if (s.teamScores[0] !== s.teamScores[1]) expect(s.winner).toBe(s.teamScores[0] > s.teamScores[1] ? 0 : 1);
  });
});

describe('trix complex', () => {
  it('two contracts per kingdom: complex and trix; the classic ones are refused', () => {
    const s = preset(KING_HANDS, 0, 'trixComplex');
    expect(trixViewFor(s, 0).contractsLeft).toEqual(['complex', 'trix']);
    expect(actTrix(s, 0, { type: 'contract', contract: 'king' })).toEqual({ ok: false, error: 'badContract' });
    expect(actTrix(preset(KING_HANDS, 0, 'trix'), 0, { type: 'contract', contract: 'complex' })).toEqual({ ok: false, error: 'badContract' });
  });
  it('complex: K♥ and Queen holders may double, in turn from the owner', () => {
    // seat0: Q♠ · seat1: K♥ · seat2: Q♥ · seat3: Q♣ (Q♦ sits with seat2 too)
    const hands: Card[][] = [
      [...range('S', 2, 12), 'S14', 'H14'],
      ['H13', ...range('D', 2, 11), 'D13', 'D14'],
      [...range('H', 2, 12), 'D12', 'C14'],
      range('C', 2, 13).concat(['S13']),
    ];
    let s = must(preset(hands, 0, 'trixComplex'), 0, { type: 'contract', contract: 'complex' });
    expect(s.phase).toBe('double');
    expect(s.doubleQueue).toEqual([0, 1, 2, 3]);
    expect(trixViewFor(s, 0).doubleOptions).toEqual(['S12']);
    s = must(s, 0, { type: 'double', cards: [] });
    expect(trixViewFor(s, 1).doubleOptions).toEqual(['H13']);
    s = must(s, 1, { type: 'double', cards: ['H13'] });
    s = must(s, 2, { type: 'double', cards: ['H12', 'D12'] });
    s = must(s, 3, { type: 'double', cards: [] });
    expect(s.doubled.map((d) => d.card)).toEqual(['H13', 'H12', 'D12']);
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(0);
  });
  it('complex scores every penalty at once: K♥, Queens, diamonds and tricks, with doubles', () => {
    const taken: Card[][] = [['S12', 'H12', 'D3'], ['D14', 'D2', 'D5'], ['H13'], []];
    const tricks = [3, 4, 5, 1];
    // seat0: Q♠ -25, Q♥ doubled by seat3 -50, D3 -10, 3 tricks -45 = -130
    // seat1: 3 diamonds -30, 4 tricks -60 = -90 · seat2: K♥ -75, 5 tricks -75 = -150 · seat3: 1 trick -15, bonus +25 = +10
    expect(trickPenalties('complex', taken, tricks, [{ card: 'H12', seat: 3 }])).toEqual([-130, -90, -150, 10]);
  });
  it('a full kingdom without doubles adds up to zero: complex −370, trix +500', () => {
    let s = preset(newTrixGame({ variant: 'trix' }, seeded(5)).hands, 0, 'trixComplex');
    s = must(s, 0, { type: 'contract', contract: 'complex' });
    while (s.phase === 'double') s = must(s, s.turn, { type: 'double', cards: [] });
    while (s.phase !== 'handOver') s = s.phase === 'trickDone' ? advanceTrix(s, rng) : must(s, s.turn, autoTrixAction(s, s.turn));
    expect(s.tricks.reduce((a, b) => a + b, 0)).toBe(13); // complex never stops early
    expect(s.lastResult!.seatDelta.reduce((a, b) => a + b, 0)).toBe(-(75 + 100 + 130 + 195));
  });
});

describe('trix complex: full games (autopilot)', () => {
  function playOut(variant: TrixVariant, seed: number) {
    const r = seeded(seed);
    let s = newTrixGame({ variant }, r);
    const perKingdom: string[][] = [[], [], [], []];
    for (let steps = 0; s.phase !== 'gameOver'; steps++) {
      if (steps > 20_000) throw new Error('did not finish');
      if (s.phase === 'trickDone' || s.phase === 'handOver') {
        s = advanceTrix(s, r);
        continue;
      }
      const a = autoTrixAction(s, s.turn);
      if (a.type === 'contract') perKingdom[s.kingdom].push(a.contract);
      s = must(s, s.turn, a);
    }
    return { s, perKingdom };
  }
  it('solo: 4 kingdoms x 2 contracts = 8 hands', { timeout: 60_000 }, () => {
    for (let n = 0; n < 10; n++) {
      const { s, perKingdom } = playOut('trixComplex', 300 + n);
      expect(s.handNo).toBe(8);
      for (const k of perKingdom) expect([...k].sort()).toEqual(['complex', 'trix']);
      expect(s.winnerSeats.every((w) => s.seatScores[w] === Math.max(...s.seatScores))).toBe(true);
    }
  });
  it('partners: opposite seats add up, the winning team is decided', () => {
    const { s } = playOut('trixComplexPartners', 9);
    expect(s.teamScores).toEqual([s.seatScores[0] + s.seatScores[2], s.seatScores[1] + s.seatScores[3]]);
    if (s.teamScores[0] !== s.teamScores[1]) expect(s.winner).toBe(s.teamScores[0] > s.teamScores[1] ? 0 : 1);
    else expect(s.winner).toBeNull();
  });
});
