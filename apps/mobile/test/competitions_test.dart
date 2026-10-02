import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/competitions.dart';
import 'package:mobile/services/store.dart';

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

  test('creating needs membership and takes prize plus commission', () {
    final comps = Competitions.instance;
    final store = Store.instance;
    final game = Competitions.games.first;
    final (none, err) = comps.create(title: 'x', game: game, seats: 4, fee: 100, prize: 1000, target: 41);
    expect(none, isNull);
    expect(err, isNotNull);

    store.stars = Store.vipPrice;
    expect(store.buyVip(), isTrue);
    final before = store.units;
    final (c, err2) = comps.create(title: 'كأسي', game: game, seats: 4, fee: 100, prize: 1000, target: 41);
    expect(err2, isNull);
    expect(store.units, before - 1000 - 1200);

    // cancelling refunds everything except 300 per seat
    comps.cancel(c!);
    expect(c.phase, CompPhase.cancelled);
    expect(store.units, before - 1200);
  });

  test('joining pays the fee, leaving refunds it', () {
    final comps = Competitions.instance;
    final store = Store.instance;
    final c = comps.all.firstWhere((c) => !c.mine && c.phase == CompPhase.registering && c.fee > 0 && !c.full);
    final before = store.units;
    expect(comps.join(c, partner: 'سامي'), isNull);
    expect(store.units, before - c.fee);
    expect(c.myRequest, contains('سامي'));
    comps.leave(c);
    expect(store.units, before);
  });
}
