import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/competitions.dart';

void main() {
  test('75% of the seats are needed to start', () {
    expect({for (final s in CompRules.seatOptions) s: CompRules.minToStart(s)}, {2: 2, 4: 3, 8: 6, 16: 12, 32: 24});
  });

  test('a cancelled competition costs the organiser 300 per seat', () {
    expect([for (final s in CompRules.seatOptions) CompRules.cancelPenalty(s)], [600, 1200, 2400, 4800, 9600]);
  });

  test('the commission is 10% of the prize or 300 per seat, whichever is larger', () {
    expect(CompRules.commission(2000, 8), 2400); // 200 < 2400
    expect(CompRules.commission(50000, 4), 5000); // 5000 > 1200
    expect(CompRules.creationCost(2000, 8), 4400);
  });

  test('the organiser gets 90% of the entry fees; partners split the prize', () {
    expect(CompRules.organiserShare(100, 8), 720);
    expect(CompRules.prizePerPlayer(2000, true), 1000);
    expect(CompRules.prizePerPlayer(2000, false), 2000);
  });

  test('solo games play tables of four and need at least one full table', () {
    final trix = Competitions.games.firstWhere((g) => g.variant == 'trix');
    expect(trix.partnership, isFalse);
    expect(trix.tableSize, 4);
    expect(trix.advance, 2);
    expect(trix.seatOptions, [4, 8, 16, 32]);
    expect(trix.targets, isEmpty);
    final tarneeb = Competitions.games.first;
    expect(tarneeb.seatOptions, [2, 4, 8, 16, 32]);
  });

  test("a competition reads the server's view", () {
    final c = Competition({
      'id': 'c1',
      'title': 'كأس الخميس',
      'variant': 'tarneeb',
      'seats': 4,
      'fee': 100,
      'prize': 1000,
      'target': 41,
      'organiser': {'id': 'u9', 'no': 100009, 'name': 'سامر', 'rating': 15},
      'mine': false,
      'deadline': 1759500000000,
      'autoAccept': true,
      'phase': 'running',
      'entrants': [
        {'id': 'e1', 'name': 'لبنى و ريم', 'userIds': ['u1', 'u2']},
        {'id': 'e2', 'name': 'خالد و نور', 'userIds': ['u3', 'u4']},
        {'id': 'e3', 'name': 'هادي و لين', 'userIds': ['u5', 'u6']},
      ],
      'requests': [],
      'requestCount': 0,
      'myEntry': {'id': 'e1', 'name': 'لبنى و ريم'},
      'myRequest': null,
      'rounds': [
        ['لبنى و ريم', 'خالد و نور', null, 'هادي و لين'],
      ],
      'myMatch': {'room': 'ABC234', 'status': 'playing', 'round': 0},
      'winner': null,
      'reviewEndsAt': null,
      'complaints': [],
      'clear': [],
      'note': null,
    });
    expect(c.game.partnership, isTrue);
    expect(c.phase, CompPhase.running);
    expect(c.entrants, hasLength(3));
    expect(c.canStart, isTrue); // 3 of 4
    expect(c.joined, isTrue);
    expect(c.myMatchRoom, 'ABC234');
    expect(c.rounds.single[2], isNull);
    expect(c.organiserRating, 15);
  });
}
