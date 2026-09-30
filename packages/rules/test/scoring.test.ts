import { describe, expect, it } from 'vitest';
import { scoreSyrianSeat, scoreTarneebHand, syrianWinner, tarneebWinner } from '../src/index.ts';

describe('scoreTarneebHand', () => {
  it('made exactly: bidders + tricks, defenders 0', () => {
    expect(scoreTarneebHand(7, 0, 7)).toEqual({ delta: [7, 0], note: 'made' });
  });
  it('made with overtricks: bidders get ALL their tricks', () => {
    expect(scoreTarneebHand(8, 1, 10)).toEqual({ delta: [0, 10], note: 'made' });
  });
  it('failed: bidders minus the BID value, defenders + their tricks', () => {
    expect(scoreTarneebHand(9, 0, 7)).toEqual({ delta: [-9, 6], note: 'fail' });
  });
  it('kaboot without bidding 13: +16', () => {
    expect(scoreTarneebHand(8, 0, 13)).toEqual({ delta: [16, 0], note: 'kaboot' });
  });
  it('bid 13 and made it: +26', () => {
    expect(scoreTarneebHand(13, 1, 13)).toEqual({ delta: [0, 26], note: 'kaboot13' });
  });
  it('bid 13 and failed: -16, defenders + their tricks', () => {
    expect(scoreTarneebHand(13, 0, 12)).toEqual({ delta: [-16, 1], note: 'fail13' });
  });
  it('defenders take all 13: bidders -bid, defenders +13 (no kaboot bonus for defenders)', () => {
    expect(scoreTarneebHand(7, 0, 0)).toEqual({ delta: [-7, 13], note: 'fail' });
  });
  it('rejects impossible input', () => {
    expect(() => scoreTarneebHand(6, 0, 7)).toThrow();
    expect(() => scoreTarneebHand(14, 0, 7)).toThrow();
    expect(() => scoreTarneebHand(7, 0, 14)).toThrow();
  });
});

describe('tarneebWinner', () => {
  it('reaching the target exactly wins', () => expect(tarneebWinner([41, 12], 41)).toBe(0));
  it('passing the target wins', () => expect(tarneebWinner([20, 35], 31)).toBe(1));
  it('below target: no winner', () => expect(tarneebWinner([60, -5], 61)).toBeNull());
  it('negative scores are fine', () => expect(tarneebWinner([-16, -3], 31)).toBeNull());
});

describe('Syrian 41 scoring', () => {
  it('made: + bid only (overtricks ignored)', () => {
    expect(scoreSyrianSeat(4, 4)).toBe(4);
    expect(scoreSyrianSeat(4, 7)).toBe(4);
  });
  it('failed: - bid', () => expect(scoreSyrianSeat(5, 4)).toBe(-5));
  it('bid out of range throws', () => {
    expect(() => scoreSyrianSeat(1, 1)).toThrow();
    expect(() => scoreSyrianSeat(14, 1)).toThrow();
  });
});

describe('syrianWinner', () => {
  it('player reaches 41 with partner > 0: team wins', () => expect(syrianWinner([41, 10, 1, 30])).toBe(0));
  it('partner at 0 or below: game continues', () => {
    expect(syrianWinner([45, 10, 0, 30])).toBeNull();
    expect(syrianWinner([45, 10, -3, 30])).toBeNull();
  });
  it('either partner can be the one who reaches 41', () => expect(syrianWinner([2, 3, 50, 30])).toBe(0));
  it('both teams qualify: higher qualifying score wins', () => expect(syrianWinner([43, 44, 5, 5])).toBe(1));
  it('both teams qualify with an exact tie: no winner yet (extra hand)', () => expect(syrianWinner([43, 43, 5, 5])).toBeNull());
  it('one team qualifies, the other reaches 41 with a partner <= 0: first team wins', () =>
    expect(syrianWinner([41, 50, 2, -1])).toBe(0));
});
