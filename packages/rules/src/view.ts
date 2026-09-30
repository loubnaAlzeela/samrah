import type { Card, Seat, Suit, Team } from './cards.ts';
import { type Bid, type GameState, type HandResult, type Phase, type Variant, minBid } from './game.ts';
import { type Play, legalCards } from './trick.ts';

/**
 * What one seat is allowed to see. Built on the server and sent only to that seat's connection.
 * Contains the viewer's own hand and COUNTS of the other hands - never the other hands themselves.
 */
export interface PlayerView {
  variant: Variant;
  target: number;
  phase: Phase;
  handNo: number;
  dealer: Seat;
  turn: Seat;
  mySeat: Seat;
  myHand: Card[];
  /** cards the viewer may play right now (empty when it is not their turn to play) */
  legal: Card[];
  /** lowest bid the viewer may make when it is their turn to bid */
  minBid: number | null;
  handCounts: number[];
  bidLog: { seat: Seat; bid: Bid }[];
  passed: boolean[];
  highBid: { seat: Seat; value: number } | null;
  seatBids: (number | null)[];
  trump: Suit | null;
  revealed: Card | null;
  trick: Play[];
  lastTrick: { plays: Play[]; winner: Seat } | null;
  tricks: number[];
  teamScores: [number, number];
  seatScores: [number, number, number, number];
  lastResult: HandResult | null;
  winner: Team | null;
}

export function viewFor(s: GameState, seat: Seat): PlayerView {
  const myTurn = s.turn === seat;
  return {
    variant: s.variant,
    target: s.target,
    phase: s.phase,
    handNo: s.handNo,
    dealer: s.dealer,
    turn: s.turn,
    mySeat: seat,
    myHand: s.hands[seat].slice(),
    legal: myTurn && s.phase === 'playing' ? legalCards(s.hands[seat], s.trick) : [],
    minBid: myTurn && s.phase === 'bidding' ? minBid(s) : null,
    handCounts: s.hands.map((h) => h.length),
    bidLog: s.bidLog.map((b) => ({ ...b })),
    passed: s.passed.slice(),
    highBid: s.highBid ? { ...s.highBid } : null,
    seatBids: s.seatBids.slice(),
    trump: s.trump,
    revealed: s.revealed,
    trick: s.trick.map((p) => ({ ...p })),
    lastTrick: s.lastTrick ? { plays: s.lastTrick.plays.map((p) => ({ ...p })), winner: s.lastTrick.winner } : null,
    tricks: s.tricks.slice(),
    teamScores: [...s.teamScores] as [number, number],
    seatScores: [...s.seatScores] as [number, number, number, number],
    lastResult: s.lastResult ? structuredClone(s.lastResult) : null,
    winner: s.winner,
  };
}
