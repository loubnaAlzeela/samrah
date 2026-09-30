/// What one seat sees in a Trix game (packages/rules/src/trix.ts `TrixView`),
/// sent inside `state.game` for the 'trix' / 'trixPartners' variants. Only
/// the viewer's own hand; doubled cards are public by the rules.
library;

import 'json_num.dart';
import 'player_view.dart';

bool isTrixVariant(String v) => v == 'trix' || v == 'trixPartners';

const trixContracts = ['king', 'queens', 'diamonds', 'tricks', 'trix'];

/// Arabic contract names.
String contractNameAr(String c) => switch (c) {
      'king' => 'شيخ الكبة',
      'queens' => 'بنات',
      'diamonds' => 'ديناري',
      'tricks' => 'لطوش',
      'trix' => 'تركس',
      _ => c,
    };

class DoubledCard {
  final String card;
  final int seat;
  DoubledCard({required this.card, required this.seat});
  static DoubledCard fromJson(Map json) => DoubledCard(card: json['card'] as String, seat: asInt(json['seat']));
}

/// One suit's sequence on the table in the trix contract: ranks low..high placed.
class TrixPile {
  final int low;
  final int high;
  TrixPile({required this.low, required this.high});
}

class TrixResult {
  final String contract;
  final int kingdomOwner;
  final List<int> seatDelta;
  final List<int> teamDelta;
  final List<int> finishOrder;
  TrixResult({required this.contract, required this.kingdomOwner, required this.seatDelta, required this.teamDelta, required this.finishOrder});

  static TrixResult fromJson(Map json) => TrixResult(
        contract: json['contract'] as String,
        kingdomOwner: asInt(json['kingdomOwner']),
        seatDelta: ((json['seatDelta'] as List?) ?? const [0, 0, 0, 0]).map(asInt).toList(),
        teamDelta: ((json['teamDelta'] as List?) ?? const [0, 0]).map(asInt).toList(),
        finishOrder: ((json['finishOrder'] as List?) ?? const []).map(asInt).toList(),
      );
}

class TrixView {
  final String variant;
  final String phase; // contract | double | playing | trickDone | handOver | gameOver
  final int handNo;
  final int kingdom;
  final int kingdomOwner;
  final List<String> contractsLeft;
  final String? contract;
  final int dealer;
  final int turn;
  final int mySeat;
  final List<String> myHand;
  final List<String> legal;
  final List<String> doubleOptions;
  final List<DoubledCard> doubled;
  final List<int> handCounts;
  final List<Play> trick;
  final LastTrick? lastTrick;
  final List<int> tricks;
  final List<int> handPoints;
  final Map<String, TrixPile?> layout;
  final List<int> finishOrder;
  final List<int> lastPasses;
  final List<int> teamScores;
  final List<int> seatScores;
  final TrixResult? lastResult;
  final int? winner;
  final List<int> winnerSeats;

  TrixView({
    required this.variant,
    required this.phase,
    required this.handNo,
    required this.kingdom,
    required this.kingdomOwner,
    required this.contractsLeft,
    required this.contract,
    required this.dealer,
    required this.turn,
    required this.mySeat,
    required this.myHand,
    required this.legal,
    required this.doubleOptions,
    required this.doubled,
    required this.handCounts,
    required this.trick,
    required this.lastTrick,
    required this.tricks,
    required this.handPoints,
    required this.layout,
    required this.finishOrder,
    required this.lastPasses,
    required this.teamScores,
    required this.seatScores,
    required this.lastResult,
    required this.winner,
    required this.winnerSeats,
  });

  bool get partners => variant == 'trixPartners';

  static List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e as String).toList();
  static List<int> _ints(Object? v, List<int> fallback) => ((v as List?) ?? fallback).map(asInt).toList();

  static TrixView fromJson(Map json) {
    final layoutRaw = (json['layout'] as Map?) ?? const {};
    return TrixView(
      variant: json['variant'] as String,
      phase: json['phase'] as String,
      handNo: asInt(json['handNo']),
      kingdom: asInt(json['kingdom']),
      kingdomOwner: asInt(json['kingdomOwner']),
      contractsLeft: _strings(json['contractsLeft']),
      contract: json['contract'] as String?,
      dealer: asInt(json['dealer']),
      turn: asInt(json['turn']),
      mySeat: asInt(json['mySeat']),
      myHand: _strings(json['myHand']),
      legal: _strings(json['legal']),
      doubleOptions: _strings(json['doubleOptions']),
      doubled: ((json['doubled'] as List?) ?? const []).map((e) => DoubledCard.fromJson(e as Map)).toList(),
      handCounts: _ints(json['handCounts'], const [0, 0, 0, 0]),
      trick: ((json['trick'] as List?) ?? const []).map((e) => Play.fromJson(e as Map)).toList(),
      lastTrick: json['lastTrick'] != null ? LastTrick.fromJson(json['lastTrick'] as Map) : null,
      tricks: _ints(json['tricks'], const [0, 0, 0, 0]),
      handPoints: _ints(json['handPoints'], const [0, 0, 0, 0]),
      layout: {
        for (final s in const ['S', 'H', 'D', 'C'])
          s: layoutRaw[s] == null ? null : TrixPile(low: asInt((layoutRaw[s] as Map)['low']), high: asInt((layoutRaw[s] as Map)['high'])),
      },
      finishOrder: _ints(json['finishOrder'], const []),
      lastPasses: _ints(json['lastPasses'], const []),
      teamScores: _ints(json['teamScores'], const [0, 0]),
      seatScores: _ints(json['seatScores'], const [0, 0, 0, 0]),
      lastResult: json['lastResult'] != null ? TrixResult.fromJson(json['lastResult'] as Map) : null,
      winner: asIntOrNull(json['winner']),
      winnerSeats: _ints(json['winnerSeats'], const []),
    );
  }
}
