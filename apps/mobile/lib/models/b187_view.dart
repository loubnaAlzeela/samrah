/// What one seat sees in a 187 game (packages/rules/src/b187.ts `B187View`),
/// sent inside `state.game` for the 'b187' variant (4 or 5 players).
library;

import 'json_num.dart';
import 'player_view.dart';

bool isB187Variant(String v) => v == 'b187';

/// Card points in 187: A=11, 10=10, K/Q/J=4, each 2=10, 2♥=25, the rest 0.
int b187Points(String card) {
  if (card == 'H2') return 25;
  return switch (int.parse(card.substring(1))) {
    2 => 10,
    14 => 11,
    10 => 10,
    11 || 12 || 13 => 4,
    _ => 0,
  };
}

/// Trick strength inside a suit: 2 > A > K > 10 > Q > J > 9 > 8 > 7 > 6.
int b187Power(String card) => switch (int.parse(card.substring(1))) {
      2 => 10,
      14 => 9,
      13 => 8,
      10 => 7,
      12 => 6,
      11 => 5,
      final r => r - 5, // 9..6 -> 4..1
    };

/// Hand order before a trump is named: ♥ ♦ ♠ ♣; once named, the trump suit moves to the front.
List<String> b187SuitOrder(String? trump) {
  const base = ['H', 'D', 'S', 'C'];
  return trump == null ? base : [trump, ...base.where((s) => s != trump)];
}

/// One void deal: the seats that held under 12 points.
class B187Redeal {
  final List<({int seat, int points})> short;
  B187Redeal(this.short);
  static B187Redeal fromJson(Map json) => B187Redeal([
        for (final e in (json['short'] as List?) ?? const []) (seat: asInt((e as Map)['seat']), points: asInt(e['points'])),
      ]);
}

class B187Bid {
  final int seat;

  /// an int, or the string 'pass'
  final Object bid;
  B187Bid({required this.seat, required this.bid});
  bool get isPass => bid == 'pass';
  static B187Bid fromJson(Map json) {
    final raw = json['bid'];
    return B187Bid(seat: asInt(json['seat']), bid: raw is num ? raw.toInt() : raw as Object);
  }
}

class B187Result {
  final int buyer;
  final int bid;
  final List<int> collected;
  final bool lost;
  final bool full;
  final List<int> seatDelta;
  B187Result({required this.buyer, required this.bid, required this.collected, required this.lost, required this.full, required this.seatDelta});

  static B187Result fromJson(Map json) => B187Result(
        buyer: asInt(json['buyer']),
        bid: asInt(json['bid']),
        collected: ((json['collected'] as List?) ?? const []).map(asInt).toList(),
        lost: json['lost'] == true,
        full: json['full'] == true,
        seatDelta: ((json['seatDelta'] as List?) ?? const []).map(asInt).toList(),
      );
}

class B187View {
  final String variant;
  final int players;
  final String phase; // bidding | give | trump | playing | trickDone | lossChoice | handOver | gameOver
  final int handNo;
  final int dealer;
  final int turn;
  final int mySeat;
  final List<String> myHand;
  final List<String> legal;
  final int? minBid;
  final int giveCount;

  /// the field cards just added to my hand (buyer, give phase only): which cards in [myHand] are new
  final List<String> kittyCards;
  final int fieldCount;
  final List<String> field;
  final List<B187Bid> bidLog;
  final List<bool> passed;
  final HighBid? highBid;
  final int? buyer;
  final String? trump;
  final List<int> handCounts;
  final List<Play> trick;
  final LastTrick? lastTrick;
  final List<int> tricks;
  final List<int> collected;
  final List<int> scores;
  final B187Result? lastResult;
  final List<int> winnerSeats;

  /// void deals thrown in before this hand (someone held under 12 points)
  final List<B187Redeal> redeals;

  B187View({
    required this.variant,
    required this.players,
    required this.phase,
    required this.handNo,
    required this.dealer,
    required this.turn,
    required this.mySeat,
    required this.myHand,
    required this.legal,
    required this.minBid,
    required this.giveCount,
    this.kittyCards = const [],
    required this.fieldCount,
    required this.field,
    required this.bidLog,
    required this.passed,
    required this.highBid,
    required this.buyer,
    required this.trump,
    required this.handCounts,
    required this.trick,
    required this.lastTrick,
    required this.tricks,
    required this.collected,
    required this.scores,
    required this.lastResult,
    required this.winnerSeats,
    this.redeals = const [],
  });

  /// Last bid a seat made this auction, or null.
  Object? lastBidBy(int seat) {
    for (var i = bidLog.length - 1; i >= 0; i--) {
      if (bidLog[i].seat == seat) return bidLog[i].bid;
    }
    return null;
  }

  static List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e as String).toList();
  static List<int> _ints(Object? v) => ((v as List?) ?? const []).map(asInt).toList();

  static B187View fromJson(Map json) => B187View(
        variant: json['variant'] as String,
        players: asInt(json['players']),
        phase: json['phase'] as String,
        handNo: asInt(json['handNo']),
        dealer: asInt(json['dealer']),
        turn: asInt(json['turn']),
        mySeat: asInt(json['mySeat']),
        myHand: _strings(json['myHand']),
        legal: _strings(json['legal']),
        minBid: asIntOrNull(json['minBid']),
        giveCount: asIntOr(json['giveCount'], 0),
        kittyCards: _strings(json['kittyCards']),
        fieldCount: asIntOr(json['fieldCount'], 0),
        field: _strings(json['field']),
        bidLog: ((json['bidLog'] as List?) ?? const []).map((e) => B187Bid.fromJson(e as Map)).toList(),
        passed: ((json['passed'] as List?) ?? const []).map((e) => e == true).toList(),
        highBid: json['highBid'] != null ? HighBid.fromJson(json['highBid'] as Map) : null,
        buyer: asIntOrNull(json['buyer']),
        trump: json['trump'] as String?,
        handCounts: _ints(json['handCounts']),
        trick: ((json['trick'] as List?) ?? const []).map((e) => Play.fromJson(e as Map)).toList(),
        lastTrick: json['lastTrick'] != null ? LastTrick.fromJson(json['lastTrick'] as Map) : null,
        tricks: _ints(json['tricks']),
        collected: _ints(json['collected']),
        scores: _ints(json['scores']),
        lastResult: json['lastResult'] != null ? B187Result.fromJson(json['lastResult'] as Map) : null,
        winnerSeats: _ints(json['winnerSeats']),
        redeals: ((json['redeals'] as List?) ?? const []).map((e) => B187Redeal.fromJson(e as Map)).toList(),
      );
}
