/**
 * 187 («بيع وشراء») — pure rules, no I/O. See docs/rules/187.md (source: docs/rules/reference-187).
 *
 * 4 or 5 players, each for themselves. 40 cards (2, 6..10, J, Q, K, A of each suit) worth 187 points in total.
 * The auction («السوم») runs from 87 to 187; the winner («المشتري») takes the face-down field, hands one hidden
 * card back to each opponent, names the trump («الحكم») and plays alone against everyone. They lose when the
 * opponents collect more than 187 − bid. First to reach +312 or −312 ends the match.
 *
 * A deal where any hand is worth less than 12 points is void and dealt again. The player right of the dealer
 * leads the first trick, and the lead then passes round the table in seat order (not to the trick's winner).
 */
import { type Card, type RandInt, type Suit, SUITS, card, isCard, rankOf, shuffle, suitOf } from './cards.ts';

export type B187Variant = 'b187';
export function isB187Variant(v: unknown): v is B187Variant {
  return v === 'b187';
}
/** Table sizes 187 can be played at (chosen when the room is created). */
export const B187_PLAYER_CHOICES: readonly number[] = [4, 5];

/** Ranks in the 40-card deck (11=J, 12=Q, 13=K, 14=A). */
export const B187_RANKS: readonly number[] = [2, 6, 7, 8, 9, 10, 11, 12, 13, 14];
/** Trick strength inside a suit: 2 > A > K > 10 > Q > J > 9 > 8 > 7 > 6. */
const POWER: Record<number, number> = { 2: 10, 14: 9, 13: 8, 10: 7, 12: 6, 11: 5, 9: 4, 8: 3, 7: 2, 6: 1 };
const BASE_POINTS: Record<number, number> = { 2: 10, 14: 11, 13: 4, 10: 10, 12: 4, 11: 4, 9: 0, 8: 0, 7: 0, 6: 0 };
export const B187_TOTAL = 187;
export const B187_MIN_BID = 87;
/** Once the bid reaches this, the field is shown face up to everyone. */
export const B187_REVEAL_AT = 140;
export const B187_MATCH_LIMIT = 312;
/** A deal is void (and dealt again) when any hand is worth less than this. */
export const B187_MIN_HAND_POINTS = 12;

export function b187Power(c: Card): number {
  return POWER[rankOf(c)];
}
/** Card points: A=11, 10=10, K/Q/J=4, each 2=10, the 2 of hearts («2 الشيريا») = 25, the rest 0. */
export function b187Points(c: Card): number {
  return c === 'H2' ? 25 : BASE_POINTS[rankOf(c)];
}
export function b187Deck(): Card[] {
  const out: Card[] = [];
  for (const s of SUITS) for (const r of B187_RANKS) out.push(card(s, r));
  return out;
}

/**
 * bidding   -> turn = seat to bid or withdraw
 * give      -> the buyer hands one card back to each opponent (turn = buyer)
 * trump     -> the buyer names the trump (turn = buyer)
 * playing   -> trick play
 * trickDone -> all cards of the trick on the table; the server calls advance187() after a pause
 * lossChoice-> the buyer lost: they choose −bid (opponents keep their points) or −187 (opponents get 0)
 * handOver  -> hand scored; the server deals the next hand
 * gameOver  -> someone reached +312 or −312
 */
export type B187Phase = 'bidding' | 'give' | 'trump' | 'playing' | 'trickDone' | 'lossChoice' | 'handOver' | 'gameOver';

export interface B187Play {
  seat: number;
  card: Card;
}

export interface B187Result {
  buyer: number;
  bid: number;
  /** points each seat collected in tricks this hand */
  collected: number[];
  /** buyer collected fewer than the bid */
  lost: boolean;
  /** the buyer took the full −187 */
  full: boolean;
  seatDelta: number[];
}

export interface B187State {
  variant: B187Variant;
  players: number;
  dealer: number;
  handNo: number;
  phase: B187Phase;
  hands: Card[][];
  /** the face-down cards in the middle, until the buyer takes them */
  field: Card[];
  /** the field cards just merged into the buyer's hand this hand (for the client to show which ones are new) */
  kittyTaken: Card[];
  turn: number;
  bidLog: { seat: number; bid: number | 'pass' }[];
  passed: boolean[];
  highBid: { seat: number; value: number } | null;
  buyer: number | null;
  trump: Suit | null;
  trick: B187Play[];
  lastTrick: { plays: B187Play[]; winner: number } | null;
  tricks: number[];
  /** cards each seat collected this hand */
  taken: Card[][];
  scores: number[];
  lastResult: B187Result | null;
  winnerSeats: number[];
  /** void deals thrown in before this hand's deal: the seats under 12 points in each, in order */
  redeals: B187Redeal[];
  /** kept for the shared game interface (unused: 187 has no teams) */
  teamScores: [number, number];
}

export interface B187Redeal {
  short: { seat: number; points: number }[];
}

export type B187Action =
  | { type: 'bid'; value: number | 'pass' }
  | { type: 'give'; cards: Card[] }
  | { type: 'trump'; suit: Suit }
  | { type: 'play'; card: Card }
  | { type: 'loss'; choice: 'bid' | 'full' };

export type B187ActResult = { ok: true; state: B187State } | { ok: false; error: string };

const next = (s: B187State, seat: number) => (seat + 1) % s.players;
const handSize = (players: number) => (players === 5 ? 7 : 9);

export function new187Game(opts: { players?: number; dealer?: number }, randInt: RandInt): B187State {
  const players = opts.players ?? 4;
  if (!B187_PLAYER_CHOICES.includes(players)) throw new Error('187: 4 or 5 players');
  const dealer = opts.dealer ?? randInt(players);
  const base: B187State = {
    variant: 'b187',
    players,
    dealer,
    handNo: 0,
    phase: 'bidding',
    hands: [],
    field: [],
    kittyTaken: [],
    turn: 0,
    bidLog: [],
    passed: [],
    highBid: null,
    buyer: null,
    trump: null,
    trick: [],
    lastTrick: null,
    tricks: [],
    taken: [],
    scores: Array(players).fill(0),
    lastResult: null,
    winnerSeats: [],
    redeals: [],
    teamScores: [0, 0],
  };
  return start187Hand(base, randInt, dealer);
}

/** Deal a hand for `dealer`, keeping scores. `preset` injects exact hands + field (tests). */
export function start187Hand(prev: B187State, randInt: RandInt, dealer: number, preset?: { hands: Card[][]; field: Card[] }): B187State {
  const n = prev.players;
  let hands: Card[][];
  let field: Card[];
  const redeals: B187Redeal[] = [];
  if (preset) {
    hands = preset.hands.map((h) => h.slice());
    field = preset.field.slice();
  } else {
    for (;;) {
      const deck = shuffle(b187Deck(), randInt);
      const size = handSize(n);
      hands = Array.from({ length: n }, () => [] as Card[]);
      // one card at a time, starting right of the dealer
      for (let i = 0; i < size * n; i++) hands[(dealer + 1 + (i % n)) % n].push(deck[i]);
      field = deck.slice(size * n);
      const short = hands.flatMap((h, seat) => {
        const points = h.reduce((a, c) => a + b187Points(c), 0);
        return points < B187_MIN_HAND_POINTS ? [{ seat, points }] : [];
      });
      if (short.length === 0) break;
      redeals.push({ short });
    }
  }
  return {
    ...structuredClone(prev),
    dealer,
    handNo: prev.handNo + 1,
    phase: 'bidding',
    hands,
    field,
    kittyTaken: [],
    turn: (dealer + 1) % n,
    bidLog: [],
    passed: Array(n).fill(false),
    highBid: null,
    buyer: null,
    trump: null,
    trick: [],
    lastTrick: null,
    tricks: Array(n).fill(0),
    taken: Array.from({ length: n }, () => [] as Card[]),
    redeals,
  };
}

/** Lowest bid allowed now: 87 to open, 90 right after 87, then at least +5 (never above 187). */
export function min187Bid(s: B187State): number {
  if (!s.highBid) return B187_MIN_BID;
  if (s.highBid.value === B187_MIN_BID) return 90;
  return Math.min(B187_TOTAL, s.highBid.value + 5);
}

export function fieldRevealed(s: B187State): boolean {
  return !!s.highBid && s.highBid.value >= B187_REVEAL_AT;
}

/** The last bid is the one that reached 140 and turned the field face up (the table pauses to look at it). */
export function b187JustRevealed(s: B187State): boolean {
  if (s.phase !== 'bidding' || !fieldRevealed(s)) return false;
  const bids = s.bidLog.flatMap((b) => (b.bid === 'pass' ? [] : [b.bid]));
  return bids.length > 0 && s.bidLog[s.bidLog.length - 1].bid === bids[bids.length - 1] && bids.filter((v) => v >= B187_REVEAL_AT).length === 1;
}

/** Must follow the led suit when able; otherwise any card (trump or not). */
export function b187Legal(hand: readonly Card[], trick: readonly B187Play[]): Card[] {
  if (trick.length === 0) return hand.slice();
  const led = suitOf(trick[0].card);
  const follow = hand.filter((c) => suitOf(c) === led);
  return follow.length > 0 ? follow : hand.slice();
}

/** Highest trump if any trump was played, else the strongest card of the led suit (2 > A > K > 10 > …). */
export function b187TrickWinner(trick: readonly B187Play[], trump: Suit | null): number {
  let best = trick[0];
  for (const p of trick.slice(1)) {
    const ps = suitOf(p.card);
    const bs = suitOf(best.card);
    if (trump && ps === trump && bs !== trump) best = p;
    else if (ps === bs && b187Power(p.card) > b187Power(best.card)) best = p;
  }
  return best.seat;
}

export function act187(prev: B187State, seat: number, a: B187Action): B187ActResult {
  if (prev.phase === 'gameOver') return { ok: false, error: 'gameOver' };
  if (seat !== prev.turn) return { ok: false, error: 'notYourTurn' };
  const s = structuredClone(prev);
  switch (a.type) {
    case 'bid':
      return bid(s, seat, a.value);
    case 'give':
      return give(s, seat, a.cards);
    case 'trump':
      if (s.phase !== 'trump') return { ok: false, error: 'wrongPhase' };
      if (!SUITS.includes(a.suit)) return { ok: false, error: 'badSuit' };
      s.trump = a.suit;
      s.phase = 'playing';
      s.turn = (s.dealer + 1) % s.players; // the player right of the dealer leads, whoever bought
      return { ok: true, state: s };
    case 'play':
      return play(s, seat, a.card);
    case 'loss':
      return lossChoice(s, seat, a.choice);
    default:
      return { ok: false, error: 'badAction' };
  }
}

function bid(s: B187State, seat: number, value: number | 'pass'): B187ActResult {
  if (s.phase !== 'bidding') return { ok: false, error: 'wrongPhase' };
  if (value === 'pass') {
    s.passed[seat] = true;
  } else {
    if (!Number.isInteger(value) || value < min187Bid(s) || value > B187_TOTAL) return { ok: false, error: 'badBid' };
    s.highBid = { seat, value };
  }
  s.bidLog.push({ seat, bid: value });
  const active = s.passed.flatMap((p, i) => (p ? [] : [i]));
  if (s.highBid?.value === B187_TOTAL) return endAuction(s, s.highBid.seat);
  if (active.length === 1) {
    // everyone else withdrew; with no bid at all the last one is forced to buy at 87
    if (!s.highBid) s.highBid = { seat: active[0], value: B187_MIN_BID };
    return endAuction(s, s.highBid.seat);
  }
  let t = next(s, seat);
  while (s.passed[t]) t = next(s, t);
  s.turn = t;
  return { ok: true, state: s };
}

function endAuction(s: B187State, buyer: number): B187ActResult {
  s.buyer = buyer;
  s.kittyTaken = s.field.slice();
  s.hands[buyer] = [...s.hands[buyer], ...s.field];
  s.field = [];
  s.phase = 'give';
  s.turn = buyer;
  return { ok: true, state: s };
}

/** Opponents in turn order from the buyer's right; the i-th given card goes to the i-th of them. */
export function b187Opponents(s: B187State): number[] {
  const out: number[] = [];
  for (let i = 1; i < s.players; i++) out.push((s.buyer! + i) % s.players);
  return out;
}

function give(s: B187State, seat: number, cards: Card[]): B187ActResult {
  if (s.phase !== 'give') return { ok: false, error: 'wrongPhase' };
  const need = s.players - 1;
  if (!Array.isArray(cards) || cards.length !== need || !cards.every(isCard) || new Set(cards).size !== need) return { ok: false, error: 'badGive' };
  if (!cards.every((c) => s.hands[seat].includes(c))) return { ok: false, error: 'notInHand' };
  s.hands[seat] = s.hands[seat].filter((c) => !cards.includes(c));
  b187Opponents(s).forEach((opp, i) => s.hands[opp].push(cards[i]));
  s.phase = 'trump';
  return { ok: true, state: s };
}

function play(s: B187State, seat: number, c: Card): B187ActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isCard(c)) return { ok: false, error: 'badCard' };
  const hand = s.hands[seat];
  if (!hand.includes(c)) return { ok: false, error: 'notInHand' };
  if (!b187Legal(hand, s.trick).includes(c)) return { ok: false, error: 'mustFollowSuit' };
  s.hands[seat] = hand.filter((x) => x !== c);
  s.trick.push({ seat, card: c });
  if (s.trick.length === s.players) {
    s.phase = 'trickDone';
    s.turn = b187TrickWinner(s.trick, s.trump);
  } else {
    s.turn = next(s, seat);
  }
  return { ok: true, state: s };
}

/** Server-driven transitions: collect a finished trick, or deal the next hand. */
export function advance187(prev: B187State, randInt: RandInt): B187State {
  if (prev.phase === 'trickDone') return collect(prev);
  if (prev.phase === 'handOver') return start187Hand(prev, randInt, (prev.dealer + 1) % prev.players);
  return prev;
}

function collect(prev: B187State): B187State {
  const s = structuredClone(prev);
  const winner = b187TrickWinner(s.trick, s.trump);
  s.tricks[winner]++;
  s.taken[winner].push(...s.trick.map((p) => p.card));
  const leader = s.trick[0].seat;
  s.lastTrick = { plays: s.trick, winner };
  s.trick = [];
  s.turn = next(s, leader); // the lead goes round in seat order, not to the winner
  if (s.hands.some((h) => h.length > 0)) {
    s.phase = 'playing';
    return s;
  }
  const collected = s.taken.map((t) => t.reduce((a, c) => a + b187Points(c), 0));
  const buyer = s.buyer!;
  const bidValue = s.highBid!.value;
  const lost = collected[buyer] < bidValue; // same as: opponents collected more than 187 − bid
  s.lastResult = { buyer, bid: bidValue, collected, lost, full: false, seatDelta: collected.slice() };
  if (lost) {
    s.phase = 'lossChoice';
    s.turn = buyer;
    return s;
  }
  return applyResult(s);
}

function lossChoice(s: B187State, seat: number, choice: 'bid' | 'full'): B187ActResult {
  if (s.phase !== 'lossChoice' || seat !== s.buyer) return { ok: false, error: 'wrongPhase' };
  if (choice !== 'bid' && choice !== 'full') return { ok: false, error: 'badChoice' };
  const r = s.lastResult!;
  r.full = choice === 'full';
  r.seatDelta = r.collected.map((pts, i) => (i === seat ? -(r.full ? B187_TOTAL : r.bid) : r.full ? 0 : pts));
  return { ok: true, state: applyResult(s) };
}

function applyResult(s: B187State): B187State {
  const r = s.lastResult!;
  s.scores = s.scores.map((v, i) => v + r.seatDelta[i]);
  if (s.scores.some((v) => Math.abs(v) >= B187_MATCH_LIMIT)) {
    const best = Math.max(...s.scores);
    s.winnerSeats = s.scores.flatMap((v, i) => (v === best ? [i] : []));
    s.phase = 'gameOver';
  } else {
    s.phase = 'handOver';
  }
  return s;
}

// ---------------------------------------------------------------------------
// View: what one seat may see.

export interface B187View {
  variant: B187Variant;
  players: number;
  phase: B187Phase;
  handNo: number;
  dealer: number;
  turn: number;
  mySeat: number;
  myHand: Card[];
  legal: Card[];
  /** lowest bid I may make (my turn to bid) */
  minBid: number | null;
  /** how many cards I must give back (buyer, give phase) */
  giveCount: number;
  /** the field cards just added to my hand (buyer, give phase only): lets the client show which cards are new */
  kittyCards: Card[];
  fieldCount: number;
  /** the field face up (once the bid reached 140), else empty */
  field: Card[];
  bidLog: { seat: number; bid: number | 'pass' }[];
  passed: boolean[];
  highBid: { seat: number; value: number } | null;
  buyer: number | null;
  trump: Suit | null;
  handCounts: number[];
  trick: B187Play[];
  lastTrick: { plays: B187Play[]; winner: number } | null;
  tricks: number[];
  /** points each seat collected so far this hand (tricks are played face up) */
  collected: number[];
  scores: number[];
  lastResult: B187Result | null;
  winnerSeats: number[];
  /** void deals thrown in before this hand (someone held under 12 points) */
  redeals: B187Redeal[];
}

export function b187ViewFor(s: B187State, seat: number): B187View {
  const myTurn = s.turn === seat;
  return {
    variant: s.variant,
    players: s.players,
    phase: s.phase,
    handNo: s.handNo,
    dealer: s.dealer,
    turn: s.turn,
    mySeat: seat,
    myHand: s.hands[seat].slice(),
    legal: myTurn && s.phase === 'playing' ? b187Legal(s.hands[seat], s.trick) : [],
    minBid: myTurn && s.phase === 'bidding' ? min187Bid(s) : null,
    giveCount: myTurn && s.phase === 'give' ? s.players - 1 : 0,
    kittyCards: seat === s.buyer && s.phase === 'give' ? s.kittyTaken.slice() : [],
    fieldCount: s.field.length,
    field: fieldRevealed(s) ? s.field.slice() : [],
    bidLog: s.bidLog.map((b) => ({ ...b })),
    passed: s.passed.slice(),
    highBid: s.highBid ? { ...s.highBid } : null,
    buyer: s.buyer,
    trump: s.trump,
    handCounts: s.hands.map((h) => h.length),
    trick: s.trick.map((p) => ({ ...p })),
    lastTrick: s.lastTrick ? { plays: s.lastTrick.plays.map((p) => ({ ...p })), winner: s.lastTrick.winner } : null,
    tricks: s.tricks.slice(),
    collected: s.taken.map((t) => t.reduce((a, c) => a + b187Points(c), 0)),
    scores: s.scores.slice(),
    lastResult: s.lastResult ? structuredClone(s.lastResult) : null,
    winnerSeats: s.winnerSeats.slice(),
    redeals: structuredClone(s.redeals ?? []),
  };
}

// ---------------------------------------------------------------------------
// Autopilot (also drives computer players). Pure, deterministic, always legal.

/** Rough value of a hand: its points plus a bonus for the strongest cards (2s and Aces win tricks). */
function handStrength(hand: readonly Card[]): number {
  return hand.reduce((a, c) => a + b187Points(c) + (rankOf(c) === 2 || rankOf(c) === 14 ? 6 : 0), 0);
}

/**
 * - Bid: raise to the minimum while it stays under a cap derived from hand strength, else withdraw. Up to 140 the
 *   cap counts the hand alone (never past 140); once the field is face up it counts the field too (up to 165).
 * - Give: the cheapest cards (no points, weakest), from the shortest suits.
 * - Trump: the suit with the most cards, ties -> the stronger one.
 * - Play: take the trick with the cheapest winning card when it matters (points on the table, or last to play);
 *   an opponent of the buyer does not over-take another opponent; otherwise throw the cheapest legal card.
 * - Loss: −187 when an opponent would otherwise gain more than 187 − bid (keeps the buyer closer to the leader).
 */
export function auto187Action(s: B187State, seat: number): B187Action {
  const hand = s.hands[seat];
  switch (s.phase) {
    case 'bidding': {
      const min = min187Bid(s);
      const cap = fieldRevealed(s) ? Math.min(165, 45 + handStrength([...hand, ...s.field])) : Math.min(B187_REVEAL_AT, 60 + handStrength(hand));
      const others = s.passed.filter((p, i) => i !== seat && !p).length;
      if (!s.highBid && others === 0) return { type: 'bid', value: B187_MIN_BID };
      return { type: 'bid', value: min <= cap ? min : 'pass' };
    }
    case 'give': {
      const len = (suit: Suit) => hand.filter((c) => suitOf(c) === suit).length;
      const cheap = hand
        .slice()
        .sort((a, b) => b187Points(a) - b187Points(b) || b187Power(a) - b187Power(b) || len(suitOf(a)) - len(suitOf(b)) || a.localeCompare(b));
      return { type: 'give', cards: cheap.slice(0, s.players - 1) };
    }
    case 'trump': {
      let best: Suit = SUITS[0];
      let key = -1;
      for (const suit of SUITS) {
        const cs = hand.filter((c) => suitOf(c) === suit);
        const k = cs.length * 100 + cs.reduce((a, c) => a + b187Power(c), 0);
        if (k > key) {
          key = k;
          best = suit;
        }
      }
      return { type: 'trump', suit: best };
    }
    case 'playing':
      return { type: 'play', card: autoPlay(s, seat) };
    case 'lossChoice': {
      const r = s.lastResult!;
      const maxOpp = Math.max(...r.collected.filter((_, i) => i !== seat));
      return { type: 'loss', choice: r.bid + maxOpp > B187_TOTAL ? 'full' : 'bid' };
    }
    default:
      throw new Error(`187 autopilot: no move in phase ${s.phase}`);
  }
}

function autoPlay(s: B187State, seat: number): Card {
  const legal = b187Legal(s.hands[seat], s.trick);
  if (legal.length === 0) throw new Error('187 autopilot: empty hand');
  const cost = (c: Card) => (suitOf(c) === s.trump ? 1000 : 0) + b187Points(c) * 10 + b187Power(c);
  const cheapest = legal.slice().sort((a, b) => cost(a) - cost(b) || a.localeCompare(b))[0];
  if (s.trick.length === 0) return cheapest;
  const current = b187TrickWinner(s.trick, s.trump);
  const buyer = s.buyer!;
  if (seat !== buyer && current !== buyer) return cheapest; // a fellow opponent is already winning
  const onTable = s.trick.reduce((a, p) => a + b187Points(p.card), 0);
  const last = s.trick.length === s.players - 1;
  if (onTable === 0 && !last) return cheapest;
  const winners = legal.filter((c) => b187TrickWinner([...s.trick, { seat, card: c }], s.trump) === seat);
  return winners.length > 0 ? winners.sort((a, b) => cost(a) - cost(b) || a.localeCompare(b))[0] : cheapest;
}
