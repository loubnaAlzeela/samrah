/**
 * Trix («تركس») — pure rules, no I/O. See docs/rules/trix.md.
 *
 * 4 kingdoms («ممالك»); each kingdom has one owner who picks the order of 5 contracts («طلبات»), one per hand:
 *   king («شيخ الكبة»), queens («بنات»), diamonds («ديناري»), tricks («لطوش») — trick-taking, avoid penalties;
 *   trix («تركس») — build the four suit sequences outward from the Jacks, finishing order scores.
 * The holder of 7♥ in the first deal owns the first kingdom; each next kingdom goes to the player on the right.
 * Solo («تركس») scores per seat; partners («تركس شراكة») adds opposite seats together.
 */
import { type Card, type RandInt, type Seat, type Suit, type Team, SUITS, deal, isCard, nextSeat, rankOf, suitOf } from './cards.ts';
import { type Play, legalCards, trickWinner } from './trick.ts';

export type TrixVariant = 'trix' | 'trixPartners';
export const TRIX_VARIANTS: readonly TrixVariant[] = ['trix', 'trixPartners'];
export function isTrixVariant(v: unknown): v is TrixVariant {
  return v === 'trix' || v === 'trixPartners';
}

export type TrixContract = 'king' | 'queens' | 'diamonds' | 'tricks' | 'trix';
export const TRIX_CONTRACTS: readonly TrixContract[] = ['king', 'queens', 'diamonds', 'tricks', 'trix'];

export const KING_OF_HEARTS: Card = 'H13';
/** The holder of this card in the first deal owns the first kingdom. */
export const FIRST_OWNER_CARD: Card = 'H7';
export const TRIX_POINTS = { king: 75, queen: 25, diamond: 10, trick: 15 } as const;
/** Trix contract: points by finishing place (1st..4th). */
export const TRIX_PLACES = [200, 150, 100, 50] as const;
export const TRIX_KINGDOMS = 4;

/**
 * contract -> the kingdom owner picks the next contract (turn = owner)
 * double   -> king / queens: each holder of K♥ / a Q decides which of those cards to double (turn = that seat)
 * playing  -> play (turn = seat to act). In trix a seat with no placeable card is skipped automatically.
 * trickDone-> 4 cards on the table; the server calls advanceTrix() after a short pause
 * handOver -> hand scored; the server calls advanceTrix() to deal the next hand
 * gameOver -> all 4 kingdoms played
 */
export type TrixPhase = 'contract' | 'double' | 'playing' | 'trickDone' | 'handOver' | 'gameOver';

export interface TrixPile {
  /** lowest rank placed (2..11) */
  low: number;
  /** highest rank placed (11..14) */
  high: number;
}
export type TrixLayout = Record<Suit, TrixPile | null>;

export interface TrixResult {
  contract: TrixContract;
  kingdomOwner: Seat;
  seatDelta: [number, number, number, number];
  teamDelta: [number, number];
  /** trix contract: seats in the order they emptied their hands */
  finishOrder: Seat[];
}

export interface TrixState {
  variant: TrixVariant;
  /** 0..3 */
  kingdom: number;
  kingdomOwner: Seat;
  /** contracts already played in the current kingdom */
  used: TrixContract[];
  dealer: Seat;
  handNo: number;
  phase: TrixPhase;
  hands: Card[][];
  turn: Seat;
  contract: TrixContract | null;
  /** doubled K♥ / Queens (public: doubling means showing the card) */
  doubled: { card: Card; seat: Seat }[];
  /** double phase: seats still to decide, in order */
  doubleQueue: Seat[];
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  tricks: number[];
  /** trick contracts: cards each seat has collected this hand */
  taken: Card[][];
  /** trix contract: the four suit sequences */
  layout: TrixLayout;
  finishOrder: Seat[];
  /** trix contract: seats that had to pass since the last card was placed */
  lastPasses: Seat[];
  teamScores: [number, number];
  seatScores: [number, number, number, number];
  lastResult: TrixResult | null;
  /** partners: winning team, null on a tie or in solo */
  winner: Team | null;
  /** seats with the best total (solo), or both seats of the winning team (partners); several on a tie */
  winnerSeats: Seat[];
}

export type TrixAction = { type: 'contract'; contract: TrixContract } | { type: 'double'; cards: Card[] } | { type: 'play'; card: Card };

export type TrixActResult = { ok: true; state: TrixState } | { ok: false; error: string };

const emptyLayout = (): TrixLayout => ({ S: null, H: null, D: null, C: null });

export function newTrixGame(opts: { variant: TrixVariant; dealer?: Seat }, randInt: RandInt): TrixState {
  const dealer = opts.dealer ?? (randInt(4) as Seat);
  const { hands } = deal(randInt, dealer);
  const owner = hands.findIndex((h) => h.includes(FIRST_OWNER_CARD)) as Seat;
  const base: TrixState = {
    variant: opts.variant,
    kingdom: 0,
    kingdomOwner: owner,
    used: [],
    dealer,
    handNo: 0,
    phase: 'contract',
    hands: [[], [], [], []],
    turn: owner,
    contract: null,
    doubled: [],
    doubleQueue: [],
    trick: [],
    lastTrick: null,
    tricks: [0, 0, 0, 0],
    taken: [[], [], [], []],
    layout: emptyLayout(),
    finishOrder: [],
    lastPasses: [],
    teamScores: [0, 0],
    seatScores: [0, 0, 0, 0],
    lastResult: null,
    winner: null,
    winnerSeats: [],
  };
  return startTrixHand(base, randInt, { hands, dealer });
}

/**
 * Start a hand for the current kingdom owner, keeping scores. The owner picks the contract.
 * `preset` injects exact hands (tests, and the first deal that decided the owner).
 */
export function startTrixHand(prev: TrixState, randInt: RandInt, preset?: { hands: Card[][]; dealer?: Seat }): TrixState {
  // the owner sits right of the dealer, so they receive the first card
  const dealer = preset?.dealer ?? (((prev.kingdomOwner + 3) % 4) as Seat);
  const hands = preset ? preset.hands.map((h) => h.slice()) : deal(randInt, dealer).hands;
  return {
    ...structuredClone(prev),
    dealer,
    handNo: prev.handNo + 1,
    phase: 'contract',
    hands,
    turn: prev.kingdomOwner,
    contract: null,
    doubled: [],
    doubleQueue: [],
    trick: [],
    lastTrick: null,
    tricks: [0, 0, 0, 0],
    taken: [[], [], [], []],
    layout: emptyLayout(),
    finishOrder: [],
    lastPasses: [],
  };
}

export function contractsLeft(s: TrixState): TrixContract[] {
  return TRIX_CONTRACTS.filter((c) => !s.used.includes(c));
}

/** Cards a seat may double in the current contract (K♥ in king, any Queen in queens). */
export function doubleOptions(s: TrixState, seat: Seat): Card[] {
  if (s.contract === 'king') return s.hands[seat].filter((c) => c === KING_OF_HEARTS);
  if (s.contract === 'queens') return s.hands[seat].filter((c) => rankOf(c) === 12);
  return [];
}

/** Trix contract: a Jack opens its suit; otherwise the card just below the low end or just above the high end. */
export function trixPlayable(hand: readonly Card[], layout: TrixLayout): Card[] {
  return hand.filter((c) => {
    const pile = layout[suitOf(c)];
    const r = rankOf(c);
    if (!pile) return r === 11;
    return r === pile.low - 1 || r === pile.high + 1;
  });
}

/** Cards `seat` may play right now (empty when it is not their turn to play). */
export function trixLegal(s: TrixState, seat: Seat): Card[] {
  if (s.phase !== 'playing' || s.turn !== seat) return [];
  return s.contract === 'trix' ? trixPlayable(s.hands[seat], s.layout) : legalCards(s.hands[seat], s.trick);
}

export function actTrix(prev: TrixState, seat: Seat, a: TrixAction): TrixActResult {
  if (prev.phase === 'gameOver') return { ok: false, error: 'gameOver' };
  if (seat !== prev.turn) return { ok: false, error: 'notYourTurn' };
  const s = structuredClone(prev);
  switch (a.type) {
    case 'contract':
      return chooseContract(s, seat, a.contract);
    case 'double':
      return chooseDoubles(s, seat, a.cards);
    case 'play':
      return s.contract === 'trix' ? placeCard(s, seat, a.card) : playTrick(s, seat, a.card);
    default:
      return { ok: false, error: 'badAction' };
  }
}

function chooseContract(s: TrixState, seat: Seat, contract: TrixContract): TrixActResult {
  if (s.phase !== 'contract') return { ok: false, error: 'wrongPhase' };
  if (seat !== s.kingdomOwner) return { ok: false, error: 'notOwner' };
  if (!TRIX_CONTRACTS.includes(contract)) return { ok: false, error: 'badContract' };
  if (s.used.includes(contract)) return { ok: false, error: 'contractUsed' };
  s.contract = contract;
  s.used.push(contract);
  if (contract === 'king' || contract === 'queens') {
    const queue: Seat[] = [];
    for (let i = 0, t = seat; i < 4; i++, t = nextSeat(t)) if (doubleOptions(s, t).length > 0) queue.push(t);
    if (queue.length > 0) {
      s.phase = 'double';
      s.doubleQueue = queue;
      s.turn = queue[0];
      return { ok: true, state: s };
    }
  }
  return { ok: true, state: startPlay(s) };
}

function chooseDoubles(s: TrixState, seat: Seat, cards: Card[]): TrixActResult {
  if (s.phase !== 'double') return { ok: false, error: 'wrongPhase' };
  if (!Array.isArray(cards) || !cards.every(isCard)) return { ok: false, error: 'badCard' };
  const allowed = doubleOptions(s, seat);
  if (new Set(cards).size !== cards.length || !cards.every((c) => allowed.includes(c))) return { ok: false, error: 'badDouble' };
  for (const c of cards) s.doubled.push({ card: c, seat });
  s.doubleQueue = s.doubleQueue.filter((x) => x !== seat);
  if (s.doubleQueue.length > 0) {
    s.turn = s.doubleQueue[0];
    return { ok: true, state: s };
  }
  return { ok: true, state: startPlay(s) };
}

/** The kingdom owner leads (trick contracts) or plays first (trix). */
function startPlay(s: TrixState): TrixState {
  s.phase = 'playing';
  s.turn = s.kingdomOwner;
  if (s.contract === 'trix') moveToPlayable(s, s.kingdomOwner, true);
  return s;
}

/** Trix: hand the turn to the first seat from `from` (inclusive when `inclusive`) that can place a card; record passes. */
function moveToPlayable(s: TrixState, from: Seat, inclusive: boolean) {
  let t = inclusive ? from : nextSeat(from);
  for (let i = 0; i < 4; i++, t = nextSeat(t)) {
    if (s.hands[t].length === 0) continue;
    if (trixPlayable(s.hands[t], s.layout).length > 0) {
      s.turn = t;
      return;
    }
    if (!s.lastPasses.includes(t)) s.lastPasses.push(t);
  }
  // unreachable while cards remain: the holder of the next card of some open end (or of an unplayed Jack) can play
  throw new Error('trix: nobody can play');
}

function placeCard(s: TrixState, seat: Seat, c: Card): TrixActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isCard(c)) return { ok: false, error: 'badCard' };
  if (!s.hands[seat].includes(c)) return { ok: false, error: 'notInHand' };
  if (!trixPlayable(s.hands[seat], s.layout).includes(c)) return { ok: false, error: 'cannotPlace' };
  s.hands[seat] = s.hands[seat].filter((x) => x !== c);
  const suit = suitOf(c);
  const r = rankOf(c);
  const pile = s.layout[suit];
  s.layout[suit] = pile ? { low: Math.min(pile.low, r), high: Math.max(pile.high, r) } : { low: 11, high: 11 };
  s.lastPasses = [];
  if (s.hands[seat].length === 0) s.finishOrder.push(seat);
  const left = ([0, 1, 2, 3] as Seat[]).filter((x) => s.hands[x].length > 0);
  if (left.length <= 1) {
    for (const x of left) s.finishOrder.push(x);
    return { ok: true, state: scoreHand(s) };
  }
  moveToPlayable(s, seat, false);
  return { ok: true, state: s };
}

function playTrick(s: TrixState, seat: Seat, c: Card): TrixActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isCard(c)) return { ok: false, error: 'badCard' };
  const hand = s.hands[seat];
  if (!hand.includes(c)) return { ok: false, error: 'notInHand' };
  if (!legalCards(hand, s.trick).includes(c)) return { ok: false, error: 'mustFollowSuit' };
  s.hands[seat] = hand.filter((x) => x !== c);
  s.trick.push({ seat, card: c });
  if (s.trick.length === 4) {
    s.phase = 'trickDone';
    s.turn = trickWinner(s.trick, null);
  } else {
    s.turn = nextSeat(seat);
  }
  return { ok: true, state: s };
}

/** Server-driven transitions: collect a finished trick, or deal the next hand. No-op in other phases. */
export function advanceTrix(prev: TrixState, randInt: RandInt): TrixState {
  if (prev.phase === 'trickDone') return collectTrick(prev);
  if (prev.phase === 'handOver') {
    const s = structuredClone(prev);
    if (s.used.length === TRIX_CONTRACTS.length) {
      s.kingdom++;
      s.kingdomOwner = nextSeat(s.kingdomOwner);
      s.used = [];
    }
    return startTrixHand(s, randInt);
  }
  return prev;
}

function collectTrick(prev: TrixState): TrixState {
  const s = structuredClone(prev);
  const winner = trickWinner(s.trick, null);
  s.tricks[winner]++;
  s.taken[winner].push(...s.trick.map((p) => p.card));
  s.lastTrick = { plays: s.trick, winner };
  s.trick = [];
  s.turn = winner;
  if (s.hands.every((h) => h.length === 0) || penaltiesAllTaken(s)) return scoreHand(s);
  s.phase = 'playing';
  return s;
}

/** The hand stops early once every penalty card of the contract has been collected (the rest cannot change the score). */
function penaltiesAllTaken(s: TrixState): boolean {
  const all = s.taken.flat();
  if (s.contract === 'king') return all.includes(KING_OF_HEARTS);
  if (s.contract === 'queens') return all.filter((c) => rankOf(c) === 12).length === 4;
  if (s.contract === 'diamonds') return all.filter((c) => suitOf(c) === 'D').length === 13;
  return false;
}

/** Points per seat for a trick contract from the cards taken so far (live during the hand, final at its end). */
export function trickPenalties(contract: TrixContract, taken: readonly Card[][], tricks: readonly number[], doubled: readonly { card: Card; seat: Seat }[]): [number, number, number, number] {
  const d: [number, number, number, number] = [0, 0, 0, 0];
  const cardPenalty = (card: Card, base: number, taker: number) => {
    const dbl = doubled.find((x) => x.card === card);
    if (!dbl) {
      d[taker] -= base;
      return;
    }
    d[taker] -= base * 2;
    if (dbl.seat !== taker) d[dbl.seat] += base; // the doubler earns the card's value when someone else takes it
  };
  for (let seat = 0; seat < 4; seat++) {
    for (const c of taken[seat]) {
      if (contract === 'king' && c === KING_OF_HEARTS) cardPenalty(c, TRIX_POINTS.king, seat);
      if (contract === 'queens' && rankOf(c) === 12) cardPenalty(c, TRIX_POINTS.queen, seat);
      if (contract === 'diamonds' && suitOf(c) === 'D') d[seat] -= TRIX_POINTS.diamond;
    }
    if (contract === 'tricks') d[seat] -= TRIX_POINTS.trick * tricks[seat];
  }
  return d;
}

function scoreHand(s: TrixState): TrixState {
  const contract = s.contract!;
  let seatDelta: [number, number, number, number];
  if (contract === 'trix') {
    seatDelta = [0, 0, 0, 0];
    s.finishOrder.forEach((seat, place) => (seatDelta[seat] = TRIX_PLACES[place]));
  } else {
    seatDelta = trickPenalties(contract, s.taken, s.tricks, s.doubled);
  }
  s.seatScores = s.seatScores.map((v, i) => v + seatDelta[i]) as [number, number, number, number];
  s.teamScores = [s.seatScores[0] + s.seatScores[2], s.seatScores[1] + s.seatScores[3]];
  s.lastResult = {
    contract,
    kingdomOwner: s.kingdomOwner,
    seatDelta,
    teamDelta: [seatDelta[0] + seatDelta[2], seatDelta[1] + seatDelta[3]],
    finishOrder: s.finishOrder.slice(),
  };
  s.trick = [];
  const last = s.kingdom === TRIX_KINGDOMS - 1 && s.used.length === TRIX_CONTRACTS.length;
  if (last) {
    s.phase = 'gameOver';
    decideWinner(s);
  } else {
    s.phase = 'handOver';
  }
  return s;
}

function decideWinner(s: TrixState) {
  if (s.variant === 'trixPartners') {
    const [a, b] = s.teamScores;
    s.winner = a === b ? null : a > b ? 0 : 1;
    s.winnerSeats = s.winner === null ? [0, 1, 2, 3] : s.winner === 0 ? [0, 2] : [1, 3];
  } else {
    const best = Math.max(...s.seatScores);
    s.winner = null;
    s.winnerSeats = ([0, 1, 2, 3] as Seat[]).filter((x) => s.seatScores[x] === best);
  }
}

// ---------------------------------------------------------------------------
// View: what one seat may see.

export interface TrixView {
  variant: TrixVariant;
  phase: TrixPhase;
  handNo: number;
  kingdom: number;
  kingdomOwner: Seat;
  /** contracts the owner can still pick in this kingdom */
  contractsLeft: TrixContract[];
  contract: TrixContract | null;
  dealer: Seat;
  turn: Seat;
  mySeat: Seat;
  myHand: Card[];
  legal: Card[];
  /** cards the viewer may double now (double phase, their turn) */
  doubleOptions: Card[];
  doubled: { card: Card; seat: Seat }[];
  handCounts: number[];
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  tricks: number[];
  /** trick contracts: live points per seat this hand */
  handPoints: [number, number, number, number];
  layout: TrixLayout;
  finishOrder: Seat[];
  lastPasses: Seat[];
  teamScores: [number, number];
  seatScores: [number, number, number, number];
  lastResult: TrixResult | null;
  winner: Team | null;
  winnerSeats: Seat[];
}

export function trixViewFor(s: TrixState, seat: Seat): TrixView {
  const myTurn = s.turn === seat;
  return {
    variant: s.variant,
    phase: s.phase,
    handNo: s.handNo,
    kingdom: s.kingdom,
    kingdomOwner: s.kingdomOwner,
    contractsLeft: contractsLeft(s),
    contract: s.contract,
    dealer: s.dealer,
    turn: s.turn,
    mySeat: seat,
    myHand: s.hands[seat].slice(),
    legal: trixLegal(s, seat),
    doubleOptions: myTurn && s.phase === 'double' ? doubleOptions(s, seat) : [],
    doubled: s.doubled.map((d) => ({ ...d })),
    handCounts: s.hands.map((h) => h.length),
    trick: s.trick.map((p) => ({ ...p })),
    lastTrick: s.lastTrick ? { plays: s.lastTrick.plays.map((p) => ({ ...p })), winner: s.lastTrick.winner } : null,
    tricks: s.tricks.slice(),
    handPoints: s.contract && s.contract !== 'trix' ? trickPenalties(s.contract, s.taken, s.tricks, s.doubled) : [0, 0, 0, 0],
    layout: structuredClone(s.layout),
    finishOrder: s.finishOrder.slice(),
    lastPasses: s.lastPasses.slice(),
    teamScores: [...s.teamScores] as [number, number],
    seatScores: [...s.seatScores] as [number, number, number, number],
    lastResult: s.lastResult ? structuredClone(s.lastResult) : null,
    winner: s.winner,
    winnerSeats: s.winnerSeats.slice(),
  };
}

// ---------------------------------------------------------------------------
// Autopilot (also drives computer players). Pure, deterministic, always legal.

/**
 * - Contract: the remaining contract that looks least risky for this hand (see contractRisk).
 * - Double: doubles a K♥ / Queen when holding 4+ cards of its suit (hard to force out).
 * - Trick contracts: lead the lowest safe card; follow with the highest card that still ducks under the current
 *   winner, else the lowest; when void, throw the most dangerous card (K♥, a Queen, the highest diamond, the highest card).
 * - Trix: place the card that keeps the most of our own cards in that suit reachable (so we can keep playing).
 */
export function autoTrixAction(s: TrixState, seat: Seat): TrixAction {
  if (s.phase === 'contract') return { type: 'contract', contract: pickContract(s, seat) };
  if (s.phase === 'double') {
    const hand = s.hands[seat];
    const suitLen = (suit: Suit) => hand.filter((c) => suitOf(c) === suit).length;
    return { type: 'double', cards: doubleOptions(s, seat).filter((c) => suitLen(suitOf(c)) >= 4) };
  }
  if (s.phase === 'playing') return { type: 'play', card: s.contract === 'trix' ? autoPlace(s, seat) : autoTrickCard(s, seat) };
  throw new Error(`trix autopilot: no move in phase ${s.phase}`);
}

export function contractRisk(contract: TrixContract, hand: readonly Card[]): number {
  const len = (suit: Suit) => hand.filter((c) => suitOf(c) === suit).length;
  const high = (c: Card) => rankOf(c) >= 11;
  switch (contract) {
    case 'king':
      return hand.includes(KING_OF_HEARTS) ? Math.max(1, 8 - 2 * len('H')) : 1;
    case 'queens':
      return hand.filter((c) => rankOf(c) === 12).reduce((a, c) => a + Math.max(0, 5 - len(suitOf(c))), 0) + 1;
    case 'diamonds':
      return hand.filter((c) => suitOf(c) === 'D' && rankOf(c) >= 9).length + 1;
    case 'tricks':
      return hand.filter(high).length;
    case 'trix':
      // Jacks and cards next to them make trix good for us; it always scores, so it is never "risky"
      return -hand.filter((c) => rankOf(c) === 11).length - 1;
  }
}

function pickContract(s: TrixState, seat: Seat): TrixContract {
  const left = contractsLeft(s);
  let best = left[0];
  for (const c of left) if (contractRisk(c, s.hands[seat]) < contractRisk(best, s.hands[seat])) best = c;
  return best;
}

function danger(contract: TrixContract, c: Card): number {
  if (contract === 'king' && c === KING_OF_HEARTS) return 1000;
  if (contract === 'queens' && rankOf(c) === 12) return 500 + rankOf(c);
  if (contract === 'diamonds' && suitOf(c) === 'D') return 200 + rankOf(c);
  return rankOf(c);
}

function autoTrickCard(s: TrixState, seat: Seat): Card {
  const contract = s.contract!;
  const legal = legalCards(s.hands[seat], s.trick);
  if (legal.length === 0) throw new Error('trix autopilot: empty hand');
  const byRank = legal.slice().sort((a, b) => rankOf(a) - rankOf(b) || a.localeCompare(b));
  if (s.trick.length === 0) {
    // lead low, and never lead a penalty card while something else is available
    const safe = byRank.filter((c) => danger(contract, c) < 100);
    return (safe.length > 0 ? safe : byRank)[0];
  }
  const led = suitOf(s.trick[0].card);
  if (suitOf(legal[0]) === led) {
    const winning = Math.max(...s.trick.filter((p) => suitOf(p.card) === led).map((p) => rankOf(p.card)));
    const under = byRank.filter((c) => rankOf(c) < winning);
    return under.length > 0 ? under[under.length - 1] : byRank[0];
  }
  // void: throw the most dangerous card
  return legal.slice().sort((a, b) => danger(contract, b) - danger(contract, a) || a.localeCompare(b))[0];
}

function autoPlace(s: TrixState, seat: Seat): Card {
  const hand = s.hands[seat];
  const options = trixPlayable(hand, s.layout);
  if (options.length === 0) throw new Error('trix autopilot: nothing to place');
  const reach = (c: Card) => {
    // own cards in the same suit on the far side of `c` (placing it opens the way to them)
    const r = rankOf(c);
    return hand.filter((x) => suitOf(x) === suitOf(c) && (r <= 11 ? rankOf(x) < r : rankOf(x) > r)).length + (r === 11 ? hand.filter((x) => suitOf(x) === suitOf(c)).length : 0);
  };
  return options.slice().sort((a, b) => reach(b) - reach(a) || a.localeCompare(b))[0];
}
