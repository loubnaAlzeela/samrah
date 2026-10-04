import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/screens/challenges_screen.dart';
import 'package:mobile/services/account.dart';
import 'package:mobile/services/challenges.dart';
import 'package:mobile/theme/samrah_theme.dart';

import 'fake_server.dart';

List<Map<String, dynamic>> _list({bool claimed = false}) => [
      {'id': 'd-play3', 'period': 'day', 'title': 'العب 3 جولات من أي لعبة', 'icon': 'style', 'goal': 3, 'reward': 5, 'game': null, 'progress': 3, 'claimed': claimed},
      {'id': 'd-win1', 'period': 'day', 'title': 'افز بجولة', 'icon': 'target', 'goal': 1, 'reward': 6, 'game': null, 'progress': 0, 'claimed': false},
      {'id': 'w-play25', 'period': 'week', 'title': 'العب 25 جولة', 'icon': 'style', 'goal': 25, 'reward': 30, 'game': null, 'progress': 17, 'claimed': false},
    ];

void main() {
  late FakeServer server;
  setUp(() {
    server = FakeServer()..install();
    var claimed = false;
    server.on('GET', '/challenges', (_, _) => _list(claimed: claimed));
    server.on('POST', '/challenges/d-play3/claim', (_, _) {
      claimed = true;
      return {'challenges': _list(claimed: true), 'me': meJson(stars: 405)};
    });
  });

  test('the server list splits into daily and weekly; claiming pays and updates the wallet', () async {
    final ch = Challenges.instance;
    await ch.load();
    expect(ch.daily.map((c) => c.id), ['d-play3', 'd-win1']);
    expect(ch.weekly.single.progress, 17);
    expect(ch.claimableCount, 1);
    expect(await ch.claim(ch.daily.first), isNull);
    expect(ch.claimableCount, 0);
    expect(Account.instance.me!.stars, 405);
    // an unfinished one is not even sent
    expect(await ch.claim(ch.daily[1]), isNull);
    expect(server.calls.where((c) => c.contains('d-win1')), isEmpty);
  });

  test('daily tasks reset at midnight in the Gulf, weekly ones on Saturday', () {
    // Thursday 2026-10-01 15:30 UTC+3
    final thursday = DateTime.utc(2026, 10, 1, 12, 30);
    expect(Challenges.nextDailyReset(thursday).toUtc(), DateTime.utc(2026, 10, 1, 21));
    expect(Challenges.nextWeeklyReset(thursday).toUtc(), DateTime.utc(2026, 10, 2, 21));
    final saturday = DateTime.utc(2026, 10, 3, 6);
    expect(Challenges.nextWeeklyReset(saturday).toUtc(), DateTime.utc(2026, 10, 9, 21));
  });

  testWidgets('both lists lay out at phone and desktop widths', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.reset);
    for (final w in [320.0, 390.0, 1400.0]) {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        theme: SamrahTheme.dark(),
        home: Directionality(textDirection: TextDirection.rtl, child: ChallengesScreen(key: UniqueKey())),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('الأسبوع'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull, reason: 'width $w');
    }
    // the screen's countdown timer stops with it
    await tester.pumpWidget(const SizedBox());
  });
}
