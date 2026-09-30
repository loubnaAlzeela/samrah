import { type Card, type Seat, type Suit, rankOf, suitOf } from './cards.ts';

export interface Play {
  seat: Seat;
  card: Card;
}

/** Cards a player may legally play: must follow the led suit if able, otherwise anything. */
export function legalCards(hand: readonly Card[], trick: readonly Play[]): Card[] {
  if (trick.length === 0) return hand.slice();
  const led = suitOf(trick[0].card);
  const follow = hand.filter((c) => suitOf(c) === led);
  return follow.length > 0 ? follow : hand.slice();
}

/** Winner of a (complete or partial) trick: highest trump if any trump was played, else highest of the led suit. */
export function trickWinner(trick: readonly Play[], trump: Suit | null): Seat {
  if (trick.length === 0) throw new Error('empty trick');
  let best = trick[0];
  for (const p of trick.slice(1)) {
    const ps = suitOf(p.card);
    const bs = suitOf(best.card);
    if (trump && ps === trump && bs !== trump) best = p;
    else if (ps === bs && rankOf(p.card) > rankOf(best.card)) best = p;
    // a card that is neither trump nor the current winning suit can never win
  }
  return best.seat;
}
