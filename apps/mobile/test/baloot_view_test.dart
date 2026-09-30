// A baloot room's `state.game` is a BalootView: RoomView must route it to
// `baloot` by variant, and every field (auction, raise offer, projects,
// results) must survive the msgpack int/double ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_card.dart';
import 'package:mobile/models/room_view.dart';

void main() {
  Map<String, Object?> room(Map<String, Object?> game) => {
        'code': 'BLT001',
        'variant': 'baloot',
        'target': 41,
        'status': 'playing',
        'seats': [null, null, null, null],
        'mySeat': 1,
        'isOwner': false,
        'ownerSeat': null,
        'pending': false,
        'turnDeadline': null,
        'serverNow': 0.0,
        'game': game,
      };

  test('parses the auction: face-up card, calls, my options', () {
    final v = RoomView.fromJson(room({
      'variant': 'baloot',
      'phase': 'bidding',
      'handNo': 1.0,
      'target': 152.0,
      'dealer': 3,
      'turn': 1,
      'mySeat': 1,
      'myHand': ['S14', 'H10', 'D7', 'C11', 'C9'],
      'legal': [],
      'handCounts': [5, 5, 5, 5],
      'flipped': 'H13',
      'bidRound': 1,
      'bidLog': [
        {'seat': 0, 'call': 'hokm', 'suit': 'H', 'round': 1.0},
      ],
      'callOptions': ['pass', 'sun'],
      'hokmSuits': [],
      'confirming': false,
      'hokmCall': {'seat': 0.0, 'suit': 'H'},
      'mode': null,
      'trump': null,
      'buyer': null,
      'ashkal': false,
      'cardTo': null,
      'level': 1,
      'qahwa': false,
      'closed': false,
      'raiseStep': null,
      'myRaise': null,
      'trick': [],
      'lastTrick': null,
      'trickNo': 0,
      'teamTricks': [0, 0],
      'abnat': [0, 0],
      'projects': [],
      'teamScores': [40.0, 12],
      'lastResult': null,
      'winner': null,
    }));
    expect(v.game, isNull);
    expect(v.trix, isNull);
    final g = v.baloot!;
    expect(g.flipped, 'H13');
    expect(g.hokmCallSeat, 0);
    expect(g.hokmCallSuit, 'H');
    expect(g.bidLog.single.suit, 'H');
    expect(g.callOptions, ['pass', 'sun']);
    expect(g.teamScores, [40, 12]);
    expect(balootCallAr('pass', round: 2), 'ولا');
    expect(balootCallAr('hokm', round: 2), 'حكم ثاني');
  });

  test('parses play: raise offer, projects (hidden and shown), round result', () {
    final g = RoomView.fromJson(room({
      'variant': 'baloot',
      'phase': 'double',
      'handNo': 4,
      'target': 152,
      'dealer': 0,
      'turn': 1,
      'mySeat': 1,
      'myHand': ['S14', 'S13', 'S12', 'H10', 'D7', 'C11', 'C9', 'C8'],
      'legal': [],
      'handCounts': [8, 8, 8, 8],
      'flipped': null,
      'bidRound': 1,
      'bidLog': [],
      'callOptions': [],
      'hokmSuits': [],
      'confirming': false,
      'hokmCall': null,
      'mode': 'hokm',
      'trump': 'C',
      'buyer': 0,
      'ashkal': false,
      'cardTo': 0,
      'level': 2.0,
      'qahwa': false,
      'closed': true,
      'raiseStep': 'four',
      'myRaise': {'step': 'four', 'chooseClosed': true},
      'trick': [],
      'lastTrick': null,
      'trickNo': 0,
      'teamTricks': [0, 0],
      'abnat': [0, 0],
      'projects': [
        {'seat': 1, 'kind': 'sira', 'cards': ['S14', 'S13', 'S12'], 'counts': null},
        {'seat': 2, 'kind': 'fifty', 'cards': null, 'counts': null},
      ],
      'teamScores': [0, 0],
      'lastResult': {
        'kind': 'scored',
        'mode': 'sun',
        'trump': null,
        'buyer': 3.0,
        'level': 1,
        'qahwa': false,
        'abnat': [70, 60],
        'cardPoints': [14, 12],
        'projectPoints': [4.0, 0],
        'teamDelta': [18, 12],
        'success': true,
        'kaboot': null,
      },
      'winner': null,
    })).baloot!;
    expect(g.level, 2);
    expect(g.closed, isTrue);
    expect(g.myRaiseStep, 'four');
    expect(g.myRaiseChooseClosed, isTrue);
    expect(g.projects.first.cards, ['S14', 'S13', 'S12']);
    expect(g.projects.last.cards, isNull);
    expect(g.lastResult!.buyer, 3);
    expect(g.lastResult!.teamDelta, [18, 12]);
    expect(balootProjectAr(g.projects.last.kind), 'خمسين');
  });

  test('hand sort follows Baloot strength: 10 above K, trump J and 9 on top', () {
    expect(sortForDisplay(['S13', 'S10', 'S14', 'S11'], null, power: (c) => balootRankPower(c, null)), ['S14', 'S10', 'S13', 'S11']);
    expect(sortForDisplay(['H14', 'H9', 'H11', 'H10'], 'H', power: (c) => balootRankPower(c, 'H')), ['H11', 'H9', 'H14', 'H10']);
  });
}
