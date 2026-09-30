import {
  type Card,
  type RandInt,
  type Seat,
  type Suit,
  type Team,
  SUITS,
  deal,
  isCard,
  nextSeat,
  sisterSuit,
  suitOf,
  teamOf,
} from './cards.ts';
import { type Play, legalCards, trickWinner } from './trick.ts';
import {
  SYRIAN_MIN_TOTAL_BIDS,
  SYRIAN_TARGET,
  type TarneebNote,
  scoreSyrianSeat,
  scoreTarneebHand,
  syrianWinner,
  tarneebWinner,
} from './scoring.ts';

export type Variant = 'tarneeb' | 'syrian41';
export const TARGETS = [31, 41, 61] as const;
export type Target = (typeof TARGETS)[number];

/**
 * bidding  -> players bid (turn = seat to act)
 * trump    -> (tarneeb only) winning bidder picks the trump suit
 * playing  -> trick play (turn = seat to act)
 * trickDone-> 4 cards on the table; the server calls advance() after a short pause
 * handOver -> hand scored (or redeal); the server calls advance() to deal the next hand
 * gameOver -> winner decided
 */
export type Phase = 'bidding' | 'trump' | 'playing' | 'trickDone' | 'handOver' | 'gameOver';

export type Bid = number | 'pass';

export interface HandResult {
  kind: 'scored' | 'redeal';
  /** redeal reasons: 'allPass' (tarneeb), 'lowBids' (syrian) */
  note: TarneebNote | 'allPass' | 'lowBids' | 'syrian';
  /** tarneeb: bidding seat and bid; syrian: undefined */
  bidder?: Seat;
  bid?: number;
  bidderTricks?: number;
  /** team deltas (tarneeb) */
  teamDelta: [number, number];
  /** per-seat deltas (syrian) */
  seatDelta: [number, number, number, number];
}

export interface GameState {
  variant: Variant;
  target: number;
  dealer: Seat;
  handNo: number;
  phase: Phase;
  hands: Card[][];
  turn: Seat;
  bidLog: { seat: Seat; bid: Bid }[];
  /** tarneeb: who passed out of the auction */
  passed: boolean[];
  /** tarneeb: current highest bid */
  highBid: { seat: Seat; value: number } | null;
  /** syrian: each seat's bid for itself */
  seatBids: (number | null)[];
  trump: Suit | null;
  /** syrian: the dealer's last card, turned face up */
  revealed: Card | null;
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  /** tricks taken this hand, per seat */
  tricks: number[];
  teamScores: [number, number];
  /** syrian: running score per seat */
  seatScores: [number, number, number, number];
  lastResult: HandResult | null;
  winner: Team | null;
}

export type Action =
  | { type: 'bid'; value: Bid }
  | { type: 'trump'; suit: Suit }
  | { type: 'play'; card: Card };

export type ActResult = { ok: true; state: GameState } | { ok: false; error: string };

export interface NewGameOptions {
  variant: Variant;
  target?: number;
  /** fix the first dealer (tests); otherwise random */
  dealer?: Seat;
}

export function newGame(opts: NewGameOptions, randInt: RandInt): GameState {
  const target = opts.variant === 'syrian41' ? SYRIAN_TARGET : opts.target ?? 41;
  if (opts.variant === 'tarneeb' && !(TARGETS as readonly number[]).includes(target)) throw new Error('bad target');
  const dealer = opts.dealer ?? (randInt(4) as Seat);
  const base: GameState = {
    variant: opts.variant,
    target,
    dealer,
    handNo: 0,
    phase: 'bidding',
    hands: [[], [], [], []],
    turn: nextSeat(dealer),
    bidLog: [],
    passed: [false, false, false, false],
    highBid: null,
    seatBids: [null, null, null, null],
    trump: null,
    revealed: null,
    trick: [],
    lastTrick: null,
    tricks: [0, 0, 0, 0],
    teamScores: [0, 0],
    seatScores: [0, 0, 0, 0],
    lastResult: null,
    winner: null,
  };
  return startHand(base, randInt, dealer);
}

/** Deal a fresh hand for `dealer`, keeping scores. Exported for tests (lets them inject exact hands). */
export function startHand(
  prev: GameState,
  randInt: RandInt,
  dealer: Seat,
  preset?: { hands: Card[][]; lastCardOfDealer: Card },
): GameState {
  const d = preset ? { hands: preset.hands.map((h) => h.slice()), lastCardOfDealer: preset.lastCardOfDealer } : deal(randInt, dealer);
  const s: GameState = {
    ...structuredClone(prev),
    dealer,
    handNo: prev.handNo + 1,
    phase: 'bidding',
    hands: d.hands,
    turn: nextSeat(dealer),
    bidLog: [],
    passed: [false, false, false, false],
    highBid: null,
    seatBids: [null, null, null, null],
    trump: null,
    revealed: null,
    trick: [],
    lastTrick: null,
    tricks: [0, 0, 0, 0],
  };
  if (s.variant === 'syrian41') {
    s.revealed = d.lastCardOfDealer;
    s.trump = sisterSuit(suitOf(d.lastCardOfDealer));
  }
  return s;
}

function nextActiveBidder(s: GameState, from: Seat): Seat {
  let t = nextSeat(from);
  for (let i = 0; i < 4; i++) {
    if (!s.passed[t]) return t;
    t = nextSeat(t);
  }
  return from;
}

/** Lowest bid the seat to act may make (tarneeb), or null if bidding is closed. */
export function minBid(s: GameState): number {
  if (s.variant === 'syrian41') return 2;
  return s.highBid ? s.highBid.value + 1 : 7;
}

export function act(prev: GameState, seat: Seat, a: Action): ActResult {
  if (prev.phase === 'gameOver') return { ok: false, error: 'gameOver' };
  if (seat !== prev.turn) return { ok: false, error: 'notYourTurn' };
  const s = structuredClone(prev);
  switch (a.type) {
    case 'bid':
      return s.variant === 'tarneeb' ? bidTarneeb(s, seat, a.value) : bidSyrian(s, seat, a.value);
    case 'trump':
      return chooseTrump(s, seat, a.suit);
    case 'play':
      return playCard(s, seat, a.card);
    default:
      return { ok: false, error: 'badAction' };
  }
}

function bidTarneeb(s: GameState, seat: Seat, value: Bid): ActResult {
  if (s.phase !== 'bidding') return { ok: false, error: 'wrongPhase' };
  if (value === 'pass') {
    s.passed[seat] = true;
  } else {
    if (!Number.isInteger(value) || value < minBid(s) || value > 13) return { ok: false, error: 'badBid' };
    s.highBid = { seat, value };
  }
  s.bidLog.push({ seat, bid: value });

  if (s.highBid && s.highBid.value === 13) return endTarneebAuction(s);
  const active = [0, 1, 2, 3].filter((x) => !s.passed[x]);
  if (!s.highBid && active.length === 0) {
    s.phase = 'handOver';
    s.lastResult = { kind: 'redeal', note: 'allPass', teamDelta: [0, 0], seatDelta: [0, 0, 0, 0] };
    return { ok: true, state: s };
  }
  if (s.highBid && active.every((x) => x === s.highBid!.seat)) return endTarneebAuction(s);
  const nxt = nextActiveBidder(s, seat);
  if (s.highBid && nxt === s.highBid.seat) return endTarneebAuction(s); // defensive, see docs
  s.turn = nxt;
  return { ok: true, state: s };
}

function endTarneebAuction(s: GameState): ActResult {
  s.phase = 'trump';
  s.turn = s.highBid!.seat;
  return { ok: true, state: s };
}

function chooseTrump(s: GameState, seat: Seat, suit: Suit): ActResult {
  if (s.variant !== 'tarneeb' || s.phase !== 'trump') return { ok: false, error: 'wrongPhase' };
  if (!SUITS.includes(suit)) return { ok: false, error: 'badSuit' };
  s.trump = suit;
  s.phase = 'playing';
  s.turn = seat; // the declarer leads the first trick
  return { ok: true, state: s };
}

function bidSyrian(s: GameState, seat: Seat, value: Bid): ActResult {
  if (s.phase !== 'bidding') return { ok: false, error: 'wrongPhase' };
  if (value === 'pass' || !Number.isInteger(value) || value < 2 || value > 13) return { ok: false, error: 'badBid' };
  if (s.seatBids[seat] !== null) return { ok: false, error: 'alreadyBid' };
  s.seatBids[seat] = value;
  s.bidLog.push({ seat, bid: value });
  if (s.seatBids.every((b) => b !== null)) {
    const total = (s.seatBids as number[]).reduce((a, b) => a + b, 0);
    if (total < SYRIAN_MIN_TOTAL_BIDS) {
      s.phase = 'handOver';
      s.lastResult = { kind: 'redeal', note: 'lowBids', teamDelta: [0, 0], seatDelta: [0, 0, 0, 0] };
      return { ok: true, state: s };
    }
    s.phase = 'playing';
    s.turn = nextSeat(s.dealer); // decision: the player right of the dealer leads
    return { ok: true, state: s };
  }
  s.turn = nextSeat(seat);
  return { ok: true, state: s };
}

function playCard(s: GameState, seat: Seat, c: Card): ActResult {
  if (s.phase !== 'playing') return { ok: false, error: 'wrongPhase' };
  if (!isCard(c)) return { ok: false, error: 'badCard' };
  const hand = s.hands[seat];
  if (!hand.includes(c)) return { ok: false, error: 'notInHand' };
  if (!legalCards(hand, s.trick).includes(c)) return { ok: false, error: 'mustFollowSuit' };
  s.hands[seat] = hand.filter((x) => x !== c);
  s.trick.push({ seat, card: c });
  if (s.trick.length === 4) {
    s.phase = 'trickDone';
    s.turn = trickWinner(s.trick, s.trump);
  } else {
    s.turn = nextSeat(seat);
  }
  return { ok: true, state: s };
}

/** Server-driven transitions: collect a finished trick, or deal the next hand. No-op in other phases. */
export function advance(prev: GameState, randInt: RandInt): GameState {
  if (prev.phase === 'trickDone') return collectTrick(prev);
  if (prev.phase === 'handOver') return startHand(prev, randInt, nextSeat(prev.dealer));
  return prev;
}

function collectTrick(prev: GameState): GameState {
  const s = structuredClone(prev);
  const winner = trickWinner(s.trick, s.trump);
  s.tricks[winner]++;
  s.lastTrick = { plays: s.trick, winner };
  s.trick = [];
  s.turn = winner;
  if (s.hands.every((h) => h.length === 0)) return scoreHand(s);
  s.phase = 'playing';
  return s;
}

function scoreHand(s: GameState): GameState {
  if (s.variant === 'tarneeb') {
    const bidder = s.highBid!.seat;
    const team = teamOf(bidder);
    const bidderTricks = s.tricks[bidder] + s.tricks[(bidder + 2) % 4];
    const { delta, note } = scoreTarneebHand(s.highBid!.value, team, bidderTricks);
    s.teamScores = [s.teamScores[0] + delta[0], s.teamScores[1] + delta[1]];
    s.lastResult = { kind: 'scored', note, bidder, bid: s.highBid!.value, bidderTricks, teamDelta: delta, seatDelta: [0, 0, 0, 0] };
    s.winner = tarneebWinner(s.teamScores, s.target);
  } else {
    const seatDelta = [0, 1, 2, 3].map((x) => scoreSyrianSeat(s.seatBids[x]!, s.tricks[x])) as [number, number, number, number];
    s.seatScores = s.seatScores.map((v, i) => v + seatDelta[i]) as [number, number, number, number];
    s.teamScores = [s.seatScores[0] + s.seatScores[2], s.seatScores[1] + s.seatScores[3]];
    s.lastResult = { kind: 'scored', note: 'syrian', teamDelta: [seatDelta[0] + seatDelta[2], seatDelta[1] + seatDelta[3]], seatDelta };
    s.winner = syrianWinner(s.seatScores, s.target);
  }
  s.phase = s.winner === null ? 'handOver' : 'gameOver';
  return s;
}
