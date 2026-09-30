import { describe, expect, it } from 'vitest';
import { deal, fullDeck, isCard, nextSeat, partnerOf, shuffle, sisterSuit, teamOf, type Seat } from '../src/index.ts';
import { seeded } from './helpers.ts';

describe('cards', () => {
  it('deck has 52 unique valid cards', () => {
    const d = fullDeck();
    expect(d).toHaveLength(52);
    expect(new Set(d).size).toBe(52);
    expect(d.every(isCard)).toBe(true);
  });
  it('isCard rejects junk', () => {
    for (const x of ['', 'X5', 'H1', 'H15', 'H07', 'h10', 'H 9', 5, null, 'H14x']) expect(isCard(x)).toBe(false);
  });
  it('shuffle is a permutation', () => {
    const d = fullDeck();
    const s = shuffle(d, seeded(1));
    expect(s.slice().sort()).toEqual(d.slice().sort());
    expect(s).not.toEqual(d);
  });
  it('deal gives 13 each, no duplicates, dealer gets the last card', () => {
    for (let seed = 0; seed < 20; seed++) {
      const { hands, lastCardOfDealer } = deal(seeded(seed), 2);
      expect(hands.map((h) => h.length)).toEqual([13, 13, 13, 13]);
      expect(new Set(hands.flat()).size).toBe(52);
      expect(hands[2]).toContain(lastCardOfDealer);
    }
  });
  it('seat helpers: order 0>1>2>3>0, partners opposite, teams 0/2 vs 1/3', () => {
    const seats: Seat[] = [0, 1, 2, 3];
    expect(seats.map(nextSeat)).toEqual([1, 2, 3, 0]);
    expect(seats.map(partnerOf)).toEqual([2, 3, 0, 1]);
    expect(seats.map(teamOf)).toEqual([0, 1, 0, 1]);
  });
  it('sister suit: hearts<->diamonds, spades<->clubs', () => {
    expect(sisterSuit('H')).toBe('D');
    expect(sisterSuit('D')).toBe('H');
    expect(sisterSuit('S')).toBe('C');
    expect(sisterSuit('C')).toBe('S');
  });
});
