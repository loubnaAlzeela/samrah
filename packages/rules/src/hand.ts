/**
 * Saudi Hand («هاند سعودي») — pure rules, no I/O. See docs/rules/hand.md.
 *
 * 2..5 players, each for themselves. Two decks + 2 jokers (106 cards). 14 cards each; the player right of the dealer
 * gets 15 and starts by discarding. A turn: draw from the stock or take the top of the discard pile («كومة النار»),
 * lay down melds / add to melds on the table, discard one card. A player's first lay-down must total 51+, and each
 * later opener must beat the last opening by 1. The round ends when a hand is empty; lowest total after 5 rounds wins.
 *
 * Cards carry a copy letter because there are two decks: "S5a" / "S5b" = five of spades, "Xa" / "Xb" = jokers.
 */
import { type RandInt, type Suit, SUITS, shuffle } from './cards.ts';

export type HandVariant = 'hand';
export function isHandVariant(v: unknown): v is HandVariant {
  return v === 'hand';
}

export type HandCard = string;
export const HAND_ROUNDS = 5;
export const HAND_OPEN_MIN = 51;
export const HAND_CARDS = 14;
export const HAND_MIN_PLAYERS = 2;
export const HAND_MAX_PLAYERS = 5;
export const HAND_PLAYER_CHOICES: readonly number[] = [2, 3, 4, 5];
/** Round points: going out −30 (a «هاند» −60), a player who never laid down +100. */
export const HAND_WIN = -30;
export const HAND_NOT_OPENED = 100;
export const HAND_JOKER_VALUE = 15;
/** When the stock runs out, the discard pile (minus its top) is shuffled back at most this many times per round. */
export const HAND_MAX_RESHUFFLES = 2;

export function isJoker(c: HandCard): boolean {
  return c[0] === 'X';
}
export function handSuit(c: HandCard): Suit {
  return c[0] as Suit;
}
/** 2..14 (11 J, 12 Q, 13 K, 14 A). */
export function handRank(c: HandCard): number {
  return parseInt(c.slice(1), 10);
}

export function isHandCard(x: unknown): x is HandCard {
  if (typeof x !== 'string') return false;
  if (x === 'Xa' || x === 'Xb') return true;
  const m = /^([SHDC])(\d{1,2})([ab])$/.exec(x);
  if (!m) return false;
  const r = Number(m[2]);
  return r >= 2 && r <= 14 && String(r) === m[2];
}

export function handDeck(): HandCard[] {
  const out: HandCard[] = [];
  for (const copy of ['a', 'b']) for (const s of SUITS) for (let r = 2; r <= 14; r++) out.push(`${s}${r}${copy}`);
  out.push('Xa', 'Xb');
  return out;
}

/** Points of a card left in the hand at the end of a round: A 11, J/Q/K 10, joker 15, else its number. */
export function handCardPoints(c: HandCard): number {
  if (isJoker(c)) return HAND_JOKER_VALUE;
  const r = handRank(c);
  return r === 14 ? 11 : r >= 11 ? 10 : r;
}

/** Value of a represented rank on the table (1 = ace low in A-2-3). */
function rankValue(rank: number): number {
  return rank === 1 ? 1 : rank === 14 ? 11 : rank >= 11 ? 10 : rank;
}

export interface MeldCard {
  card: HandCard;
  /** the rank this card stands for: 1..14 (1 = ace low); a joker takes the rank it replaces */
  rank: number;
  /** runs: the suit; sets: the real card's suit, null for a joker */
  suit: Suit | null;
}

export interface Meld {
  id: number;
  owner: number;
  kind: 'run' | 'set';
  cards: MeldCard[];
}

export function meldValue(m: { cards: MeldCard[] }): number {
  return m.cards.reduce((a, c) => a + rankValue(c.rank), 0);
}

/**
 * Arrange cards into a meld, or null. A set: 3-4 cards of one rank in different suits. A run: 3+ consecutive cards
 * of one suit (A-2-3 … Q-K-A, no wrap). Jokers stand in for missing cards; at least 2 real cards per meld.
 * Run jokers fill the gaps first, then extend the top, then the bottom.
 */
export function arrangeMeld(cards: readonly HandCard[]): { kind: 'run' | 'set'; cards: MeldCard[] } | null {
  if (cards.length < 3 || new Set(cards).size !== cards.length) return null;
  const reals = cards.filter((c) => !isJoker(c));
  const jokers = cards.filter(isJoker);
  if (reals.length < 2) return null;
  const rank0 = handRank(reals[0]);
  if (reals.every((c) => handRank(c) === rank0)) {
    const suits = reals.map(handSuit);
    if (new Set(suits).size !== suits.length || cards.length > 4) return null;
    return {
      kind: 'set',
      cards: [...reals.map((c) => ({ card: c, rank: rank0, suit: handSuit(c) })), ...jokers.map((c) => ({ card: c, rank: rank0, suit: null }))],
    };
  }
  const suit = handSuit(reals[0]);
  if (!reals.every((c) => handSuit(c) === suit)) return null;
  const hasAce = reals.some((c) => handRank(c) === 14);
  for (const aceLow of hasAce ? [false, true] : [false]) {
    const r = reals.map((c) => ({ card: c, rank: handRank(c) === 14 && aceLow ? 1 : handRank(c) })).sort((a, b) => a.rank - b.rank);
    if (new Set(r.map((x) => x.rank)).size !== r.length) continue;
    const lo = r[0].rank;
    const hi = r[r.length - 1].rank;
    const gaps = hi - lo + 1 - r.length;
    let extra = jokers.length - gaps;
    if (extra < 0) continue;
    // extend with the leftover jokers: upwards first, then downwards (A-2-3 … Q-K-A, never both aces)
    const min = aceLow ? 1 : 2;
    const max = aceLow ? 13 : 14;
    const up = Math.min(extra, max - hi);
    extra -= up;
    const bottom = lo - extra;
    if (bottom < min) continue;
    const out: MeldCard[] = [];
    let j = 0;
    let k = 0;
    for (let rank = bottom; rank <= hi + up; rank++) {
      if (k < r.length && r[k].rank === rank) out.push({ card: r[k++].card, rank, suit });
      else out.push({ card: jokers[j++], rank, suit });
    }
    return { kind: 'run', cards: out };
  }
  return null;
}

/**
 * Add one card to a meld on the table. A real card that matches what a joker stands for takes the joker's place
 * (runs), or completes the set's four suits (sets); the freed joker goes back to the player's hand.
 */
export function layoffCard(m: Meld, c: HandCard): { cards: MeldCard[]; freed: HandCard | null } | null {
  const cards = m.cards.map((x) => ({ ...x }));
  if (m.kind === 'set') {
    const rank = cards[0].rank;
    if (isJoker(c)) return cards.length < 4 ? { cards: [...cards, { card: c, rank, suit: null }], freed: null } : null;
    if (handRank(c) !== rank || cards.some((x) => x.suit === handSuit(c))) return null;
    if (cards.length < 4) return { cards: [...cards, { card: c, rank, suit: handSuit(c) }], freed: null };
    const i = cards.findIndex((x) => isJoker(x.card));
    if (i < 0) return null;
    const freed = cards[i].card;
    cards[i] = { card: c, rank, suit: handSuit(c) };
    return { cards, freed };
  }
  const suit = cards.find((x) => x.suit)!.suit!;
  const lo = cards[0].rank;
  const hi = cards[cards.length - 1].rank;
  // a run holds the ace low (1) or high (14), never both
  const min = hi === 14 ? 2 : 1;
  const max = lo === 1 ? 13 : 14;
  const place = (card: HandCard, ranks: number[]) => {
    for (const rank of ranks) {
      if (rank === hi + 1 && rank <= max) return { cards: [...cards, { card, rank, suit }], freed: null };
      if (rank === lo - 1 && rank >= min) return { cards: [{ card, rank, suit }, ...cards], freed: null };
    }
    return null;
  };
  if (isJoker(c)) return place(c, [hi + 1, lo - 1]);
  if (handSuit(c) !== suit) return null;
  const r = handRank(c);
  const ranks = r === 14 ? [14, 1] : [r];
  for (const rank of ranks) {
    const i = cards.findIndex((x) => isJoker(x.card) && x.rank === rank);
    if (i >= 0) {
      const freed = cards[i].card;
      cards[i] = { card: c, rank, suit };
      return { cards, freed };
    }
  }
  return place(c, ranks);
}

/**
 * draw     -> the player to act draws from the stock or takes the top of the discard pile
 * playing  -> lay down / add to melds, then discard (turn = that player)
 * handOver -> round scored; the server calls advanceHand() to deal the next round
 * gameOver -> 5 rounds played
 */
export type HandPhase = 'draw' | 'playing' | 'handOver' | 'gameOver';

export interface HandRoundResult {
  /** seat that went out, null when the stock ran dry */
  winner: number | null;
  /** went out with a «هاند»: everything laid down at once, points doubled */
  hand: boolean;
  delta: number[];
  /** cards left in each hand */
  left: HandCard[][];
  opened: boolean[];
}

export interface HandState {
  variant: HandVariant;
  players: number;
  dealer: number;
  /** round number, 1..5 */
  handNo: number;
  phase: HandPhase;
  hands: HandCard[][];
  stock: HandCard[];
  /** discard pile, top = last */
  fire: HandCard[];
  melds: Meld[];
  nextMeldId: number;
  opened: boolean[];
  /** the lowest total the next opening may have */
  openMin: number;
  turn: number;
  /** the current turn: how the player drew, and what they did so far */
  drew: 'start' | 'stock' | 'fire' | null;
  /** taken from the discard pile this turn: must go on the table in the player's next lay-down */
  fireCard: HandCard | null;
  openAtTurnStart: boolean;
  laidOffThisTurn: boolean;
  actedThisTurn: boolean;
  reshuffles: number;
  /** internal PRNG state (reshuffling the discard pile back into the stock) */
  rng: number;
  scores: number[];
  lastResult: HandRoundResult | null;
  /** lowest total after the last round (several on a tie) */
  winners: number[];
  /** kept empty: the server treats every moment as "between tricks" */
  trick: never[];
}

export type HandAction =
  | { type: 'draw'; from: 'stock' | 'fire' }
  | { type: 'undoFire' }
  | { type: 'meld'; groups: HandCard[][] }
  | { type: 'layoff'; card: HandCard; meld: number }
  | { type: 'discard'; card: HandCard };

export type HandActResult = { ok: true; state: HandState } | { ok: false; error: string };

const next = (s: HandState, seat: number) => (seat + 1) % s.players;

/** mulberry32 step over the state's seed. */
function stateRand(s: HandState): RandInt {
  return (n: number) => {
    s.rng = (s.rng + 0x6d2b79f5) >>> 0;
    let t = s.rng;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return Math.floor((((t ^ (t >>> 14)) >>> 0) / 4294967296) * n);
  };
}

export function newHandGame(opts: { players?: number; dealer?: number }, randInt: RandInt): HandState {
  const players = opts.players ?? 4;
  if (!Number.isInteger(players) || players < HAND_MIN_PLAYERS || players > HAND_MAX_PLAYERS) throw new Error('hand: 2..5 players');
  const base: HandState = {
    variant: 'hand',
    players,
    dealer: opts.dealer ?? randInt(players),
    handNo: 0,
    phase: 'draw',
    hands: [],
    stock: [],
    fire: [],
    melds: [],
    nextMeldId: 1,
    opened: [],
    openMin: HAND_OPEN_MIN,
    turn: 0,
    drew: null,
    fireCard: null,
    openAtTurnStart: false,
    laidOffThisTurn: false,
    actedThisTurn: false,
    reshuffles: 0,
    rng: 0,
    scores: Array(players).fill(0),
    lastResult: null,
    winners: [],
    trick: [],
  };
  return startHandRound(base, randInt, { dealer: base.dealer });
}

/**
 * Deal a round, keeping the scores: 14 cards each from the dealer's right, a 15th to that first player, who starts
 * by discarding. `preset.deck` fixes the order (tests): cards are dealt one at a time around the table.
 */
export function startHandRound(prev: HandState, randInt: RandInt, preset?: { dealer?: number; deck?: HandCard[] }): HandState {
  const s = structuredClone(prev);
  s.dealer = preset?.dealer ?? prev.dealer;
  const deck = preset?.deck ? preset.deck.slice() : shuffle(handDeck(), randInt);
  const first = next(s, s.dealer);
  s.hands = Array.from({ length: s.players }, () => []);
  for (let i = 0; i < HAND_CARDS * s.players; i++) s.hands[(first + i) % s.players].push(deck.shift()!);
  s.hands[first].push(deck.shift()!);
  s.hands = s.hands.map(sortHandCards);
  s.stock = deck;
  s.fire = [];
  s.melds = [];
  s.nextMeldId = 1;
  s.opened = Array(s.players).fill(false);
  s.openMin = HAND_OPEN_MIN;
  s.handNo = prev.handNo + 1;
  s.reshuffles = 0;
  s.rng = randInt(2 ** 31);
  s.winners = [];
  startTurn(s, first, 'start');
  return s;
}

function startTurn(s: HandState, seat: number, drew: 'start' | null) {
  s.turn = seat;
  s.phase = drew === 'start' ? 'playing' : 'draw';
  s.drew = drew;
  s.fireCard = null;
  s.openAtTurnStart = s.opened[seat];
  s.laidOffThisTurn = false;
  s.actedThisTurn = false;
}

const SUIT_ORDER: Record<Suit, number> = { S: 0, H: 1, C: 2, D: 3 };
export function sortHandCards(h: HandCard[]): HandCard[] {
  return h.slice().sort((a, b) => {
    if (isJoker(a) !== isJoker(b)) return isJoker(a) ? -1 : 1;
    if (isJoker(a)) return a.localeCompare(b);
    return SUIT_ORDER[handSuit(a)] - SUIT_ORDER[handSuit(b)] || handRank(a) - handRank(b) || a.localeCompare(b);
  });
}

export function actHand(prev: HandState, seat: number, a: HandAction): HandActResult {
  if (prev.phase === 'gameOver' || prev.phase === 'handOver') return { ok: false, error: 'wrongPhase' };
  if (seat !== prev.turn) return { ok: false, error: 'notYourTurn' };
  const s = structuredClone(prev);
  switch (a.type) {
    case 'draw':
      return draw(s, a.from);
    case 'undoFire':
      return undoFire(s);
    case 'meld':
      return meld(s, seat, a.groups);
    case 'layoff':
      return layoff(s, seat, a.card, a.meld);
    case 'discard':
      return discard(s, seat, a.card);
    default:
      return { ok: false, error: 'badAction' };
  }
}

function draw(s: HandState, from: 'stock' | 'fire'): HandActResult {
  if (s.phase !== 'draw') return { ok: false, error: 'wrongPhase' };
  if (from === 'fire') {
    if (s.fire.length === 0) return { ok: false, error: 'fireEmpty' };
    const c = s.fire.pop()!;
    s.hands[s.turn].push(c);
    s.fireCard = c;
  } else if (from === 'stock') {
    if (s.stock.length === 0) {
      if (s.fire.length <= 1 || s.reshuffles >= HAND_MAX_RESHUFFLES) return { ok: true, state: scoreRound(s, null) };
      const top = s.fire.pop()!;
      s.stock = shuffle(s.fire, stateRand(s));
      s.fire = [top];
      s.reshuffles++;
    }
    s.hands[s.turn].push(s.stock.shift()!);
  } else {
    return { ok: false, error: 'badAction' };
  }
  s.hands[s.turn] = sortHandCards(s.hands[s.turn]);
  s.drew = from;
  s.phase = 'playing';
  return { ok: true, state: s };
}

/** Put the card taken from the discard pile back (only before laying anything down); then draw from the stock. */
function undoFire(s: HandState): HandActResult {
  if (s.phase !== 'playing' || !s.fireCard || s.actedThisTurn) return { ok: false, error: 'wrongPhase' };
  s.hands[s.turn] = s.hands[s.turn].filter((c) => c !== s.fireCard);
  s.fire.push(s.fireCard);
  s.fireCard = null;
  s.drew = null;
  s.phase = 'draw';
  return { ok: true, state: s };
}

function hasAll(hand: readonly HandCard[], cards: readonly HandCard[]): boolean {
  return new Set(cards).size === cards.length && cards.every((c) => hand.includes(c));
}

function meld(s: HandState, seat: number, groups: HandCard[][]): HandActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!Array.isArray(groups) || groups.length === 0 || !groups.every((g) => Array.isArray(g) && g.every(isHandCard))) return { ok: false, error: 'badMeld' };
  const all = groups.flat();
  if (!hasAll(s.hands[seat], all)) return { ok: false, error: 'notInHand' };
  const arranged = groups.map(arrangeMeld);
  if (arranged.some((m) => m === null)) return { ok: false, error: 'badMeld' };
  if (s.fireCard && !all.includes(s.fireCard)) return { ok: false, error: 'mustUseFire' };
  const total = arranged.reduce((a, m) => a + meldValue(m!), 0);
  if (!s.opened[seat]) {
    if (total < s.openMin) return { ok: false, error: 'openTooLow' };
    s.opened[seat] = true;
    s.openMin = total + 1;
  }
  for (const m of arranged) s.melds.push({ id: s.nextMeldId++, owner: seat, kind: m!.kind, cards: m!.cards });
  s.hands[seat] = s.hands[seat].filter((c) => !all.includes(c));
  s.fireCard = null;
  s.actedThisTurn = true;
  if (s.hands[seat].length === 0) return { ok: true, state: scoreRound(s, seat) };
  return { ok: true, state: s };
}

function layoff(s: HandState, seat: number, c: HandCard, meldId: number): HandActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!s.opened[seat]) return { ok: false, error: 'notOpened' };
  if (!isHandCard(c) || !s.hands[seat].includes(c)) return { ok: false, error: 'notInHand' };
  if (s.fireCard && c !== s.fireCard) return { ok: false, error: 'mustUseFire' };
  const m = s.melds.find((x) => x.id === meldId);
  if (!m) return { ok: false, error: 'badMeld' };
  const r = layoffCard(m, c);
  if (!r) return { ok: false, error: 'cannotLayoff' };
  m.cards = r.cards;
  s.hands[seat] = s.hands[seat].filter((x) => x !== c);
  if (r.freed) s.hands[seat] = sortHandCards([...s.hands[seat], r.freed]);
  s.fireCard = null;
  s.actedThisTurn = true;
  s.laidOffThisTurn = true;
  if (s.hands[seat].length === 0) return { ok: true, state: scoreRound(s, seat) };
  return { ok: true, state: s };
}

function discard(s: HandState, seat: number, c: HandCard): HandActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isHandCard(c) || !s.hands[seat].includes(c)) return { ok: false, error: 'notInHand' };
  if (s.fireCard) return { ok: false, error: 'mustUseFire' };
  s.hands[seat] = s.hands[seat].filter((x) => x !== c);
  s.fire.push(c);
  if (s.hands[seat].length === 0) return { ok: true, state: scoreRound(s, seat) };
  startTurn(s, next(s, seat), null);
  return { ok: true, state: s };
}

function scoreRound(s: HandState, winner: number | null): HandState {
  // «هاند»: the winner laid everything down this turn, in one go, without adding to melds on the table
  const hand = winner !== null && !s.openAtTurnStart && !s.laidOffThisTurn;
  const mult = hand ? 2 : 1;
  const delta = s.hands.map((h, i) => {
    if (i === winner) return hand ? HAND_WIN * 2 : HAND_WIN;
    const pts = s.opened[i] ? h.reduce((a, c) => a + handCardPoints(c), 0) : HAND_NOT_OPENED;
    return pts * mult;
  });
  s.scores = s.scores.map((v, i) => v + delta[i]);
  s.lastResult = { winner, hand, delta, left: s.hands.map((h) => h.slice()), opened: s.opened.slice() };
  s.fireCard = null;
  if (s.handNo >= HAND_ROUNDS) {
    s.phase = 'gameOver';
    const best = Math.min(...s.scores);
    s.winners = s.scores.flatMap((v, i) => (v === best ? [i] : []));
  } else {
    s.phase = 'handOver';
  }
  return s;
}

/** Server-driven transition: deal the next round. No-op in other phases. */
export function advanceHand(prev: HandState, randInt: RandInt): HandState {
  if (prev.phase !== 'handOver') return prev;
  return startHandRound(prev, randInt, { dealer: (prev.dealer + 1) % prev.players });
}

// ---------------------------------------------------------------------------
// View: what one seat may see.

export interface HandView {
  variant: HandVariant;
  players: number;
  phase: HandPhase;
  /** round number, 1..5 */
  handNo: number;
  rounds: number;
  dealer: number;
  turn: number;
  mySeat: number;
  myHand: HandCard[];
  handCounts: number[];
  stockCount: number;
  fireTop: HandCard | null;
  fireCount: number;
  melds: Meld[];
  opened: boolean[];
  openMin: number;
  drew: 'start' | 'stock' | 'fire' | null;
  /** my turn: the card I took from the discard pile and still have to lay down */
  fireCard: HandCard | null;
  canUndoFire: boolean;
  scores: number[];
  lastResult: HandRoundResult | null;
  winners: number[];
  /** always empty (no tricks in Hand); kept so every game view has the same shape */
  trick: never[];
}

export function handViewFor(s: HandState, seat: number): HandView {
  const mine = s.turn === seat;
  return {
    variant: s.variant,
    players: s.players,
    phase: s.phase,
    handNo: s.handNo,
    rounds: HAND_ROUNDS,
    dealer: s.dealer,
    turn: s.turn,
    mySeat: seat,
    myHand: s.hands[seat].slice(),
    handCounts: s.hands.map((h) => h.length),
    stockCount: s.stock.length,
    fireTop: s.fire.length ? s.fire[s.fire.length - 1] : null,
    fireCount: s.fire.length,
    melds: structuredClone(s.melds),
    opened: s.opened.slice(),
    openMin: s.openMin,
    drew: mine ? s.drew : null,
    fireCard: mine ? s.fireCard : null,
    canUndoFire: mine && s.phase === 'playing' && !!s.fireCard && !s.actedThisTurn,
    scores: s.scores.slice(),
    lastResult: s.lastResult ? structuredClone(s.lastResult) : null,
    winners: s.winners.slice(),
    trick: [],
  };
}

// ---------------------------------------------------------------------------
// Autopilot (also drives computer players). Pure, deterministic, always legal.

/**
 * Melds a hand can lay down now: runs and sets from real cards (whichever order finds more points), then jokers
 * complete pairs or extend a found meld. Every group passes arrangeMeld.
 */
export function findMelds(hand: readonly HandCard[]): HandCard[][] {
  const a = greedyMelds(hand, true);
  const b = greedyMelds(hand, false);
  const val = (gs: HandCard[][]) => gs.reduce((t, g) => t + meldValue(arrangeMeld(g)!), 0);
  return val(a) >= val(b) ? a : b;
}

function greedyMelds(hand: readonly HandCard[], runsFirst: boolean): HandCard[][] {
  let rest = hand.filter((c) => !isJoker(c));
  const jokers = hand.filter(isJoker);
  const out: HandCard[][] = [];
  const take = (g: HandCard[]) => {
    out.push(g);
    rest = rest.filter((c) => !g.includes(c));
  };
  const runs = () => {
    for (const suit of SUITS) {
      for (;;) {
        const byRank = new Map<number, HandCard>();
        for (const c of rest) if (handSuit(c) === suit && !byRank.has(handRank(c))) byRank.set(handRank(c), c);
        let best: HandCard[] = [];
        for (const start of [1, ...Array.from({ length: 13 }, (_, i) => i + 2)]) {
          const seq: HandCard[] = [];
          for (let r = start; r <= 14; r++) {
            const c = byRank.get(r === 1 ? 14 : r);
            if (!c || (r === 14 && start === 1)) break;
            seq.push(c);
          }
          if (seq.length > best.length) best = seq;
        }
        if (best.length < 3) break;
        take(best);
      }
    }
  };
  const sets = () => {
    for (let r = 2; r <= 14; r++) {
      const bySuit = new Map<Suit, HandCard>();
      for (const c of rest) if (handRank(c) === r && !bySuit.has(handSuit(c))) bySuit.set(handSuit(c), c);
      if (bySuit.size >= 3) take([...bySuit.values()]);
    }
  };
  if (runsFirst) {
    runs();
    sets();
  } else {
    sets();
    runs();
  }
  for (const j of jokers) {
    let placed = false;
    // a pair of the same rank, or two cards of a suit one apart / next to each other
    for (let i = 0; i < rest.length && !placed; i++) {
      for (let k = i + 1; k < rest.length && !placed; k++) {
        if (arrangeMeld([rest[i], rest[k], j])) {
          take([rest[i], rest[k], j]);
          placed = true;
        }
      }
    }
    for (let i = 0; i < out.length && !placed; i++) {
      if (arrangeMeld([...out[i], j])) {
        out[i] = [...out[i], j];
        placed = true;
      }
    }
  }
  return out;
}

/** A card of the hand that fits a meld on the table (the fire card only, when it is pending). */
function findLayoff(s: HandState, seat: number): { card: HandCard; meld: number } | null {
  const hand = s.hands[seat];
  const cards = s.fireCard ? [s.fireCard] : [...hand.filter((c) => !isJoker(c)), ...hand.filter(isJoker)];
  for (const c of cards) {
    for (const m of s.melds) {
      const r = layoffCard(m, c);
      if (r) return { card: c, meld: m.id };
    }
  }
  return null;
}

/**
 * - Draw: always from the stock.
 * - A pending discard-pile card (a human's timeout): lay it down if possible, else put it back.
 * - Lay down every meld found (before opening: only when they reach the opening minimum), then add cards to melds.
 * - Discard the least connected card (fewest same-rank / nearby same-suit partners), the highest on a tie; never a
 *   joker while holding anything else.
 */
export function autoHandAction(s: HandState, seat: number): HandAction {
  if (s.phase === 'draw') return { type: 'draw', from: 'stock' };
  if (s.phase !== 'playing') throw new Error(`hand autopilot: no move in phase ${s.phase}`);
  const hand = s.hands[seat];
  const groups = findMelds(hand);
  if (s.fireCard) {
    const g = groups.filter((x) => x.includes(s.fireCard!));
    if (g.length > 0) {
      const total = groups.reduce((t, x) => t + meldValue(arrangeMeld(x)!), 0);
      if (s.opened[seat] || total >= s.openMin) return { type: 'meld', groups };
    }
    if (s.opened[seat]) {
      const l = findLayoff(s, seat);
      if (l) return { type: 'layoff', ...l };
    }
    if (!s.actedThisTurn) return { type: 'undoFire' };
    // cannot happen: laying anything down while the fire card is pending must include it
    throw new Error('hand autopilot: stuck with the discard-pile card');
  }
  if (groups.length > 0) {
    const total = groups.reduce((t, x) => t + meldValue(arrangeMeld(x)!), 0);
    if (s.opened[seat] || total >= s.openMin) return { type: 'meld', groups };
  }
  if (s.opened[seat]) {
    const l = findLayoff(s, seat);
    if (l) return { type: 'layoff', ...l };
  }
  return { type: 'discard', card: pickDiscard(hand) };
}

function pickDiscard(hand: readonly HandCard[]): HandCard {
  const reals = hand.filter((c) => !isJoker(c));
  if (reals.length === 0) return hand[0];
  const links = (c: HandCard) =>
    reals.filter((x) => x !== c && ((handRank(x) === handRank(c) && handSuit(x) !== handSuit(c)) || (handSuit(x) === handSuit(c) && Math.abs(handRank(x) - handRank(c)) <= 2 && handRank(x) !== handRank(c)))).length;
  return reals.slice().sort((a, b) => links(a) - links(b) || handCardPoints(b) - handCardPoints(a) || a.localeCompare(b))[0];
}
