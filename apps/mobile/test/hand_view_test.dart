// A hand room's `state.game` is a HandGameView: RoomView must route it to
// `hand` by variant; two-deck card codes ("S5a") and jokers ("Xa") must sort
// and survive the msgpack int/double ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_card.dart';
import 'package:mobile/models/room_view.dart';

void main() {
  test('parses a hand room: melds, piles, my turn, round result', () {
    final v = RoomView.fromJson({
      'code': 'HND001',
      'variant': 'hand',
      'target': 41,
      'status': 'playing',
      'seats': [null, null, null],
      'mySeat': 2,
      'isOwner': false,
      'ownerSeat': null,
      'pending': false,
      'turnDeadline': null,
      'serverNow': 0.0,
      'game': {
        'variant': 'hand',
        'players': 3.0,
        'phase': 'playing',
        'handNo': 2,
        'rounds': 5,
        'dealer': 0,
        'turn': 2,
        'mySeat': 2,
        'myHand': ['S5a', 'Xb', 'H14b'],
        'handCounts': [9, 12.0, 3],
        'stockCount': 40,
        'fireTop': 'D9b',
        'fireCount': 4,
        'melds': [
          {
            'id': 3,
            'owner': 1,
            'kind': 'run',
            'cards': [
              {'card': 'H5a', 'rank': 5, 'suit': 'H'},
              {'card': 'Xa', 'rank': 6.0, 'suit': 'H'},
              {'card': 'H7a', 'rank': 7, 'suit': 'H'},
            ],
          },
        ],
        'opened': [false, true, false],
        'openMin': 62,
        'drew': 'fire',
        'fireCard': 'S5a',
        'canUndoFire': true,
        'scores': [-30, 100.0, 12],
        'lastResult': {
          'winner': 0,
          'hand': true,
          'delta': [-60, 200, 24],
          'left': [[], ['S2a'], ['C12b', 'D2a']],
          'opened': [true, false, true],
        },
        'winners': [],
        'trick': [],
      },
    });
    expect(v.game, isNull);
    final g = v.hand!;
    expect(g.players, 3);
    expect(g.melds.single.cards[1].rank, 6);
    expect(g.fireCard, 'S5a');
    expect(g.openMin, 62);
    expect(g.lastResult!.hand, isTrue);
    expect(g.lastResult!.delta, [-60, 200, 24]);
    expect(g.lastResult!.left[2], ['C12b', 'D2a']);
  });

  test('two-deck codes sort by suit then rank, jokers first', () {
    expect(sortForDisplay(['S5a', 'Xb', 'S12b', 'H14a', 'S5b'], null, power: handSortPower), ['Xb', 'S12b', 'S5a', 'S5b', 'H14a']);
  });
}
