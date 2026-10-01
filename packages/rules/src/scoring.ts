import type { Seat, Team } from './cards.ts';
import { partnerOf, teamOf } from './cards.ts';

export type TarneebNote = 'made' | 'kaboot' | 'kaboot13' | 'fail' | 'fail13';

/**
 * Score one hand of regular Tarneeb.
 * - bid 13 made  -> bidders +26, defenders 0
 * - bid 13 failed-> bidders -16, defenders + their tricks
 * - all 13 tricks without bidding 13 -> bidders +16, defenders 0
 * - made (tricks >= bid) -> bidders + tricks taken, defenders 0
 * - failed -> bidders - bid value, defenders + their tricks
 */
export function scoreTarneebHand(
  bid: number,
  bidderTeam: Team,
  bidderTricks: number,
): { delta: [number, number]; note: TarneebNote } {
  if (!Number.isInteger(bid) || bid < 7 || bid > 13) throw new Error('bad bid');
  if (!Number.isInteger(bidderTricks) || bidderTricks < 0 || bidderTricks > 13) throw new Error('bad tricks');
  const defTricks = 13 - bidderTricks;
  let bidderDelta: number;
  let defDelta: number;
  let note: TarneebNote;
  if (bid === 13) {
    if (bidderTricks === 13) {
      bidderDelta = 26; defDelta = 0; note = 'kaboot13';
    } else {
      bidderDelta = -16; defDelta = defTricks; note = 'fail13';
    }
  } else if (bidderTricks >= bid) {
    if (bidderTricks === 13) {
      bidderDelta = 16; defDelta = 0; note = 'kaboot';
    } else {
      bidderDelta = bidderTricks; defDelta = 0; note = 'made';
    }
  } else {
    bidderDelta = -bid; defDelta = defTricks; note = 'fail';
  }
  const delta: [number, number] = [0, 0];
  delta[bidderTeam] = bidderDelta;
  delta[(1 - bidderTeam) as Team] = defDelta;
  return { delta, note };
}

/** Team that reached the target after this hand, or null. Only one team can gain points per hand. */
export function tarneebWinner(scores: readonly [number, number], target: number): Team | null {
  if (scores[0] >= target && scores[1] >= target) return scores[0] >= scores[1] ? 0 : 1; // unreachable by the rules, defensive
  if (scores[0] >= target) return 0;
  if (scores[1] >= target) return 1;
  return null;
}

/** Syrian 41: each player scores alone: made (tricks >= bid) -> +bid, failed -> -bid. */
export function scoreSyrianSeat(bid: number, tricks: number): number {
  if (!Number.isInteger(bid) || bid < 2 || bid > 13) throw new Error('bad bid');
  return tricks >= bid ? bid : -bid;
}

export const SYRIAN_MIN_TOTAL_BIDS = 11;
export const SYRIAN_TARGET = 41;

/**
 * 400: what a bid is worth, won or lost. A player whose own score is already 30 or more
 * scores bids of 5 and 6 at face value; everything else is the same in both tables.
 */
export const FOUR00_VALUES: Readonly<Record<number, number>> = { 2: 2, 3: 3, 4: 4, 5: 10, 6: 12, 7: 14, 8: 16, 9: 27, 10: 40, 11: 40, 12: 40, 13: 40 };
export const FOUR00_VALUES_FROM_30: Readonly<Record<number, number>> = { ...FOUR00_VALUES, 5: 5, 6: 6 };

/** 400: made (tricks >= bid) -> +value of the bid, failed -> −value; the table depends on the player's own score. */
export function scoreFour00Seat(bid: number, tricks: number, ownScore: number): number {
  if (!Number.isInteger(bid) || bid < 2 || bid > 13) throw new Error('bad bid');
  const value = (ownScore >= 30 ? FOUR00_VALUES_FROM_30 : FOUR00_VALUES)[bid];
  return tricks >= bid ? value : -value;
}

/** 400: the lowest bid a player may make, by their own score: 30–39 -> 3, 40–49 -> 4, 50+ -> 5, else 2. */
export function four00MinBid(ownScore: number): number {
  if (ownScore >= 50) return 5;
  if (ownScore >= 40) return 4;
  if (ownScore >= 30) return 3;
  return 2;
}

/** 400: the lowest total of the four bids, by the highest score at the table: 30+ -> 12, 40+ -> 13, 50+ -> 14, else 11. */
export function four00MinTotal(seatScores: readonly number[]): number {
  const top = Math.max(...seatScores);
  if (top >= 50) return 14;
  if (top >= 40) return 13;
  if (top >= 30) return 12;
  return SYRIAN_MIN_TOTAL_BIDS;
}

/**
 * Syrian 41 winner check.
 * A team qualifies when one of its players has >= target AND that player's partner has > 0.
 * Both teams qualify -> the team whose qualifying player has the higher score wins; exact tie -> null (play another hand).
 */
export function syrianWinner(seatScores: readonly number[], target = SYRIAN_TARGET): Team | null {
  const best: [number | null, number | null] = [null, null];
  for (let s = 0 as Seat; s < 4; s = (s + 1) as Seat) {
    if (seatScores[s] >= target && seatScores[partnerOf(s)] > 0) {
      const t = teamOf(s);
      best[t] = Math.max(best[t] ?? -Infinity, seatScores[s]);
    }
  }
  if (best[0] !== null && best[1] !== null) {
    if (best[0] === best[1]) return null;
    return best[0] > best[1] ? 0 : 1;
  }
  if (best[0] !== null) return 0;
  if (best[1] !== null) return 1;
  return null;
}
