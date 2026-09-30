/// What one seat sees in a Baloot game (packages/rules/src/baloot.ts
/// `BalootView`), sent inside `state.game` for the 'baloot' variant. Only the
/// viewer's own hand; the face-up card and declared projects are public.
library;

import 'json_num.dart';
import 'player_view.dart';

bool isBalootVariant(String v) => v == 'baloot';

/// Arabic names of the auction calls. 'pass' reads «بس» in the first round
/// and «ولا» in the second; 'hokm' in the second round is «حكم ثاني».
String balootCallAr(String call, {int round = 1}) => switch (call) {
      'pass' => round == 2 ? 'ولا' : 'بس',
      'sun' => 'صن',
      'hokm' => round == 2 ? 'حكم ثاني' : 'حكم',
      'ashkal' => 'أشكل',
      _ => call,
    };

String balootRaiseAr(String step) => switch (step) {
      'double' => 'دبل',
      'triple' => 'تربل',
      'four' => 'فور',
      'qahwa' => 'قهوة',
      _ => step,
    };

String balootProjectAr(String kind) => switch (kind) {
      'sira' => 'سرا',
      'fifty' => 'خمسين',
      'hundred' => 'مئة',
      'fourHundred' => 'أربعمئة',
      'baloot' => 'بلوت',
      _ => kind,
    };

/// Card strength inside its suit, weakest 0 → strongest 7 (sun order, or the
/// trump order for the trump suit). Used to sort the hand the Baloot way.
int balootRankPower(String card, String? trump) {
  const sun = [7, 8, 9, 11, 12, 13, 10, 14];
  const hokm = [7, 8, 12, 13, 10, 14, 9, 11];
  final r = int.parse(card.substring(1));
  return (trump != null && card[0] == trump ? hokm : sun).indexOf(r);
}

class BalootBid {
  final int seat;
  final String call;
  final String? suit;
  final int round;
  BalootBid({required this.seat, required this.call, required this.suit, required this.round});
  static BalootBid fromJson(Map json) => BalootBid(seat: asInt(json['seat']), call: json['call'] as String, suit: json['suit'] as String?, round: asIntOr(json['round'], 1));
}

class BalootProject {
  final int seat;
  final String kind;

  /// null while hidden (another player's project before the first trick ends)
  final List<String>? cards;

  /// null until the first trick ends
  final bool? counts;
  BalootProject({required this.seat, required this.kind, required this.cards, required this.counts});
  static BalootProject fromJson(Map json) => BalootProject(
        seat: asInt(json['seat']),
        kind: json['kind'] as String,
        cards: (json['cards'] as List?)?.map((e) => e as String).toList(),
        counts: json['counts'] as bool?,
      );
}

class BalootResult {
  final String kind; // scored | redeal
  final String? mode;
  final String? trump;
  final int? buyer;
  final int level;
  final bool qahwa;
  final List<int> abnat;
  final List<int> cardPoints;
  final List<int> projectPoints;
  final List<int> teamDelta;
  final bool success;
  final int? kaboot;
  BalootResult({
    required this.kind,
    required this.mode,
    required this.trump,
    required this.buyer,
    required this.level,
    required this.qahwa,
    required this.abnat,
    required this.cardPoints,
    required this.projectPoints,
    required this.teamDelta,
    required this.success,
    required this.kaboot,
  });

  static List<int> _pair(Object? v) => ((v as List?) ?? const [0, 0]).map(asInt).toList();

  static BalootResult fromJson(Map json) => BalootResult(
        kind: json['kind'] as String,
        mode: json['mode'] as String?,
        trump: json['trump'] as String?,
        buyer: asIntOrNull(json['buyer']),
        level: asIntOr(json['level'], 1),
        qahwa: json['qahwa'] == true,
        abnat: _pair(json['abnat']),
        cardPoints: _pair(json['cardPoints']),
        projectPoints: _pair(json['projectPoints']),
        teamDelta: _pair(json['teamDelta']),
        success: json['success'] == true,
        kaboot: asIntOrNull(json['kaboot']),
      );
}

class BalootView {
  final String phase; // bidding | double | playing | trickDone | handOver | gameOver
  final int handNo;
  final int target;
  final int dealer;
  final int turn;
  final int mySeat;
  final List<String> myHand;
  final List<String> legal;
  final List<int> handCounts;
  final String? flipped;
  final int bidRound;
  final List<BalootBid> bidLog;
  final List<String> callOptions;
  final List<String> hokmSuits;
  final bool confirming;
  final int? hokmCallSeat;
  final String? hokmCallSuit;
  final String? mode; // sun | hokm
  final String? trump;
  final int? buyer;
  final bool ashkal;
  final int? cardTo;
  final int level;
  final bool qahwa;
  final bool closed;
  final String? raiseStep;

  /// The viewer is asked to raise now: which step, and whether the raise
  /// needs the open / closed choice.
  final String? myRaiseStep;
  final bool myRaiseChooseClosed;
  final List<Play> trick;
  final LastTrick? lastTrick;
  final int trickNo;
  final List<int> teamTricks;
  final List<int> abnat;
  final List<BalootProject> projects;
  final List<int> teamScores;
  final BalootResult? lastResult;
  final int? winner;

  BalootView({
    required this.phase,
    required this.handNo,
    required this.target,
    required this.dealer,
    required this.turn,
    required this.mySeat,
    required this.myHand,
    required this.legal,
    required this.handCounts,
    required this.flipped,
    required this.bidRound,
    required this.bidLog,
    required this.callOptions,
    required this.hokmSuits,
    required this.confirming,
    required this.hokmCallSeat,
    required this.hokmCallSuit,
    required this.mode,
    required this.trump,
    required this.buyer,
    required this.ashkal,
    required this.cardTo,
    required this.level,
    required this.qahwa,
    required this.closed,
    required this.raiseStep,
    required this.myRaiseStep,
    required this.myRaiseChooseClosed,
    required this.trick,
    required this.lastTrick,
    required this.trickNo,
    required this.teamTricks,
    required this.abnat,
    required this.projects,
    required this.teamScores,
    required this.lastResult,
    required this.winner,
  });

  static List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e as String).toList();
  static List<int> _ints(Object? v, List<int> fallback) => ((v as List?) ?? fallback).map(asInt).toList();

  static BalootView fromJson(Map json) {
    final hokmCall = json['hokmCall'] as Map?;
    final myRaise = json['myRaise'] as Map?;
    return BalootView(
      phase: json['phase'] as String,
      handNo: asInt(json['handNo']),
      target: asIntOr(json['target'], 152),
      dealer: asInt(json['dealer']),
      turn: asInt(json['turn']),
      mySeat: asInt(json['mySeat']),
      myHand: _strings(json['myHand']),
      legal: _strings(json['legal']),
      handCounts: _ints(json['handCounts'], const [0, 0, 0, 0]),
      flipped: json['flipped'] as String?,
      bidRound: asIntOr(json['bidRound'], 1),
      bidLog: ((json['bidLog'] as List?) ?? const []).map((e) => BalootBid.fromJson(e as Map)).toList(),
      callOptions: _strings(json['callOptions']),
      hokmSuits: _strings(json['hokmSuits']),
      confirming: json['confirming'] == true,
      hokmCallSeat: hokmCall == null ? null : asInt(hokmCall['seat']),
      hokmCallSuit: hokmCall?['suit'] as String?,
      mode: json['mode'] as String?,
      trump: json['trump'] as String?,
      buyer: asIntOrNull(json['buyer']),
      ashkal: json['ashkal'] == true,
      cardTo: asIntOrNull(json['cardTo']),
      level: asIntOr(json['level'], 1),
      qahwa: json['qahwa'] == true,
      closed: json['closed'] == true,
      raiseStep: json['raiseStep'] as String?,
      myRaiseStep: myRaise?['step'] as String?,
      myRaiseChooseClosed: myRaise?['chooseClosed'] == true,
      trick: ((json['trick'] as List?) ?? const []).map((e) => Play.fromJson(e as Map)).toList(),
      lastTrick: json['lastTrick'] != null ? LastTrick.fromJson(json['lastTrick'] as Map) : null,
      trickNo: asIntOr(json['trickNo'], 0),
      teamTricks: _ints(json['teamTricks'], const [0, 0]),
      abnat: _ints(json['abnat'], const [0, 0]),
      projects: ((json['projects'] as List?) ?? const []).map((e) => BalootProject.fromJson(e as Map)).toList(),
      teamScores: _ints(json['teamScores'], const [0, 0]),
      lastResult: json['lastResult'] != null ? BalootResult.fromJson(json['lastResult'] as Map) : null,
      winner: asIntOrNull(json['winner']),
    );
  }
}
