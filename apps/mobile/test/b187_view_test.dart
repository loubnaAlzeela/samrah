// A 187 room's `state.game` is a B187View: RoomView must route it to `b187`
// by variant, keep 5-seat lists intact, and survive msgpack int/double.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_card.dart';
import 'package:mobile/models/room_view.dart';

void main() {
  test('parses a 5-player 187 room', () {
    final v = RoomView.fromJson({
      'code': 'B18701',
      'variant': 'b187',
      'target': 41,
      'status': 'playing',
      'seats': [null, null, null, null, null],
      'mySeat': 4,
      'isOwner': true,
      'ownerSeat': 4,
      'pending': false,
      'turnDeadline': null,
      'serverNow': 0,
      'game': {
        'variant': 'b187',
        'players': 5,
        'phase': 'bidding',
        'handNo': 1,
        'dealer': 2,
        'turn': 4,
        'mySeat': 4,
        'myHand': ['H2', 'S14'],
        'legal': [],
        'minBid': 95.0,
        'giveCount': 0,
        'fieldCount': 5,
        'field': [],
        'bidLog': [
          {'seat': 3, 'bid': 90},
          {'seat': 0, 'bid': 'pass'},
        ],
        'passed': [true, false, false, false, false],
        'highBid': {'seat': 3, 'value': 90},
        'buyer': null,
        'trump': null,
        'handCounts': [7, 7, 7, 7, 7],
        'trick': [],
        'lastTrick': null,
        'tricks': [0, 0, 0, 0, 0],
        'collected': [0, 0, 0, 0, 0],
        'scores': [-87, 40, 0, 12, 35],
        'lastResult': null,
        'winnerSeats': [],
      },
    });

    expect(v.game, isNull);
    expect(v.trix, isNull);
    expect(v.seats, hasLength(5));
    final g = v.b187!;
    expect(g.players, 5);
    expect(g.minBid, 95);
    expect(g.highBid!.value, 90);
    expect(g.lastBidBy(3), 90);
    expect(g.lastBidBy(0), 'pass');
    expect(g.scores, [-87, 40, 0, 12, 35]);
    expect(b187Points('H2'), 25);
    expect(b187Points('D14'), 11);
    expect(b187Points('C9'), 0);
  });

  test('187 hand order: ♥ ♦ ♠ ♣, 2 > A > K > 10 > Q > J, trump first once named', () {
    final hand = ['C6', 'S10', 'H14', 'D2', 'H2', 'H10', 'H13', 'S12', 'H11'];
    List<String> sort(String? t) => sortForDisplay(hand, t, power: b187Power, suitOrder: b187SuitOrder(t));
    expect(sort(null), ['H2', 'H14', 'H13', 'H10', 'H11', 'D2', 'S10', 'S12', 'C6']);
    expect(sort('S'), ['S10', 'S12', 'H2', 'H14', 'H13', 'H10', 'H11', 'D2', 'C6']);
  });

  test('187 redeals parse', () {
    final r = B187Redeal.fromJson({
      'short': [
        {'seat': 2, 'points': 8},
        {'seat': 4, 'points': 11.0},
      ],
    });
    expect(r.short.map((x) => (x.seat, x.points)), [(2, 8), (4, 11)]);
  });
}
