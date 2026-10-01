// A trix room's `state.game` is a TrixView, not a PlayerView: RoomView must
// route it to `trix` by variant, and every field (layout, doubled cards,
// results) must survive the msgpack int/double ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/room_view.dart';

void main() {
  test('parses a trix room: layout, doubled cards, contracts left', () {
    final v = RoomView.fromJson({
      'code': 'TRX001',
      'variant': 'trixPartners',
      'target': 41,
      'status': 'playing',
      'seats': [null, null, null, null],
      'mySeat': 2,
      'isOwner': false,
      'ownerSeat': null,
      'pending': false,
      'turnDeadline': null,
      'serverNow': 0.0,
      'game': {
        'variant': 'trixPartners',
        'phase': 'playing',
        'handNo': 7.0,
        'kingdom': 1,
        'kingdomOwner': 3,
        'contractsLeft': ['queens', 'trix'],
        'contract': 'trix',
        'dealer': 2,
        'turn': 2,
        'mySeat': 2,
        'myHand': ['S12', 'H3'],
        'legal': ['S12'],
        'doubleOptions': [],
        'doubled': [
          {'card': 'H13', 'seat': 1},
        ],
        'handCounts': [5, 6, 2, 7],
        'trick': [],
        'lastTrick': null,
        'tricks': [0, 0, 0, 0],
        'handPoints': [0, 0, 0, 0],
        'layout': {
          'S': {'low': 9, 'high': 11},
          'H': null,
          'D': {'low': 11.0, 'high': 13.0},
          'C': null,
        },
        'finishOrder': [0],
        'lastPasses': [1],
        'teamScores': [120, -80],
        'seatScores': [200, -40, -80, -40],
        'lastResult': {
          'contract': 'king',
          'kingdomOwner': 3,
          'seatDelta': [0, 75, -150, 0],
          'teamDelta': [-150, 75],
          'finishOrder': [],
        },
        'winner': null,
        'winnerSeats': [],
      },
    });

    expect(v.game, isNull);
    final g = v.trix!;
    expect(g.partners, isTrue);
    expect(g.contract, 'trix');
    expect(g.contractsLeft, ['queens', 'trix']);
    expect(g.layout['S']!.low, 9);
    expect(g.layout['D']!.high, 13);
    expect(g.layout['H'], isNull);
    expect(g.doubled.single.card, 'H13');
    expect(g.lastPasses, [1]);
    expect(g.lastResult!.seatDelta, [0, 75, -150, 0]);
    expect(contractNameAr('king'), 'شيخ الكبة');
  });

  test('trix complex: two contracts per kingdom, partners variant scores by team', () {
    expect(isTrixVariant('trixComplex'), isTrue);
    expect(isTrixVariant('trixComplexPartners'), isTrue);
    expect(trixContractsOf('trixComplex'), ['complex', 'trix']);
    expect(trixContractsOf('trixPartners'), ['king', 'queens', 'diamonds', 'tricks', 'trix']);
    expect(contractNameAr('complex'), 'كمبلكس');
  });
}
