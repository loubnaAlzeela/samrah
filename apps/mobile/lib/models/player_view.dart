/// What one seat is allowed to see, as sent by the server inside `state.game`
/// (see packages/rules/src/view.ts `PlayerView`, apps/server/src/LammaRoom.ts
/// `broadcastViews`). Only the viewer's own hand + public counts, never the
/// other hands.
library;

import 'json_num.dart';

class BidEntry {
  final int seat;

  /// Either an int (a real bid) or the string 'pass'.
  final Object bid;

  BidEntry({required this.seat, required this.bid});

  bool get isPass => bid == 'pass';
  int? get value => bid is num ? (bid as num).toInt() : null;

  static BidEntry fromJson(Map json) {
    final rawBid = json['bid'];
    return BidEntry(seat: asInt(json['seat']), bid: rawBid is num ? rawBid.toInt() : rawBid as Object);
  }
}

class HighBid {
  final int seat;
  final int value;
  HighBid({required this.seat, required this.value});
  static HighBid fromJson(Map json) => HighBid(seat: asInt(json['seat']), value: asInt(json['value']));
}

class Play {
  final int seat;
  final String card;
  Play({required this.seat, required this.card});
  static Play fromJson(Map json) => Play(seat: asInt(json['seat']), card: json['card'] as String);
}

class LastTrick {
  final List<Play> plays;
  final int winner;
  LastTrick({required this.plays, required this.winner});
  static LastTrick fromJson(Map json) => LastTrick(
        plays: ((json['plays'] as List?) ?? const []).map((p) => Play.fromJson(p as Map)).toList(),
        winner: asInt(json['winner']),
      );
}

class HandResult {
  final String kind; // 'scored' | 'redeal'
  final String note;
  final int? bidder;
  final int? bid;
  final int? bidderTricks;
  final List<int> teamDelta;
  final List<int> seatDelta;

  HandResult({
    required this.kind,
    required this.note,
    this.bidder,
    this.bid,
    this.bidderTricks,
    required this.teamDelta,
    required this.seatDelta,
  });

  static HandResult fromJson(Map json) => HandResult(
        kind: json['kind'] as String,
        note: json['note'] as String,
        bidder: asIntOrNull(json['bidder']),
        bid: asIntOrNull(json['bid']),
        bidderTricks: asIntOrNull(json['bidderTricks']),
        teamDelta: ((json['teamDelta'] as List?) ?? const [0, 0]).map(asInt).toList(),
        seatDelta: ((json['seatDelta'] as List?) ?? const [0, 0, 0, 0]).map(asInt).toList(),
      );
}

class PlayerView {
  final String variant; // 'tarneeb' | 'syrian41'
  final int target;
  final String phase; // bidding | trump | playing | trickDone | handOver | gameOver
  final int handNo;
  final int dealer;
  final int turn;
  final int mySeat;
  final List<String> myHand;
  final List<String> legal;
  final int? minBid;
  final List<int> handCounts;
  final List<BidEntry> bidLog;
  final List<bool> passed;
  final HighBid? highBid;
  final List<int?> seatBids;
  final String? trump; // suit char, null before chosen
  final String? revealed; // syrian: dealer's turned-up card
  final List<Play> trick;
  final LastTrick? lastTrick;
  final List<int> tricks;
  final List<int> teamScores;
  final List<int> seatScores;
  final HandResult? lastResult;
  final int? winner; // team 0/1, null while undecided

  PlayerView({
    required this.variant,
    required this.target,
    required this.phase,
    required this.handNo,
    required this.dealer,
    required this.turn,
    required this.mySeat,
    required this.myHand,
    required this.legal,
    required this.minBid,
    required this.handCounts,
    required this.bidLog,
    required this.passed,
    required this.highBid,
    required this.seatBids,
    required this.trump,
    required this.revealed,
    required this.trick,
    required this.lastTrick,
    required this.tricks,
    required this.teamScores,
    required this.seatScores,
    required this.lastResult,
    required this.winner,
  });

  /// Last bid a given seat made (or null if it hasn't bid yet this auction).
  Object? lastBidBy(int seat) {
    for (var i = bidLog.length - 1; i >= 0; i--) {
      if (bidLog[i].seat == seat) return bidLog[i].bid;
    }
    return null;
  }

  static PlayerView fromJson(Map json) => PlayerView(
        variant: json['variant'] as String,
        target: asInt(json['target']),
        phase: json['phase'] as String,
        handNo: asInt(json['handNo']),
        dealer: asInt(json['dealer']),
        turn: asInt(json['turn']),
        mySeat: asInt(json['mySeat']),
        myHand: ((json['myHand'] as List?) ?? const []).map((e) => e as String).toList(),
        legal: ((json['legal'] as List?) ?? const []).map((e) => e as String).toList(),
        minBid: asIntOrNull(json['minBid']),
        handCounts: ((json['handCounts'] as List?) ?? const [0, 0, 0, 0]).map(asInt).toList(),
        bidLog: ((json['bidLog'] as List?) ?? const []).map((e) => BidEntry.fromJson(e as Map)).toList(),
        passed: ((json['passed'] as List?) ?? const [false, false, false, false]).map((e) => e as bool).toList(),
        highBid: json['highBid'] != null ? HighBid.fromJson(json['highBid'] as Map) : null,
        seatBids: ((json['seatBids'] as List?) ?? const [null, null, null, null]).map(asIntOrNull).toList(),
        trump: json['trump'] as String?,
        revealed: json['revealed'] as String?,
        trick: ((json['trick'] as List?) ?? const []).map((e) => Play.fromJson(e as Map)).toList(),
        lastTrick: json['lastTrick'] != null ? LastTrick.fromJson(json['lastTrick'] as Map) : null,
        tricks: ((json['tricks'] as List?) ?? const [0, 0, 0, 0]).map(asInt).toList(),
        teamScores: ((json['teamScores'] as List?) ?? const [0, 0]).map(asInt).toList(),
        seatScores: ((json['seatScores'] as List?) ?? const [0, 0, 0, 0]).map(asInt).toList(),
        lastResult: json['lastResult'] != null ? HandResult.fromJson(json['lastResult'] as Map) : null,
        winner: asIntOrNull(json['winner']),
      );
}
