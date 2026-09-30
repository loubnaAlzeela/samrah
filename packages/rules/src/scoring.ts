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
