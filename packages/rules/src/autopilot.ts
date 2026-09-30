import { type Card, type Seat, type Suit, SUITS, partnerOf, rankOf, suitOf } from './cards.ts';
import type { Action, GameState } from './game.ts';
import { SYRIAN_MIN_TOTAL_BIDS } from './scoring.ts';
import { legalCards, trickWinner } from './trick.ts';

/**
 * «الطيار الآلي»: plays ONE move for `seat` when its turn timer runs out or the player is away.
 * Pure and deterministic (same state -> same move) and always legal.
 *
 * - Tarneeb bidding: pass.
 * - Tarneeb trump (autopilot won the auction): longest suit in hand; tie -> stronger suit (higher rank sum).
 * - Syrian bidding: aces + Q/K of trump, clamped to 2..5. If it is the LAST bid and the total would stay
 *   under 11, it tops up to reach exactly 11 (avoids endless redeals when several seats are on autopilot).
 * - Play: if partner is currently winning the trick -> cheapest legal card. Otherwise, if some legal card
 *   wins the trick right now -> the cheapest such card. Otherwise -> cheapest legal card.
 *   "Cheapest" = non-trump before trump, then lower rank.
 */
export function autoAction(s: GameState, seat: Seat): Action {
  if (s.phase === 'bidding') {
    if (s.variant === 'tarneeb') return { type: 'bid', value: 'pass' };
    return { type: 'bid', value: syrianAutoBid(s, seat) };
  }
  if (s.phase === 'trump') return { type: 'trump', suit: longestSuit(s.hands[seat]) };
  if (s.phase === 'playing') return { type: 'play', card: autoCard(s, seat) };
  throw new Error(`autopilot: no move in phase ${s.phase}`);
}

export function longestSuit(hand: readonly Card[]): Suit {
  let best: Suit = SUITS[0];
  let bestLen = -1;
  let bestStrength = -1;
  for (const suit of SUITS) {
    const cards = hand.filter((c) => suitOf(c) === suit);
    const strength = cards.reduce((a, c) => a + rankOf(c), 0);
    if (cards.length > bestLen || (cards.length === bestLen && strength > bestStrength)) {
      best = suit;
      bestLen = cards.length;
      bestStrength = strength;
    }
  }
  return best;
}

export const SYRIAN_AUTO_MAX_BID = 5;

export function syrianAutoBid(s: GameState, seat: Seat): number {
  const hand = s.hands[seat];
  const aces = hand.filter((c) => rankOf(c) === 14).length;
  const highTrumps = hand.filter((c) => suitOf(c) === s.trump && (rankOf(c) === 13 || rankOf(c) === 12)).length;
  let bid = Math.min(SYRIAN_AUTO_MAX_BID, Math.max(2, aces + highTrumps));
  const others = s.seatBids.filter((b, i) => i !== seat && b !== null) as number[];
  if (others.length === 3) {
    const sum = others.reduce((a, b) => a + b, 0);
    if (sum + bid < SYRIAN_MIN_TOTAL_BIDS) bid = Math.min(13, SYRIAN_MIN_TOTAL_BIDS - sum);
  }
  return bid;
}

function cost(c: Card, trump: Suit | null): number {
  return (suitOf(c) === trump ? 100 : 0) + rankOf(c);
}

export function autoCard(s: GameState, seat: Seat): Card {
  const legal = legalCards(s.hands[seat], s.trick).sort((a, b) => cost(a, s.trump) - cost(b, s.trump));
  if (legal.length === 0) throw new Error('autopilot: empty hand');
  const cheapest = legal[0];
  if (s.trick.length === 0) return cheapest;
  const current = trickWinner(s.trick, s.trump);
  if (current === partnerOf(seat)) return cheapest;
  const winning = legal.find((c) => trickWinner([...s.trick, { seat, card: c }], s.trump) === seat);
  return winning ?? cheapest;
}
