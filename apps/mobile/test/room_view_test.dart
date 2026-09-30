// RoomView/PlayerView.fromJson is the one place that turns the server's
// wire JSON into what the screens read (state filtering already happened
// server-side; this is the client-side message transformation) — worth a
// direct test against a realistic payload shape.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/room_view.dart';

void main() {
  test('parses a full RoomView during play, including nested game fields', () {
    final json = {
      'code': 'ABC123',
      'variant': 'tarneeb',
      'target': 41,
      'status': 'playing',
      'seats': [
        {'name': 'لاعب', 'connected': true, 'heldMsLeft': null, 'auto': false, 'bot': false, 'level': 1},
        {'name': 'سالم', 'connected': true, 'heldMsLeft': null, 'auto': false, 'bot': true, 'level': 1},
        null,
        {'name': 'نور', 'connected': false, 'heldMsLeft': 4200, 'auto': true, 'bot': false, 'level': 1},
      ],
      'mySeat': 0,
      'isOwner': true,
      'ownerSeat': 0,
      'partnerChooser': 0,
      'pending': false,
      'kickQueued': [],
      'turnDeadline': 1000,
      'serverNow': 400,
      'settings': {'visibility': 'private', 'chat': true, 'kick': false, 'noLeave': false, 'speed': 'normal', 'target': 41, 'minLevel': 1, 'voice': false},
      'game': {
        'variant': 'tarneeb',
        'target': 41,
        'phase': 'playing',
        'handNo': 1,
        'dealer': 3,
        'turn': 0,
        'mySeat': 0,
        'myHand': ['H14', 'S2'],
        'legal': ['H14'],
        'minBid': null,
        'handCounts': [2, 13, 13, 13],
        'bidLog': [
          {'seat': 1, 'bid': 7},
          {'seat': 2, 'bid': 'pass'},
        ],
        'passed': [false, false, true, false],
        'highBid': {'seat': 1, 'value': 7},
        'seatBids': [null, null, null, null],
        'trump': 'H',
        'revealed': null,
        'trick': [
          {'seat': 3, 'card': 'D5'},
        ],
        'lastTrick': null,
        'tricks': [0, 0, 0, 1],
        'teamScores': [0, 5],
        'seatScores': [0, 0, 0, 0],
        'lastResult': null,
        'winner': null,
      },
    };

    final v = RoomView.fromJson(json);
    expect(v.code, 'ABC123');
    expect(v.status, 'playing');
    expect(v.seats.length, 4);
    expect(v.seats[2], isNull);
    expect(v.seats[1]!.bot, isTrue);
    expect(v.seats[3]!.connected, isFalse);
    expect(v.seats[3]!.heldMsLeft, 4200);
    expect(v.mySeat, 0);
    expect(v.isOwner, isTrue);

    final g = v.game!;
    expect(g.phase, 'playing');
    expect(g.myHand, ['H14', 'S2']);
    expect(g.legal, ['H14']);
    expect(g.trump, 'H');
    expect(g.highBid!.seat, 1);
    expect(g.highBid!.value, 7);
    expect(g.trick.single.card, 'D5');
    expect(g.teamScores, [0, 5]);
    expect(g.lastBidBy(1), 7);
    expect(g.lastBidBy(2), 'pass');
    expect(g.lastBidBy(3), isNull);
  });

  test('parses a hand-over result and a null game (no seat yet)', () {
    final scored = HandResult.fromJson({
      'kind': 'scored',
      'note': 'clean',
      'bidder': 1,
      'bid': 8,
      'bidderTricks': 9,
      'teamDelta': [10, -10],
      'seatDelta': [0, 0, 0, 0],
    });
    expect(scored.kind, 'scored');
    expect(scored.teamDelta, [10, -10]);

    final v = RoomView.fromJson({
      'code': 'XYZ999',
      'variant': 'tarneeb',
      'target': 41,
      'status': 'playing',
      'seats': [null, null, null, null],
      'mySeat': null,
      'isOwner': false,
      'ownerSeat': null,
      'partnerChooser': null,
      'pending': true,
      'kickQueued': [],
      'turnDeadline': null,
      'serverNow': 0,
      'settings': {},
      'game': null,
    });
    expect(v.mySeat, isNull);
    expect(v.game, isNull);
    expect(v.pending, isTrue);
  });
}
