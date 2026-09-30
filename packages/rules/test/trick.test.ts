import { describe, expect, it } from 'vitest';
import { legalCards, trickWinner } from '../src/index.ts';

describe('legalCards (follow suit)', () => {
  const hand = ['S14', 'S3', 'H10', 'D2'];
  it('leader may play anything', () => {
    expect(legalCards(hand, [])).toEqual(hand);
  });
  it('must follow the led suit when holding it', () => {
    expect(legalCards(hand, [{ seat: 0, card: 'S9' }])).toEqual(['S14', 'S3']);
  });
  it('without the led suit, any card (including trump) is allowed', () => {
    expect(legalCards(hand, [{ seat: 0, card: 'C9' }])).toEqual(hand);
  });
  it('led suit is the FIRST card, not a later trump', () => {
    expect(legalCards(hand, [{ seat: 0, card: 'D9' }, { seat: 1, card: 'S2' }])).toEqual(['D2']);
  });
});

describe('trickWinner', () => {
  it('highest card of the led suit wins when no trump is played', () => {
    expect(trickWinner([{ seat: 0, card: 'H5' }, { seat: 1, card: 'H13' }, { seat: 2, card: 'H14' }, { seat: 3, card: 'H2' }], 'S')).toBe(2);
  });
  it('an off-suit Ace never beats the led suit', () => {
    expect(trickWinner([{ seat: 0, card: 'H5' }, { seat: 1, card: 'C14' }, { seat: 2, card: 'H4' }, { seat: 3, card: 'D14' }], 'S')).toBe(0);
  });
  it('a single low trump cuts', () => {
    expect(trickWinner([{ seat: 0, card: 'H14' }, { seat: 1, card: 'S2' }, { seat: 2, card: 'H13' }, { seat: 3, card: 'H12' }], 'S')).toBe(1);
  });
  it('highest trump wins when several players cut', () => {
    expect(trickWinner([{ seat: 3, card: 'H14' }, { seat: 0, card: 'S2' }, { seat: 1, card: 'S10' }, { seat: 2, card: 'S5' }], 'S')).toBe(1);
  });
  it('trump led: highest trump wins', () => {
    expect(trickWinner([{ seat: 1, card: 'S3' }, { seat: 2, card: 'S12' }, { seat: 3, card: 'H14' }, { seat: 0, card: 'S11' }], 'S')).toBe(2);
  });
  it('10 beats 9 (numeric ranks, not string order)', () => {
    expect(trickWinner([{ seat: 0, card: 'D9' }, { seat: 1, card: 'D10' }], null)).toBe(1);
  });
});
