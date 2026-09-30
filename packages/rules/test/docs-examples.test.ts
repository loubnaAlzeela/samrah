import { describe, expect, it } from 'vitest';
import { scoreSyrianSeat, scoreTarneebHand, syrianWinner, tarneebWinner } from '../src/index.ts';

/** The worked examples in docs/rules/*.md, checked against the engine so the docs cannot drift. */
describe('docs/rules/tarneeb.md examples', () => {
  it('1: made 8 with 9 tricks -> +9; 12 vs 20 becomes 21 vs 20', () => {
    const { delta } = scoreTarneebHand(8, 0, 9);
    expect([12 + delta[0], 20 + delta[1]]).toEqual([21, 20]);
  });
  it('2: bid 9 got 7 -> bidders -9, defenders +6; 12 vs 20 becomes 18 vs 11', () => {
    const { delta } = scoreTarneebHand(9, 1, 7);
    expect([12 + delta[0], 20 + delta[1]]).toEqual([18, 11]);
  });
  it('3: bid 7 took all 13 -> +16', () => expect(scoreTarneebHand(7, 0, 13).delta).toEqual([16, 0]));
  it('4: bid 13 made -> +26', () => expect(scoreTarneebHand(13, 0, 13).delta).toEqual([26, 0]));
  it('5: seat 3 bid 13 got 12 -> -16, defenders +1', () => expect(scoreTarneebHand(13, 1, 12).delta).toEqual([1, -16]));
  it('6: 35 + 7 = 42 >= 41 wins', () => {
    const { delta } = scoreTarneebHand(7, 0, 7);
    expect(tarneebWinner([35 + delta[0], 38 + delta[1]], 41)).toBe(0);
  });
});

describe('docs/rules/tarneeb-syrian-41.md examples', () => {
  it('1: bids 3/4/2/3, tricks 4/3/2/4 -> +3/-4/+2/+3', () => {
    const bids = [3, 4, 2, 3];
    const tricks = [4, 3, 2, 4];
    expect(bids.map((b, i) => scoreSyrianSeat(b, tricks[i]))).toEqual([3, -4, 2, 3]);
  });
  it('3: 42 with partner -3 -> continue', () => expect(syrianWinner([-3, 0, 42, 0])).toBeNull());
  it('4: 42 with partner 2 -> team 0 wins', () => expect(syrianWinner([2, 0, 42, 0])).toBe(0));
  it('5: 43 vs 44 both qualified -> team 1; 43 vs 43 -> extra hand', () => {
    expect(syrianWinner([43, 44, 5, 5])).toBe(1);
    expect(syrianWinner([43, 43, 5, 5])).toBeNull();
  });
});
