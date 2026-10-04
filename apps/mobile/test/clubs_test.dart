import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/screens/clubs_screen.dart';
import 'package:mobile/services/clubs.dart';
import 'package:mobile/theme/samrah_theme.dart';

import 'fake_server.dart';

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
    home: Directionality(textDirection: TextDirection.rtl, child: ClubsScreen(key: UniqueKey())),
  ));
  await _settle(tester);
}

Map<String, dynamic> _card(String id, String name, {String type = 'open', String status = 'active'}) => {
      'id': id,
      'name': name,
      'motto': 'معاً',
      'emblem': 1,
      'color': 2,
      'type': type,
      'status': status,
      'minLevel': 1,
      'members': 3,
      'maxMembers': 30,
      'weekPoints': 42,
      'president': 'سامر',
    };

Map<String, dynamic> _detail({String status = 'active'}) => {
      ..._card('k1', 'صقور الطرنيب', type: 'closed', status: status),
      'members': [
        {'id': 'u1', 'no': 100001, 'name': 'لبنى', 'level': 3, 'online': true, 'role': 'president', 'weekPoints': 30, 'totalPoints': 90, 'joinedAt': 1},
        {'id': 'u2', 'no': 100002, 'name': 'سامر', 'level': 2, 'online': false, 'role': 'member', 'weekPoints': 12, 'totalPoints': 20, 'joinedAt': 2},
      ],
      'myRole': 'president',
      'requested': false,
      'invited': false,
      'requests': [
        {'id': 'u3', 'no': 100003, 'name': 'ريم', 'level': 1, 'online': true},
      ],
      'invites': [],
    };

void main() {
  late FakeServer server;
  Map<String, dynamic> mine = {'club': null, 'invites': [], 'requestedId': null, 'unlockLevel': 1, 'level': 1};
  setUp(() {
    server = FakeServer()..install();
    server.on('GET', '/clubs/mine', (_, _) => mine);
    server.on('GET', '/clubs', (_, _) => [_card('k1', 'صقور الطرنيب', type: 'closed'), _card('k2', 'ديوانية السمر')]);
    server.on('GET', '/clubs-ranking', (_, _) => [_card('k1', 'صقور الطرنيب'), _card('k2', 'ديوانية السمر')]);
    server.on('GET', '/clubs/k1/chat', (_, _) => [
          {'id': 'm1', 'from': null, 'name': 'النادي', 'text': 'أسّس لبنى النادي', 'at': 1759500000000},
          {'id': 'm2', 'from': 'u2', 'name': 'سامر', 'text': 'أهلاً', 'at': 1759500001000},
        ]);
  });

  test('the card and the page read the server\'s club', () {
    final c = ClubDetail(_detail());
    expect(c.memberCount, 2);
    expect(c.myRole, ClubRole.president);
    expect(c.canManage, isTrue);
    expect(c.requests.single.name, 'ريم');
    expect(clubTypeName(c.type), 'مغلق');
    expect(c.emblem, Clubs.emblems[1]);
  });

  test('joining an open club answers joined; a refusal comes back in Arabic', () async {
    server.on('POST', '/clubs/k2/join', (_, _) => {'result': 'joined'});
    final (result, err) = await Clubs.instance.join('k2');
    expect((result, err), ('joined', null));
    final (r2, err2) = await Clubs.instance.join('k9');
    expect(r2, isNull);
    expect(err2, isNotEmpty);
  });

  testWidgets('locked, browsing, waiting for approval and a club of your own lay out at phone and desktop widths', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.reset);
    for (final w in [320.0, 390.0, 1400.0]) {
      mine = {'club': null, 'invites': [], 'requestedId': null, 'unlockLevel': 2, 'level': 1};
      await _show(tester, w);
      expect(find.text('تُفتح عند وصولك إلى المستوى 2'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'locked at $w');

      mine = {'club': null, 'invites': [_card('k3', 'نادي خاص', type: 'private')], 'requestedId': null, 'unlockLevel': 1, 'level': 1};
      await _show(tester, w);
      expect(find.text('نادٍ جديد'), findsOneWidget);
      expect(find.text('ديوانية السمر'), findsOneWidget);
      expect(find.text('دعوة إلى نادي «نادي خاص»'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'browse at $w');

      // the creation dialog, as in the design
      await tester.tap(find.text('نادٍ جديد'));
      await _settle(tester);
      expect(find.text('نادي جديد'), findsOneWidget);
      expect(find.text('نادي مفتوح'), findsOneWidget);
      expect(find.text('نادي مغلق'), findsOneWidget);
      expect(find.text('نادي خاص'), findsOneWidget);
      expect(find.text('قوانين نوادي سمرة'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'create at $w');
      Navigator.of(tester.element(find.text('نادي جديد'))).pop();
      await _settle(tester);

      mine = {'club': _detail(status: 'pending'), 'invites': [], 'requestedId': null, 'unlockLevel': 1, 'level': 1};
      await _show(tester, w);
      expect(find.text('ناديك بانتظار الموافقة'), findsOneWidget);

      mine = {'club': _detail(), 'invites': [], 'requestedId': null, 'unlockLevel': 1, 'level': 1};
      await _show(tester, w);
      expect(find.text('أهلاً'), findsOneWidget);
      for (final tab in ['الأعضاء', 'الترتيب', 'الدردشة']) {
        await tester.tap(find.text(tab));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$tab at $w');
      }
    }
    // the chat poll stops with the page
    await tester.pumpWidget(const SizedBox());
  });
}
