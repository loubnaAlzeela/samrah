/// What one seat sees in a Saudi Hand game (packages/rules/src/hand.ts
/// `HandGameView`), sent inside `state.game` for the 'hand' variant. Only the
/// viewer's own cards; melds on the table and the discard-pile top are public.
/// Cards carry a copy letter (two decks): "S5a", "S5b"; jokers "Xa" / "Xb".
library;

import 'json_num.dart';

bool isHandVariant(String v) => v == 'hand';

bool isJokerCode(String c) => c.startsWith('X');

/// Strength inside a suit for sorting the hand (jokers first, then by rank).
int handSortPower(String c) => isJokerCode(c) ? 99 : int.parse(c.substring(1, c.length - 1));

class MeldCardView {
  final String card;

  /// the rank this card stands for, 1..14 (1 = ace low)
  final int rank;
  MeldCardView({required this.card, required this.rank});
}

class HandMeld {
  final int id;
  final int owner;
  final String kind; // run | set
  final List<MeldCardView> cards;
  HandMeld({required this.id, required this.owner, required this.kind, required this.cards});

  static HandMeld fromJson(Map json) => HandMeld(
        id: asInt(json['id']),
        owner: asInt(json['owner']),
        kind: json['kind'] as String,
        cards: ((json['cards'] as List?) ?? const []).map((e) => MeldCardView(card: (e as Map)['card'] as String, rank: asInt(e['rank']))).toList(),
      );
}

class HandRoundResult {
  final int? winner;
  final bool hand;
  final List<int> delta;
  final List<List<String>> left;
  final List<bool> opened;
  HandRoundResult({required this.winner, required this.hand, required this.delta, required this.left, required this.opened});

  static HandRoundResult fromJson(Map json) => HandRoundResult(
        winner: asIntOrNull(json['winner']),
        hand: json['hand'] == true,
        delta: ((json['delta'] as List?) ?? const []).map(asInt).toList(),
        left: ((json['left'] as List?) ?? const []).map((h) => (h as List).map((c) => c as String).toList()).toList(),
        opened: ((json['opened'] as List?) ?? const []).map((b) => b == true).toList(),
      );
}

class HandGameView {
  final int players;
  final String phase; // draw | playing | handOver | gameOver
  final int handNo;
  final int rounds;
  final int dealer;
  final int turn;
  final int mySeat;
  final List<String> myHand;
  final List<int> handCounts;
  final int stockCount;
  final String? fireTop;
  final int fireCount;
  final List<HandMeld> melds;
  final List<bool> opened;
  final int openMin;

  /// my turn only: how I drew ('start' = first player, no draw)
  final String? drew;

  /// my turn only: taken from the discard pile, must go into my next lay-down
  final String? fireCard;
  final bool canUndoFire;
  final List<int> scores;
  final HandRoundResult? lastResult;
  final List<int> winners;

  HandGameView({
    required this.players,
    required this.phase,
    required this.handNo,
    required this.rounds,
    required this.dealer,
    required this.turn,
    required this.mySeat,
    required this.myHand,
    required this.handCounts,
    required this.stockCount,
    required this.fireTop,
    required this.fireCount,
    required this.melds,
    required this.opened,
    required this.openMin,
    required this.drew,
    required this.fireCard,
    required this.canUndoFire,
    required this.scores,
    required this.lastResult,
    required this.winners,
  });

  static List<int> _ints(Object? v) => ((v as List?) ?? const []).map(asInt).toList();

  static HandGameView fromJson(Map json) => HandGameView(
        players: asIntOr(json['players'], 4),
        phase: json['phase'] as String,
        handNo: asInt(json['handNo']),
        rounds: asIntOr(json['rounds'], 5),
        dealer: asInt(json['dealer']),
        turn: asInt(json['turn']),
        mySeat: asInt(json['mySeat']),
        myHand: ((json['myHand'] as List?) ?? const []).map((e) => e as String).toList(),
        handCounts: _ints(json['handCounts']),
        stockCount: asIntOr(json['stockCount'], 0),
        fireTop: json['fireTop'] as String?,
        fireCount: asIntOr(json['fireCount'], 0),
        melds: ((json['melds'] as List?) ?? const []).map((e) => HandMeld.fromJson(e as Map)).toList(),
        opened: ((json['opened'] as List?) ?? const []).map((b) => b == true).toList(),
        openMin: asIntOr(json['openMin'], 51),
        drew: json['drew'] as String?,
        fireCard: json['fireCard'] as String?,
        canUndoFire: json['canUndoFire'] == true,
        scores: _ints(json['scores']),
        lastResult: json['lastResult'] != null ? HandRoundResult.fromJson(json['lastResult'] as Map) : null,
        winners: _ints(json['winners']),
      );
}
