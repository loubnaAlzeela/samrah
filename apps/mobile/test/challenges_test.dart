import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/screens/challenges_screen.dart';
import 'package:mobile/services/challenges.dart';
import 'package:mobile/services/store.dart';
import 'package:mobile/theme/samrah_theme.dart';

void main() {
  test('claiming a finished challenge pays its stars once', () {
    final ch = Challenges.instance;
    final store = Store.instance;
    final c = ch.daily.firstWhere((c) => c.claimable);
    final before = store.stars;
    final waiting = ch.claimableCount;
    ch.claim(c);
    expect(store.stars, before + c.reward);
    expect(ch.claimableCount, waiting - 1);
    ch.claim(c);
    expect(store.stars, before + c.reward);
  });

  test('an unfinished challenge cannot be claimed', () {
    final c = Challenges.instance.weekly.firstWhere((c) => !c.done);
    final before = Store.instance.stars;
    Challenges.instance.claim(c);
    expect(Store.instance.stars, before);
    expect(c.claimed, isFalse);
  });

  test('daily tasks reset at midnight, weekly ones on Saturday', () {
    final thursday = DateTime(2026, 10, 1, 15, 30);
    expect(Challenges.nextDailyReset(thursday), DateTime(2026, 10, 2));
    expect(Challenges.nextWeeklyReset(thursday), DateTime(2026, 10, 3));
    final saturday = DateTime(2026, 10, 3, 9);
    expect(Challenges.nextWeeklyReset(saturday), DateTime(2026, 10, 10));
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
