/**
 * One entry point over every game family, so the server stays game-agnostic: Tarneeb / Syrian 41 / 400 (game.ts),
 * Trix (trix.ts), 187 (b187.ts), Baloot (baloot.ts) and Hand (hand.ts) each keep their own state and rules; these functions dispatch on the variant.
 */
import type { RandInt, Seat } from './cards.ts';
import { type Action, type GameState, type Variant, act, advance, newGame } from './game.ts';
import { autoAction } from './autopilot.ts';
import { type PlayerView, viewFor } from './view.ts';
import {
  TRIX_KINGDOMS,
  type TrixAction,
  type TrixState,
  type TrixVariant,
  type TrixView,
  actTrix,
  advanceTrix,
  autoTrixAction,
  isTrixVariant,
  newTrixGame,
  trixContractsOf,
  trixViewFor,
} from './trix.ts';
import {
  B187_MATCH_LIMIT,
  B187_PLAYER_CHOICES,
  type B187Action,
  type B187State,
  type B187Variant,
  type B187View,
  act187,
  advance187,
  auto187Action,
  b187ViewFor,
  isB187Variant,
  new187Game,
} from './b187.ts';
import {
  BALOOT_TARGET,
  type BalootAction,
  type BalootState,
  type BalootVariant,
  type BalootView,
  actBaloot,
  advanceBaloot,
  autoBalootAction,
  balootViewFor,
  isBalootVariant,
  newBalootGame,
} from './baloot.ts';
import {
  HAND_PLAYER_CHOICES,
  HAND_ROUNDS,
  type HandAction,
  type HandState,
  type HandVariant,
  type HandView,
  actHand,
  advanceHand,
  autoHandAction,
  handViewFor,
  isHandVariant,
  newHandGame,
} from './hand.ts';

export type AnyVariant = Variant | TrixVariant | B187Variant | BalootVariant | HandVariant;
export const ALL_VARIANTS: readonly AnyVariant[] = ['tarneeb', 'syrian41', 'tarneeb400', 'trix', 'trixPartners', 'trixComplex', 'trixComplexPartners', 'b187', 'baloot', 'hand'];
export function isVariant(v: unknown): v is AnyVariant {
  return (ALL_VARIANTS as readonly unknown[]).includes(v);
}

/** Table sizes the host may pick when creating the room (187: 4 or 5, Hand: 2..5); null = always 4. */
export function playerChoices(v: AnyVariant): readonly number[] | null {
  if (isB187Variant(v)) return B187_PLAYER_CHOICES;
  if (isHandVariant(v)) return HAND_PLAYER_CHOICES;
  return null;
}
/** Seats at the table: the room's player count where the game allows a choice, else 4. */
export function seatCount(v: AnyVariant, players?: number): number {
  return playerChoices(v) ? (players ?? 4) : 4;
}
/** Variants with two fixed teams of opposite seats (the pre-game partner picker applies). */
export function hasTeams(v: AnyVariant): boolean {
  return v === 'tarneeb' || v === 'syrian41' || v === 'tarneeb400' || v === 'trixPartners' || v === 'trixComplexPartners' || v === 'baloot';
}

export type AnyGame = GameState | TrixState | B187State | BalootState | HandState;
export type AnyAction = Action | TrixAction | B187Action | BalootAction | HandAction;
export type AnyView = PlayerView | TrixView | B187View | BalootView | HandView;
export type AnyActResult = { ok: true; state: AnyGame } | { ok: false; error: string };

export function isTrixGame(g: AnyGame): g is TrixState {
  return isTrixVariant(g.variant);
}
export function is187Game(g: AnyGame): g is B187State {
  return isB187Variant(g.variant);
}
export function isBalootGame(g: AnyGame): g is BalootState {
  return isBalootVariant(g.variant);
}
export function isHandGame(g: AnyGame): g is HandState {
  return isHandVariant(g.variant);
}

export function newAnyGame(opts: { variant: AnyVariant; target?: number; players?: number }, randInt: RandInt): AnyGame {
  if (isTrixVariant(opts.variant)) return newTrixGame({ variant: opts.variant }, randInt);
  if (isB187Variant(opts.variant)) return new187Game({ players: opts.players }, randInt);
  if (isBalootVariant(opts.variant)) return newBalootGame({}, randInt);
  if (isHandVariant(opts.variant)) return newHandGame({ players: opts.players }, randInt);
  return newGame({ variant: opts.variant, target: opts.target }, randInt);
}

export function actAny(g: AnyGame, seat: number, a: AnyAction): AnyActResult {
  if (isTrixGame(g)) {
    if (a.type !== 'contract' && a.type !== 'double' && a.type !== 'play') return { ok: false, error: 'wrongPhase' };
    return actTrix(g, seat as Seat, a);
  }
  if (isHandGame(g)) {
    if (a.type !== 'draw' && a.type !== 'undoFire' && a.type !== 'meld' && a.type !== 'layoff' && a.type !== 'discard') return { ok: false, error: 'wrongPhase' };
    return actHand(g, seat, a);
  }
  if (isBalootGame(g)) {
    if (a.type !== 'call' && a.type !== 'raise' && a.type !== 'play') return { ok: false, error: 'wrongPhase' };
    return actBaloot(g, seat as Seat, a);
  }
  if (is187Game(g)) {
    if (a.type !== 'bid' && a.type !== 'give' && a.type !== 'trump' && a.type !== 'play' && a.type !== 'loss') return { ok: false, error: 'wrongPhase' };
    return act187(g, seat, a as B187Action);
  }
  if (a.type !== 'bid' && a.type !== 'trump' && a.type !== 'play') return { ok: false, error: 'wrongPhase' };
  return act(g, seat as Seat, a);
}

export function advanceAny(g: AnyGame, randInt: RandInt): AnyGame {
  if (isTrixGame(g)) return advanceTrix(g, randInt);
  if (is187Game(g)) return advance187(g, randInt);
  if (isBalootGame(g)) return advanceBaloot(g, randInt);
  if (isHandGame(g)) return advanceHand(g, randInt);
  return advance(g, randInt);
}

export function viewForAny(g: AnyGame, seat: number): AnyView {
  if (isTrixGame(g)) return trixViewFor(g, seat as Seat);
  if (is187Game(g)) return b187ViewFor(g, seat);
  if (isBalootGame(g)) return balootViewFor(g, seat as Seat);
  if (isHandGame(g)) return handViewFor(g, seat);
  return viewFor(g, seat as Seat);
}

export function autoActionAny(g: AnyGame, seat: number): AnyAction {
  if (isTrixGame(g)) return autoTrixAction(g, seat as Seat);
  if (is187Game(g)) return auto187Action(g, seat);
  if (isBalootGame(g)) return autoBalootAction(g, seat as Seat);
  if (isHandGame(g)) return autoHandAction(g, seat);
  return autoAction(g, seat as Seat);
}

/** Phases where a seat has to act (the turn timer runs). */
export const ACTING_PHASES: readonly string[] = ['bidding', 'trump', 'contract', 'double', 'give', 'draw', 'playing', 'lossChoice'];

/** How far the game is, 0..100 (for the public tables list). */
export function gameProgress(g: AnyGame, target: number): number {
  let pct: number;
  if (isTrixGame(g)) {
    const per = trixContractsOf(g.variant).length;
    pct = ((g.kingdom * per + g.used.length) / (TRIX_KINGDOMS * per)) * 100;
  }
  else if (isHandGame(g)) pct = ((g.handNo - 1) / HAND_ROUNDS) * 100;
  else if (isBalootGame(g)) pct = (Math.max(...g.teamScores) / BALOOT_TARGET) * 100;
  else if (is187Game(g)) pct = (Math.max(...g.scores.map(Math.abs)) / B187_MATCH_LIMIT) * 100;
  else pct = (Math.max(...g.teamScores) / target) * 100;
  return Math.max(0, Math.min(100, Math.round(pct)));
}

/**
 * The seats that won a finished game (several on a tie; a whole team in a partnership game).
 * Empty while the game is still running, or when it ended in a draw with no winner.
 */
export function matchWinners(g: AnyGame): number[] {
  if (g.phase !== 'gameOver') return [];
  if (isTrixGame(g) || is187Game(g)) return g.winnerSeats.slice();
  if (isHandGame(g)) return g.winners.slice();
  // tarneeb / syrian 41 / 400 / baloot: a team (seats 0+2 or 1+3)
  const team = g.winner;
  if (team === null) return [];
  return [0, 1, 2, 3].filter((s) => s % 2 === team);
}

/** Seats of a finished game from best to worst (by the game's own scores), for knockout tables that send on two. */
export function seatRanking(g: AnyGame): number[] {
  const seats = Array.from({ length: isHandGame(g) || is187Game(g) ? g.scores.length : 4 }, (_, i) => i);
  const score = (s: number): number => {
    if (isHandGame(g)) return -g.scores[s]; // Hand: the lowest total is best
    if (is187Game(g)) return g.scores[s];
    if (isTrixGame(g)) return g.variant === 'trixPartners' || g.variant === 'trixComplexPartners' ? g.teamScores[s % 2] : g.seatScores[s];
    if (isBalootGame(g)) return g.teamScores[s % 2];
    return g.variant === 'syrian41' ? g.seatScores[s] : g.teamScores[s % 2];
  };
  const winners = new Set(matchWinners(g));
  return seats.sort((a, b) => Number(winners.has(b)) - Number(winners.has(a)) || score(b) - score(a));
}
