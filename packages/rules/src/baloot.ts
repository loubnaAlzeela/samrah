/**
 * Baloot («بلوت») — pure rules, no I/O. See docs/rules/baloot.md.
 *
 * 4 players, opposite seats are partners. 32 cards (7..A). Each seat gets 5 cards and one card is turned face up
 * («المشترى»). The auction decides the mode — sun («صن», no trump) or hokm («حكم», a trump suit) — and the buyer, who
 * takes the face-up card plus 2 more (the others get 3). Trick play, must follow suit. Card points («أبناط») are
 * converted to game points; projects («مشاريع») add to them. First team to 152 wins, or the winner of a «قهوة» round.
 */
import { type Card, type RandInt, type Seat, type Suit, type Team, SUITS, card, isCard, nextSeat, partnerOf, rankOf, shuffle, sortHand, suitOf, teamOf } from './cards.ts';
import { type Play, legalCards } from './trick.ts';

export type BalootVariant = 'baloot';
export function isBalootVariant(v: unknown): v is BalootVariant {
  return v === 'baloot';
}

export type BalootMode = 'sun' | 'hokm';
/** Auction calls. 'pass' is «بس» in the first round and «ولا» in the second; 'hokm' in the second round is «حكم ثاني». */
export type BalootCall = 'pass' | 'sun' | 'hokm' | 'ashkal';
/** Raising the stakes after the contract: دبل ×2, تربل ×3, فور ×4, قهوة (the round's winner wins the game). */
export type BalootRaiseStep = 'double' | 'triple' | 'four' | 'qahwa';
export type BalootProjectKind = 'sira' | 'fifty' | 'hundred' | 'fourHundred' | 'baloot';

export const BALOOT_TARGET = 152;
export const BALOOT_RANKS: readonly number[] = [7, 8, 9, 10, 11, 12, 13, 14];
/** Game points in a round (before projects): sun 26, hokm 16. */
export const BALOOT_ROUND_POINTS: Record<BalootMode, number> = { sun: 26, hokm: 16 };
/** One team takes all 8 tricks («كبوت»). */
export const BALOOT_KABOOT = 44;
/** Card points for the last trick («الأرض»). */
export const BALOOT_LAST_TRICK = 10;
/** Project values in game points. */
export const BALOOT_PROJECT_POINTS: Record<BalootMode, Partial<Record<BalootProjectKind, number>>> = {
  sun: { sira: 4, fifty: 10, fourHundred: 40 },
  hokm: { sira: 2, fifty: 5, hundred: 10, baloot: 2 },
};
/** Projects compare by kind («رتبة المشروع»); baloot never competes. */
const PROJECT_RANK: Record<BalootProjectKind, number> = { sira: 1, fifty: 2, hundred: 3, fourHundred: 4, baloot: 0 };

// Strength, weakest -> strongest.
const SUN_ORDER = [7, 8, 9, 11, 12, 13, 10, 14];
const TRUMP_ORDER = [7, 8, 12, 13, 10, 14, 9, 11];
const SUN_VALUE: Record<number, number> = { 7: 0, 8: 0, 9: 0, 10: 10, 11: 2, 12: 3, 13: 4, 14: 11 };
const TRUMP_VALUE: Record<number, number> = { 7: 0, 8: 0, 9: 14, 10: 10, 11: 20, 12: 3, 13: 4, 14: 11 };

/** Strength of a card in its suit (0..7); trump cards rank above every other suit (+100). */
export function balootPower(c: Card, trump: Suit | null): number {
  const isTrump = trump !== null && suitOf(c) === trump;
  return (isTrump ? 100 + TRUMP_ORDER.indexOf(rankOf(c)) : SUN_ORDER.indexOf(rankOf(c)));
}

/** Card points («أبناط»). */
export function balootValue(c: Card, trump: Suit | null): number {
  return trump !== null && suitOf(c) === trump ? TRUMP_VALUE[rankOf(c)] : SUN_VALUE[rankOf(c)];
}

export function balootDeck(): Card[] {
  const out: Card[] = [];
  for (const s of SUITS) for (const r of BALOOT_RANKS) out.push(card(s, r));
  return out;
}

export function isBalootCard(x: unknown): x is Card {
  return isCard(x) && rankOf(x) >= 7;
}

/** Winner of a (partial) trick: highest trump if any, else the strongest card of the led suit. */
export function balootTrickWinner(trick: readonly Play[], trump: Suit | null): Seat {
  if (trick.length === 0) throw new Error('empty trick');
  const led = suitOf(trick[0].card);
  let best = trick[0];
  for (const p of trick.slice(1)) {
    const ps = suitOf(p.card);
    const bs = suitOf(best.card);
    const counts = ps === led || (trump !== null && ps === trump);
    if (!counts) continue;
    if (ps !== bs && trump !== null && ps === trump) best = p;
    else if (ps === bs && balootPower(p.card, trump) > balootPower(best.card, trump)) best = p;
  }
  return best.seat;
}

/**
 * bidding  -> the auction (turn = seat to call; while `confirming`, the hokm caller confirms hokm or turns it to sun)
 * double   -> raising the stakes (turn = seat deciding; `raiseStep` says which raise is on offer)
 * playing  -> trick play (turn = seat to act)
 * trickDone-> 4 cards on the table; the server calls advanceBaloot() after a short pause
 * handOver -> round scored, or everyone passed twice (redeal); the server calls advanceBaloot()
 * gameOver -> a team reached 152, or won a «قهوة» round
 */
export type BalootPhase = 'bidding' | 'double' | 'playing' | 'trickDone' | 'handOver' | 'gameOver';

export interface BalootBid {
  seat: Seat;
  call: BalootCall;
  /** hokm: the trump suit named */
  suit?: Suit;
  round: 1 | 2;
}

export interface BalootProject {
  seat: Seat;
  kind: BalootProjectKind;
  cards: Card[];
  /** this project scores (the team with the highest project, and every baloot) */
  counts: boolean;
}

export interface BalootResult {
  kind: 'scored' | 'redeal';
  mode: BalootMode | null;
  trump: Suit | null;
  buyer: Seat | null;
  level: number;
  qahwa: boolean;
  /** card points per team, including the last trick's 10 */
  abnat: [number, number];
  /** game points from the cards alone, before projects and the buyer's success check */
  cardPoints: [number, number];
  /** counted project points per team (baloot included) */
  projectPoints: [number, number];
  teamDelta: [number, number];
  /** the buyer's team made more than the other team */
  success: boolean;
  /** team that took all 8 tricks */
  kaboot: Team | null;
}

export interface BalootState {
  variant: BalootVariant;
  dealer: Seat;
  handNo: number;
  phase: BalootPhase;
  hands: Card[][];
  /** undealt cards (hidden): 11 during the auction, then empty */
  stock: Card[];
  turn: Seat;
  /** the face-up card during the auction; null once it is in the buyer's hand */
  flipped: Card | null;
  bidRound: 1 | 2;
  bidLog: BalootBid[];
  /** seats still to call in the current auction round, in order */
  bidQueue: Seat[];
  /** a hokm call waiting for the rest of the round (they may still say sun), then for its caller's confirmation */
  hokmCall: { seat: Seat; suit: Suit } | null;
  confirming: boolean;
  mode: BalootMode | null;
  trump: Suit | null;
  buyer: Seat | null;
  /** «أشكل»: sun, but the face-up card went to the caller's partner */
  ashkal: boolean;
  /** receiver of the face-up card */
  cardTo: Seat | null;
  level: 1 | 2 | 3 | 4;
  qahwa: boolean;
  /** «مغلق»: nobody may lead a trump while holding another suit */
  closed: boolean;
  raiseStep: BalootRaiseStep | null;
  raiseQueue: Seat[];
  /** seat that said دبل (they are asked for فور) */
  doubler: Seat | null;
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  /** tricks collected this round */
  trickNo: number;
  teamTricks: [number, number];
  abnat: [number, number];
  projects: BalootProject[];
  teamScores: [number, number];
  lastResult: BalootResult | null;
  winner: Team | null;
}

export type BalootAction =
  | { type: 'call'; call: BalootCall; suit?: Suit }
  | { type: 'raise'; raise: boolean; closed?: boolean }
  | { type: 'play'; card: Card };

export type BalootActResult = { ok: true; state: BalootState } | { ok: false; error: string };

const other = (t: Team): Team => (1 - t) as Team;

export function newBalootGame(opts: { dealer?: Seat }, randInt: RandInt): BalootState {
  const dealer = opts.dealer ?? (randInt(4) as Seat);
  const base: BalootState = {
    variant: 'baloot',
    dealer,
    handNo: 0,
    phase: 'bidding',
    hands: [[], [], [], []],
    stock: [],
    turn: nextSeat(dealer),
    flipped: null,
    bidRound: 1,
    bidLog: [],
    bidQueue: [],
    hokmCall: null,
    confirming: false,
    mode: null,
    trump: null,
    buyer: null,
    ashkal: false,
    cardTo: null,
    level: 1,
    qahwa: false,
    closed: false,
    raiseStep: null,
    raiseQueue: [],
    doubler: null,
    trick: [],
    lastTrick: null,
    trickNo: 0,
    teamTricks: [0, 0],
    abnat: [0, 0],
    projects: [],
    teamScores: [0, 0],
    lastResult: null,
    winner: null,
  };
  return startBalootHand(base, randInt, { dealer });
}

/**
 * Deal a round, keeping the scores: 5 cards each from the dealer's right, then one card face up.
 * `preset.deck` fixes the 32 cards (tests): seat dealer+1 gets deck[0..4], dealer+2 deck[5..9], …, the face-up
 * card is deck[20], and deck[21..31] complete the hands after the auction.
 */
export function startBalootHand(prev: BalootState, randInt: RandInt, preset?: { dealer?: Seat; deck?: Card[] }): BalootState {
  const dealer = preset?.dealer ?? prev.dealer;
  const deck = preset?.deck ? preset.deck.slice() : shuffle(balootDeck(), randInt);
  const hands: Card[][] = [[], [], [], []];
  const order = biddingOrder(dealer);
  order.forEach((seat, i) => (hands[seat] = sortHand(deck.slice(i * 5, i * 5 + 5))));
  return {
    ...structuredClone(prev),
    dealer,
    handNo: prev.handNo + 1,
    phase: 'bidding',
    hands,
    stock: deck.slice(21),
    turn: order[0],
    flipped: deck[20],
    bidRound: 1,
    bidLog: [],
    bidQueue: order,
    hokmCall: null,
    confirming: false,
    mode: null,
    trump: null,
    buyer: null,
    ashkal: false,
    cardTo: null,
    level: 1,
    qahwa: false,
    closed: false,
    raiseStep: null,
    raiseQueue: [],
    doubler: null,
    trick: [],
    lastTrick: null,
    trickNo: 0,
    teamTricks: [0, 0],
    abnat: [0, 0],
    projects: [],
  };
}

/** The auction starts right of the dealer; the dealer calls last. */
function biddingOrder(dealer: Seat): Seat[] {
  const out: Seat[] = [];
  for (let i = 1, t = nextSeat(dealer); i <= 4; i++, t = nextSeat(t)) out.push(t);
  return out;
}

/** «أشكل» is offered to the dealer and the player on the dealer's left (the last two to call). */
function mayAshkal(s: BalootState, seat: Seat): boolean {
  return seat === s.dealer || nextSeat(seat) === s.dealer;
}

/** Calls `seat` may make now (empty when it is not their turn in the auction). */
export function balootCallOptions(s: BalootState, seat: Seat): BalootCall[] {
  if (s.phase !== 'bidding' || s.turn !== seat) return [];
  if (s.confirming) return ['hokm', 'sun'];
  const out: BalootCall[] = ['pass', 'sun'];
  if (s.hokmCall === null) out.push('hokm');
  if (mayAshkal(s, seat)) out.push('ashkal');
  return out;
}

/** Suits a hokm call may name now: the face-up card's suit in round 1, any other suit in round 2. */
export function balootHokmSuits(s: BalootState): Suit[] {
  if (!s.flipped) return [];
  const f = suitOf(s.flipped);
  return s.bidRound === 1 ? [f] : SUITS.filter((x) => x !== f);
}

/** Cards `seat` may play now: follow suit; in a closed game, lead a trump only when holding nothing else. */
export function balootLegal(s: BalootState, seat: Seat): Card[] {
  if (s.phase !== 'playing' || s.turn !== seat) return [];
  const hand = s.hands[seat];
  if (s.trick.length === 0 && s.closed && s.trump) {
    const rest = hand.filter((c) => suitOf(c) !== s.trump);
    return rest.length > 0 ? rest : hand.slice();
  }
  return legalCards(hand, s.trick);
}

export function actBaloot(prev: BalootState, seat: Seat, a: BalootAction): BalootActResult {
  if (prev.phase === 'gameOver') return { ok: false, error: 'gameOver' };
  if (seat !== prev.turn) return { ok: false, error: 'notYourTurn' };
  const s = structuredClone(prev);
  switch (a.type) {
    case 'call':
      return call(s, seat, a.call, a.suit);
    case 'raise':
      return raise(s, seat, a.raise, a.closed);
    case 'play':
      return play(s, seat, a.card);
    default:
      return { ok: false, error: 'badAction' };
  }
}

function call(s: BalootState, seat: Seat, c: BalootCall, suit: Suit | undefined): BalootActResult {
  if (s.phase !== 'bidding') return { ok: false, error: 'wrongPhase' };
  if (!balootCallOptions(s, seat).includes(c)) return { ok: false, error: 'badCall' };
  if (s.confirming) {
    s.bidLog.push({ seat, call: c, round: s.bidRound, ...(c === 'hokm' ? { suit: s.hokmCall!.suit } : {}) });
    return { ok: true, state: c === 'hokm' ? buy(s, 'hokm', seat, s.hokmCall!.suit, false) : buy(s, 'sun', seat, null, false) };
  }
  if (c === 'hokm') {
    if (suit === undefined || !balootHokmSuits(s).includes(suit)) return { ok: false, error: 'badSuit' };
    s.hokmCall = { seat, suit };
  }
  s.bidLog.push({ seat, call: c, round: s.bidRound, ...(c === 'hokm' ? { suit } : {}) });
  if (c === 'sun' || c === 'ashkal') return { ok: true, state: buy(s, 'sun', seat, null, c === 'ashkal') };
  s.bidQueue = s.bidQueue.filter((x) => x !== seat);
  if (s.bidQueue.length > 0) {
    s.turn = s.bidQueue[0];
  } else if (s.hokmCall) {
    // the round is over and nobody turned it to sun: the caller confirms hokm or switches to sun
    s.confirming = true;
    s.turn = s.hokmCall.seat;
  } else if (s.bidRound === 1) {
    s.bidRound = 2;
    s.bidQueue = biddingOrder(s.dealer);
    s.turn = s.bidQueue[0];
  } else {
    // «ولا» all round: the cards go back and the next dealer deals again
    s.phase = 'handOver';
    s.lastResult = {
      kind: 'redeal',
      mode: null,
      trump: null,
      buyer: null,
      level: 1,
      qahwa: false,
      abnat: [0, 0],
      cardPoints: [0, 0],
      projectPoints: [0, 0],
      teamDelta: [0, 0],
      success: false,
      kaboot: null,
    };
  }
  return { ok: true, state: s };
}

/** The auction is won: finish the deal, find the projects, offer the raises (or start play). */
function buy(s: BalootState, mode: BalootMode, buyer: Seat, trump: Suit | null, ashkal: boolean): BalootState {
  const to = ashkal ? partnerOf(buyer) : buyer;
  const stock = s.stock.slice();
  s.hands[to].push(s.flipped!, ...stock.splice(0, 2));
  for (const seat of biddingOrder(s.dealer)) if (seat !== to) s.hands[seat].push(...stock.splice(0, 3));
  s.hands = s.hands.map(sortHand);
  s.stock = [];
  s.flipped = null;
  s.bidQueue = [];
  s.hokmCall = null;
  s.confirming = false;
  s.mode = mode;
  s.trump = trump;
  s.buyer = buyer;
  s.ashkal = ashkal;
  s.cardTo = to;
  s.projects = resolveProjects(s);
  const def = nextSeat(buyer);
  const buyerTeam = teamOf(buyer);
  const sunDouble = mode === 'sun' && s.teamScores[buyerTeam] > 100 && s.teamScores[other(buyerTeam)] < 100;
  if (mode === 'hokm' || sunDouble) {
    s.phase = 'double';
    s.raiseStep = 'double';
    s.raiseQueue = [def, partnerOf(def)];
    s.turn = def;
    return s;
  }
  return startPlay(s);
}

function raise(s: BalootState, seat: Seat, yes: boolean, closed: boolean | undefined): BalootActResult {
  if (s.phase !== 'double' || !s.raiseStep) return { ok: false, error: 'wrongPhase' };
  if (typeof yes !== 'boolean' || (closed !== undefined && typeof closed !== 'boolean')) return { ok: false, error: 'badRaise' };
  const step = s.raiseStep;
  if (!yes) {
    s.raiseQueue = s.raiseQueue.filter((x) => x !== seat);
    if (step === 'double' && s.raiseQueue.length > 0) {
      s.turn = s.raiseQueue[0];
      return { ok: true, state: s };
    }
    return { ok: true, state: startPlay(s) };
  }
  const buyer = s.buyer!;
  switch (step) {
    case 'double':
      s.level = 2;
      s.doubler = seat;
      if (s.mode === 'sun') return { ok: true, state: startPlay(s) }; // sun: only «دبل»
      s.closed = closed === true;
      return { ok: true, state: offer(s, 'triple', buyer) };
    case 'triple':
      s.level = 3;
      return { ok: true, state: offer(s, 'four', s.doubler!) };
    case 'four':
      s.level = 4;
      s.closed = closed === true;
      return { ok: true, state: offer(s, 'qahwa', buyer) };
    case 'qahwa':
      s.qahwa = true;
      return { ok: true, state: startPlay(s) };
  }
}

function offer(s: BalootState, step: BalootRaiseStep, seat: Seat): BalootState {
  s.raiseStep = step;
  s.raiseQueue = [seat];
  s.turn = seat;
  return s;
}

/** The buyer leads the first trick. */
function startPlay(s: BalootState): BalootState {
  s.phase = 'playing';
  s.raiseStep = null;
  s.raiseQueue = [];
  s.turn = s.buyer!;
  return s;
}

function play(s: BalootState, seat: Seat, c: Card): BalootActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isCard(c)) return { ok: false, error: 'badCard' };
  const hand = s.hands[seat];
  if (!hand.includes(c)) return { ok: false, error: 'notInHand' };
  if (!balootLegal(s, seat).includes(c)) {
    return { ok: false, error: s.trick.length === 0 ? 'closedTrump' : 'mustFollowSuit' };
  }
  s.hands[seat] = hand.filter((x) => x !== c);
  s.trick.push({ seat, card: c });
  if (s.trick.length === 4) {
    s.phase = 'trickDone';
    s.turn = balootTrickWinner(s.trick, s.trump);
  } else {
    s.turn = nextSeat(seat);
  }
  return { ok: true, state: s };
}

/** Server-driven transitions: collect a finished trick, or deal the next round. No-op in other phases. */
export function advanceBaloot(prev: BalootState, randInt: RandInt): BalootState {
  if (prev.phase === 'trickDone') return collectTrick(prev);
  if (prev.phase === 'handOver') return startBalootHand(prev, randInt, { dealer: nextSeat(prev.dealer) });
  return prev;
}

function collectTrick(prev: BalootState): BalootState {
  const s = structuredClone(prev);
  const winner = balootTrickWinner(s.trick, s.trump);
  const team = teamOf(winner);
  s.abnat[team] += s.trick.reduce((a, p) => a + balootValue(p.card, s.trump), 0);
  s.teamTricks[team]++;
  s.trickNo++;
  s.lastTrick = { plays: s.trick, winner };
  s.trick = [];
  s.turn = winner;
  if (s.hands.every((h) => h.length === 0)) {
    s.abnat[team] += BALOOT_LAST_TRICK;
    return scoreRound(s);
  }
  s.phase = 'playing';
  return s;
}

// ---------------------------------------------------------------------------
// Projects

/** Best projects in an 8-card hand: at most two, no card in two of them, plus baloot (hokm: trump K + Q). */
export function findProjects(hand: readonly Card[], mode: BalootMode, trump: Suit | null): { kind: BalootProjectKind; cards: Card[] }[] {
  const points = BALOOT_PROJECT_POINTS[mode];
  const candidates: { kind: BalootProjectKind; cards: Card[] }[] = [];
  const maxRun = mode === 'hokm' ? 5 : 4;
  for (const suit of SUITS) {
    const ranks = hand.filter((c) => suitOf(c) === suit).map(rankOf).sort((a, b) => a - b);
    // every run of 3..maxRun consecutive ranks (7 8 9 10 J Q K A)
    for (let i = 0; i < ranks.length; i++) {
      let j = i;
      while (j + 1 < ranks.length && ranks[j + 1] === ranks[j] + 1 && j + 1 - i < maxRun) {
        j++;
        const len = j - i + 1;
        if (len >= 3) candidates.push({ kind: len === 3 ? 'sira' : len === 4 ? 'fifty' : 'hundred', cards: ranks.slice(i, j + 1).map((r) => card(suit, r)) });
      }
    }
  }
  for (const r of mode === 'sun' ? [14] : [14, 13, 12, 11, 10]) {
    const four = hand.filter((c) => rankOf(c) === r);
    if (four.length === 4) candidates.push({ kind: mode === 'sun' ? 'fourHundred' : 'hundred', cards: four.slice() });
  }
  const value = (p: { kind: BalootProjectKind }) => points[p.kind] ?? 0;
  const usable = candidates.filter((p) => value(p) > 0);
  let best: { kind: BalootProjectKind; cards: Card[] }[] = [];
  let bestValue = 0;
  for (let i = 0; i < usable.length; i++) {
    if (value(usable[i]) > bestValue) {
      best = [usable[i]];
      bestValue = value(usable[i]);
    }
    for (let j = i + 1; j < usable.length; j++) {
      if (usable[i].cards.some((c) => usable[j].cards.includes(c))) continue;
      const v = value(usable[i]) + value(usable[j]);
      if (v > bestValue) {
        best = [usable[i], usable[j]];
        bestValue = v;
      }
    }
  }
  const out = best.map((p) => ({ kind: p.kind, cards: sortHand(p.cards) }));
  if (mode === 'hokm' && trump && hand.includes(card(trump, 13)) && hand.includes(card(trump, 12))) out.push({ kind: 'baloot', cards: [card(trump, 13), card(trump, 12)] });
  return out;
}

/**
 * Every seat's projects, and which ones score: all projects of the team holding the highest-ranked project;
 * on a tie, the team of the player on the dealer's left. Baloot always scores.
 */
function resolveProjects(s: BalootState): BalootProject[] {
  const all: BalootProject[] = [];
  for (const seat of biddingOrder(s.dealer)) for (const p of findProjects(s.hands[seat], s.mode!, s.trump)) all.push({ seat, ...p, counts: p.kind === 'baloot' });
  const best: [number, number] = [0, 0];
  for (const p of all) best[teamOf(p.seat)] = Math.max(best[teamOf(p.seat)], PROJECT_RANK[p.kind]);
  if (best[0] === 0 && best[1] === 0) return all;
  const leftOfDealer = ((s.dealer + 3) % 4) as Seat;
  const team: Team = best[0] === best[1] ? teamOf(leftOfDealer) : best[0] > best[1] ? 0 : 1;
  for (const p of all) if (teamOf(p.seat) === team) p.counts = true;
  return all;
}

// ---------------------------------------------------------------------------
// Scoring

/** Sun: round the card points to the nearest ten, double, divide by ten; a total ending in 5 is just doubled. */
export function sunPoints(abnat: number): number {
  return abnat % 10 === 5 ? (abnat * 2) / 10 : Math.round(abnat / 10) * 2;
}
/** Hokm: card points / 10, a half rounds down, anything above rounds up. */
export function hokmPoints(abnat: number): number {
  return abnat % 10 <= 5 ? Math.floor(abnat / 10) : Math.ceil(abnat / 10);
}

export interface BalootScoreInput {
  mode: BalootMode;
  buyerTeam: Team;
  abnat: [number, number];
  teamTricks: [number, number];
  /** counted project points per team, baloot excluded */
  projects: [number, number];
  /** baloot points per team */
  baloot: [number, number];
  level: number;
  qahwa: boolean;
}

/** Round result: cards to points, projects, the buyer's success check, kaboot, raises. Pure (exported for tests). */
export function scoreBaloot(x: BalootScoreInput): { teamDelta: [number, number]; cardPoints: [number, number]; success: boolean; kaboot: Team | null; roundWinner: Team } {
  const b = x.buyerTeam;
  const d = other(b);
  const total = BALOOT_ROUND_POINTS[x.mode];
  const mult = x.qahwa ? 4 : x.level;
  const delta: [number, number] = [0, 0];
  const kaboot = x.teamTricks[0] === 8 ? 0 : x.teamTricks[1] === 8 ? 1 : null;
  const cardPoints: [number, number] = [0, 0];
  if (x.mode === 'sun') {
    cardPoints[b] = sunPoints(x.abnat[b]);
    cardPoints[d] = sunPoints(x.abnat[d]);
  } else {
    cardPoints[b] = hokmPoints(x.abnat[b]);
    cardPoints[d] = total - cardPoints[b];
  }
  if (kaboot !== null) {
    delta[kaboot] = (BALOOT_KABOOT + x.projects[kaboot]) * mult + x.baloot[kaboot];
    delta[other(kaboot)] = x.baloot[other(kaboot)];
    return { teamDelta: delta, cardPoints, success: kaboot === b, kaboot, roundWinner: kaboot };
  }
  const mine = (t: Team) => cardPoints[t] + x.projects[t] + x.baloot[t];
  const success = mine(b) > mine(d);
  const winner = success ? b : d;
  if (mult === 1 && success) {
    delta[b] = mine(b);
    delta[d] = mine(d);
  } else {
    // a failed buyer, or any raised round: the round's winner takes all the points; baloot stays with its holder
    delta[winner] = (total + x.projects[0] + x.projects[1]) * mult + x.baloot[winner];
    delta[other(winner)] = x.baloot[other(winner)];
  }
  return { teamDelta: delta, cardPoints, success, kaboot: null, roundWinner: winner };
}

function scoreRound(s: BalootState): BalootState {
  const mode = s.mode!;
  const pts = BALOOT_PROJECT_POINTS[mode];
  const projects: [number, number] = [0, 0];
  const baloot: [number, number] = [0, 0];
  for (const p of s.projects) {
    if (!p.counts) continue;
    const v = pts[p.kind] ?? 0;
    if (p.kind === 'baloot') baloot[teamOf(p.seat)] += v;
    else projects[teamOf(p.seat)] += v;
  }
  const r = scoreBaloot({ mode, buyerTeam: teamOf(s.buyer!), abnat: s.abnat, teamTricks: s.teamTricks, projects, baloot, level: s.level, qahwa: s.qahwa });
  s.teamScores = [s.teamScores[0] + r.teamDelta[0], s.teamScores[1] + r.teamDelta[1]];
  s.lastResult = {
    kind: 'scored',
    mode,
    trump: s.trump,
    buyer: s.buyer,
    level: s.level,
    qahwa: s.qahwa,
    abnat: [...s.abnat] as [number, number],
    cardPoints: r.cardPoints,
    projectPoints: [projects[0] + baloot[0], projects[1] + baloot[1]],
    teamDelta: r.teamDelta,
    success: r.success,
    kaboot: r.kaboot,
  };
  const [a, b] = s.teamScores;
  if (s.qahwa) s.winner = r.roundWinner;
  else if ((a >= BALOOT_TARGET || b >= BALOOT_TARGET) && a !== b) s.winner = a > b ? 0 : 1;
  s.phase = s.winner !== null ? 'gameOver' : 'handOver';
  return s;
}

// ---------------------------------------------------------------------------
// View: what one seat may see.

export interface BalootProjectView {
  seat: Seat;
  kind: BalootProjectKind;
  /** shown for the viewer's own projects, and for the scoring team's once the first trick is over */
  cards: Card[] | null;
  /** known once the first trick is over */
  counts: boolean | null;
}

export interface BalootView {
  variant: BalootVariant;
  phase: BalootPhase;
  handNo: number;
  target: number;
  dealer: Seat;
  turn: Seat;
  mySeat: Seat;
  myHand: Card[];
  legal: Card[];
  handCounts: number[];
  flipped: Card | null;
  bidRound: 1 | 2;
  bidLog: BalootBid[];
  /** calls the viewer may make now */
  callOptions: BalootCall[];
  /** suits the viewer may name with a hokm call now */
  hokmSuits: Suit[];
  confirming: boolean;
  hokmCall: { seat: Seat; suit: Suit } | null;
  mode: BalootMode | null;
  trump: Suit | null;
  buyer: Seat | null;
  ashkal: boolean;
  cardTo: Seat | null;
  level: number;
  qahwa: boolean;
  closed: boolean;
  raiseStep: BalootRaiseStep | null;
  /** the viewer is asked to raise now (and whether the raise needs an open / closed choice) */
  myRaise: { step: BalootRaiseStep; chooseClosed: boolean } | null;
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  trickNo: number;
  teamTricks: [number, number];
  abnat: [number, number];
  projects: BalootProjectView[];
  teamScores: [number, number];
  lastResult: BalootResult | null;
  winner: Team | null;
}

export function balootViewFor(s: BalootState, seat: Seat): BalootView {
  const myTurn = s.turn === seat;
  const declared = s.phase !== 'bidding' && s.phase !== 'double';
  const revealed = s.trickNo >= 1 || s.phase === 'handOver' || s.phase === 'gameOver';
  const projects: BalootProjectView[] = s.projects
    .filter((p) => p.seat === seat || declared)
    .map((p) => ({
      seat: p.seat,
      kind: p.kind,
      cards: p.seat === seat || (revealed && p.counts) ? p.cards.slice() : null,
      counts: revealed ? p.counts : null,
    }));
  const step = s.raiseStep;
  return {
    variant: s.variant,
    phase: s.phase,
    handNo: s.handNo,
    target: BALOOT_TARGET,
    dealer: s.dealer,
    turn: s.turn,
    mySeat: seat,
    myHand: s.hands[seat].slice(),
    legal: balootLegal(s, seat),
    handCounts: s.hands.map((h) => h.length),
    flipped: s.flipped,
    bidRound: s.bidRound,
    bidLog: s.bidLog.map((b) => ({ ...b })),
    callOptions: balootCallOptions(s, seat),
    hokmSuits: myTurn && s.phase === 'bidding' && !s.confirming && s.hokmCall === null ? balootHokmSuits(s) : [],
    confirming: s.confirming,
    hokmCall: s.hokmCall ? { ...s.hokmCall } : null,
    mode: s.mode,
    trump: s.trump,
    buyer: s.buyer,
    ashkal: s.ashkal,
    cardTo: s.cardTo,
    level: s.level,
    qahwa: s.qahwa,
    closed: s.closed,
    raiseStep: step,
    myRaise: myTurn && s.phase === 'double' && step ? { step, chooseClosed: s.mode === 'hokm' && (step === 'double' || step === 'four') } : null,
    trick: s.trick.map((p) => ({ ...p })),
    lastTrick: s.lastTrick ? { plays: s.lastTrick.plays.map((p) => ({ ...p })), winner: s.lastTrick.winner } : null,
    trickNo: s.trickNo,
    teamTricks: [...s.teamTricks] as [number, number],
    abnat: [...s.abnat] as [number, number],
    projects,
    teamScores: [...s.teamScores] as [number, number],
    lastResult: s.lastResult ? structuredClone(s.lastResult) : null,
    winner: s.winner,
  };
}

// ---------------------------------------------------------------------------
// Autopilot (also drives computer players). Pure, deterministic, always legal.

/** Hokm strength of `suit` for a hand: J and 9 of trump, trump length, side aces. */
export function hokmStrength(hand: readonly Card[], suit: Suit): number {
  const trumps = hand.filter((c) => suitOf(c) === suit);
  let v = 0;
  if (trumps.some((c) => rankOf(c) === 11)) v += 3;
  if (trumps.some((c) => rankOf(c) === 9)) v += 2;
  if (trumps.some((c) => rankOf(c) === 14)) v += 1;
  v += Math.max(0, trumps.length - 2);
  v += hand.filter((c) => suitOf(c) !== suit && rankOf(c) === 14).length;
  return v;
}

/** Sun strength: aces count double, tens once. */
export function sunStrength(hand: readonly Card[]): number {
  return hand.filter((c) => rankOf(c) === 14).length * 2 + hand.filter((c) => rankOf(c) === 10).length;
}

/**
 * - Auction: sun with sun strength ≥ 6 (counting the face-up card, which the buyer receives); hokm with hokm
 *   strength ≥ 5; otherwise pass. Confirming its own hokm: always confirm.
 * - Raises: never.
 * - Play: lead an ace (or the trump Jack), else the weakest card; follow with the cheapest card that takes the
 *   trick unless the partner already holds it; otherwise throw the card worth the fewest points.
 */
export function autoBalootAction(s: BalootState, seat: Seat): BalootAction {
  if (s.phase === 'bidding') return autoCall(s, seat);
  if (s.phase === 'double') return { type: 'raise', raise: false };
  if (s.phase === 'playing') return { type: 'play', card: autoCard(s, seat) };
  throw new Error(`baloot autopilot: no move in phase ${s.phase}`);
}

function autoCall(s: BalootState, seat: Seat): BalootAction {
  const opts = balootCallOptions(s, seat);
  if (s.confirming) return { type: 'call', call: 'hokm' };
  const hand = s.hands[seat];
  const withFlipped = s.flipped ? [...hand, s.flipped] : hand;
  if (sunStrength(withFlipped) >= 6) return { type: 'call', call: 'sun' };
  if (opts.includes('hokm')) {
    const suits = balootHokmSuits(s);
    const cards = s.bidRound === 1 ? withFlipped : hand;
    const best = suits.slice().sort((a, b) => hokmStrength(cards, b) - hokmStrength(cards, a))[0];
    if (best && hokmStrength(cards, best) >= 5) return { type: 'call', call: 'hokm', suit: best };
  }
  return { type: 'call', call: 'pass' };
}

function autoCard(s: BalootState, seat: Seat): Card {
  const legal = balootLegal(s, seat);
  if (legal.length === 0) throw new Error('baloot autopilot: empty hand');
  const trump = s.trump;
  const weakest = (cs: Card[]) => cs.slice().sort((a, b) => balootValue(a, trump) - balootValue(b, trump) || balootPower(a, trump) - balootPower(b, trump) || a.localeCompare(b))[0];
  if (s.trick.length === 0) {
    const ace = legal.find((c) => rankOf(c) === 14 && suitOf(c) !== trump);
    if (ace) return ace;
    const jack = trump ? legal.find((c) => c === card(trump, 11)) : undefined;
    if (jack && teamOf(seat) === teamOf(s.buyer!)) return jack;
    return weakest(legal);
  }
  const w = balootTrickWinner(s.trick, trump);
  if (teamOf(w) === teamOf(seat)) return weakest(legal);
  const winners = legal.filter((c) => balootTrickWinner([...s.trick, { seat, card: c }], trump) === seat);
  if (winners.length > 0) return winners.sort((a, b) => balootPower(a, trump) - balootPower(b, trump) || a.localeCompare(b))[0];
  return weakest(legal);
}
