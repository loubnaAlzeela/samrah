import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/screens/clubs_screen.dart';
import 'package:mobile/services/clubs.dart';
import 'package:mobile/services/store.dart';
import 'package:mobile/theme/samrah_theme.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _show(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
    theme: SamrahTheme.dark(),
    home: Directionality(textDirection: TextDirection.rtl, child: ClubsScreen(key: UniqueKey(), playerName: 'لبنى')),
  ));
  await _settle(tester);
}

void main() {
  test('an open club takes the player at once; leaving frees them', () {
    final clubs = Clubs.instance..setPlayer('لبنى');
    final open = clubs.all.firstWhere((c) => c.open && !c.full);
    final before = open.members.length;
    expect(clubs.join(open), isNull);
    expect(clubs.myClub, open);
    expect(open.members.length, before + 1);
    expect(clubs.join(clubs.all.firstWhere((c) => c != open)), isNotNull, reason: 'one club at a time');
    clubs.leave();
    expect(clubs.myClub, isNull);
    expect(open.members.length, before);
  });

  test('founding costs units and makes the player president; the next moderator inherits', () {
    final clubs = Clubs.instance;
    final store = Store.instance;
    final before = store.units;
    expect(clubs.create(name: 'ab', motto: '', emblem: Clubs.emblems.first, color: Clubs.colors.first, open: true), isNotNull, reason: 'name too short');
    expect(clubs.create(name: 'نادي الاختبار', motto: 'شعار', emblem: Clubs.emblems.first, color: Clubs.colors.first, open: false), isNull);
    expect(store.units, before - Clubs.createCost);
    expect(clubs.myMember!.role, ClubRole.president);
    final club = clubs.myClub!;
    final who = club.requests.first;
    clubs.accept(who);
    final member = club.members.firstWhere((m) => m.name == who);
    clubs.toggleModerator(member);
    expect(member.role, ClubRole.moderator);
    clubs.leave();
    expect(member.role, ClubRole.president);
    expect(clubs.all, contains(club));
  });

  testWidgets('locked, browsing and a club of your own lay out at phone and desktop widths', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.reset);
    final clubs = Clubs.instance;
    for (final w in [320.0, 390.0, 1400.0]) {
      clubs.demoUnlocked = false;
      await _show(tester, w);
      expect(find.text('جرّبها الآن (نسخة تجريبية)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'locked at $w');

      clubs.unlockDemo();
      await _show(tester, w);
      expect(find.text('أسّس نادياً'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'browse at $w');

      clubs.join(clubs.all.firstWhere((c) => c.open && !c.full));
      await _show(tester, w);
      for (final tab in ['الأعضاء', 'الترتيب', 'الدردشة']) {
        await tester.tap(find.text(tab));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$tab at $w');
      }
      clubs.leave();
    }
    // let the members' delayed chat replies run out
    await tester.pump(const Duration(seconds: 5));
  });
}
