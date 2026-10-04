import { type Card, type Seat, type Suit, SUITS, partnerOf, rankOf, suitOf } from './cards.ts';
import { type Action, type GameState, minBid, minTotalBids } from './game.ts';
import { legalCards, trickWinner } from './trick.ts';

/**
 * «الطيار الآلي»: plays ONE move for `seat` when its turn timer runs out or the player is away.
 * Pure and deterministic (same state -> same move) and always legal.
 *
 * - Tarneeb bidding: an estimate of the hand's tricks (aces, guarded kings, length in the longest suit) opens or
 *   raises when the team can make it; never over the partner. The last seat after three passes bids 7, so a
 *   table of computers (or of absent players) never redeals for ever.
 * - Tarneeb trump (autopilot won the auction): longest suit in hand; tie -> stronger suit (higher rank sum).
 * - Syrian / 400 bidding: aces + Q/K of trump, clamped to the seat's minimum..5. If it is the LAST bid and
 *   the total would stay under the minimum total (11; 400: up to 14), it tops up to reach it exactly
 *   (avoids endless redeals when several seats are on autopilot).
 * - Play: if partner is currently winning the trick -> cheapest legal card. Otherwise, if some legal card
 *   wins the trick right now -> the cheapest such card. Otherwise -> cheapest legal card.
 *   "Cheapest" = non-trump before trump, then lower rank.
 */
export function autoAction(s: GameState, seat: Seat): Action {
  if (s.phase === 'bidding') {
    if (s.variant === 'tarneeb') return { type: 'bid', value: tarneebAutoBid(s, seat) };
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

/** Tricks the hand should take by itself: aces, kings with a guard, and the long suit's extra length. */
export function handTricks(hand: readonly Card[]): number {
  let t = 0;
  for (const suit of SUITS) {
    const cards = hand.filter((c) => suitOf(c) === suit);
    if (cards.some((c) => rankOf(c) === 14)) t++;
    if (cards.length >= 2 && cards.some((c) => rankOf(c) === 13)) t++;
    t += Math.max(0, cards.length - 4);
  }
  return t;
}

export function tarneebAutoBid(s: GameState, seat: Seat): number | 'pass' {
  const min = minBid(s);
  if (!s.highBid && s.passed.filter(Boolean).length === 3) return 7;
  if (s.highBid && s.highBid.seat === partnerOf(seat)) return 'pass';
  // the partner is counted for three tricks
  const reach = handTricks(s.hands[seat]) + 3;
  return reach >= min && min <= 9 ? min : 'pass';
}

export const SYRIAN_AUTO_MAX_BID = 5;

export function syrianAutoBid(s: GameState, seat: Seat): number {
  const hand = s.hands[seat];
  const aces = hand.filter((c) => rankOf(c) === 14).length;
  const highTrumps = hand.filter((c) => suitOf(c) === s.trump && (rankOf(c) === 13 || rankOf(c) === 12)).length;
  // never under this seat's minimum (400 raises it with the seat's score)
  const floor = minBid({ ...s, turn: seat });
  let bid = Math.max(floor, Math.min(SYRIAN_AUTO_MAX_BID, Math.max(2, aces + highTrumps)));
  const others = s.seatBids.filter((b, i) => i !== seat && b !== null) as number[];
  if (others.length === 3) {
    const sum = others.reduce((a, b) => a + b, 0);
    const need = minTotalBids(s);
    if (sum + bid < need) bid = Math.min(13, need - sum);
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
