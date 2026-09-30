/** Card primitives. A card is encoded as `${suit}${rank}`, e.g. "H14" = Ace of hearts, "S10" = ten of spades. */
export type Suit = 'S' | 'H' | 'D' | 'C';
export type Card = string;
export type Seat = 0 | 1 | 2 | 3;
export type Team = 0 | 1;

export const SUITS: readonly Suit[] = ['S', 'H', 'D', 'C'];
/** 2..14 where 11=J, 12=Q, 13=K, 14=A (Ace is the highest). */
export const RANKS: readonly number[] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

/** Random integer in [0, n). The server injects crypto.randomInt; tests inject a seeded RNG. */
export type RandInt = (n: number) => number;

export function card(suit: Suit, rank: number): Card {
  return `${suit}${rank}`;
}
export function suitOf(c: Card): Suit {
  return c[0] as Suit;
}
export function rankOf(c: Card): number {
  return Number(c.slice(1));
}
export function isCard(x: unknown): x is Card {
  if (typeof x !== 'string' || x.length < 2 || x.length > 3) return false;
  const s = x[0];
  const r = Number(x.slice(1));
  return (SUITS as readonly string[]).includes(s) && Number.isInteger(r) && r >= 2 && r <= 14 && String(r) === x.slice(1);
}

export function fullDeck(): Card[] {
  const out: Card[] = [];
  for (const s of SUITS) for (const r of RANKS) out.push(card(s, r));
  return out;
}

/** Fisher-Yates using the injected RNG. Returns a new array. */
export function shuffle<T>(arr: readonly T[], randInt: RandInt): T[] {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Next seat in play order (counter-clockwise = the player on your right). */
export function nextSeat(s: Seat): Seat {
  return ((s + 1) % 4) as Seat;
}
export function teamOf(s: Seat): Team {
  return (s % 2) as Team;
}
export function partnerOf(s: Seat): Seat {
  return ((s + 2) % 4) as Seat;
}

/** Deal 13 cards to each seat, starting from the seat to the dealer's right; the dealer receives the last card. */
export function deal(randInt: RandInt, dealer: Seat): { hands: Card[][]; lastCardOfDealer: Card } {
  const deck = shuffle(fullDeck(), randInt);
  const hands: Card[][] = [[], [], [], []];
  let s = nextSeat(dealer);
  for (const c of deck) {
    hands[s].push(c);
    s = nextSeat(s);
  }
  // 52 cards, 4 seats, starting right of dealer: the 52nd card lands on the dealer.
  const lastCardOfDealer = deck[deck.length - 1];
  return { hands: hands.map(sortHand), lastCardOfDealer };
}

const SUIT_ORDER: Record<Suit, number> = { S: 0, H: 1, C: 2, D: 3 };
export function sortHand(h: Card[]): Card[] {
  return h.slice().sort((a, b) => SUIT_ORDER[suitOf(a)] - SUIT_ORDER[suitOf(b)] || rankOf(b) - rankOf(a));
}

/** Syrian 41: trump is the other suit of the same colour as the revealed card (H<->D, S<->C). */
export function sisterSuit(s: Suit): Suit {
  return ({ H: 'D', D: 'H', S: 'C', C: 'S' } as const)[s];
}
