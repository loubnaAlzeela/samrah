// Smoke tests: the app boots to the way in (Google, no email or guest), and a failed sign-in leaves the buttons
// usable. Signing in itself is the Google / Apple SDK's, so the server-side half is tested in apps/server.
// (The server is a fake here, see fake_server.dart.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/account.dart';

import 'fake_server.dart';

/// The opening scene plays first; a tap skips it.
Future<void> _pastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(const Offset(10, 10));
  await tester.pump(const Duration(milliseconds: 700));
  // the login's parts come in on their own delays
  await tester.pump(const Duration(seconds: 1));
}

/// A home-screen mode, whether written out or named only in its button's semantics.
Finder _mode(String label) => find.byWidgetPredicate(
      (w) => (w is Text && w.data == label) || (w is Semantics && (w.properties.label ?? '').contains(label)),
    );

void main() {
  late FakeServer server;
  setUp(() {
    server = FakeServer()..install();
    Account.instance.setForTest(null);
    server.on('GET', '/me', (_, _) => meJson());
    server.on('GET', '/challenges', (_, _) => []);
    server.on('GET', '/clubs/mine', (_, _) => {'club': null, 'invites': [], 'requestedId': null, 'unlockLevel': 1, 'level': 1});
  });

  testWidgets('boots to the way in: Google only, no guest start and no email fields', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('سمرة'), findsOneWidget); // the gold wordmark image
    expect(find.text('المتابعة بحساب Google'), findsOneWidget);
    expect(find.text('المتابعة بحساب Apple'), findsNothing); // iPhone only
    expect(find.byType(TextField), findsNothing);
    expect(find.text('ابدأ اللعب'), findsNothing);
    expect(find.text('شروط الاستخدام'), findsOneWidget);
    expect(server.calls, isEmpty);
  });

  testWidgets('a signed-in player goes straight to the home screen', (WidgetTester tester) async {
    server.on('GET', '/me', (_, _) => meJson(name: 'سامي'));
    Account.instance.setForTest(meJson(name: 'سامي'));
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(_mode('لعبة ودية'), findsWidgets);
    expect(_mode('إنشاء لعبة'), findsWidgets);
    expect(find.text('سامي'), findsWidgets);
    // the home screen's timers stop with it, and the account's refresh
    await tester.pumpWidget(const SizedBox());
    Account.instance.stop();
  });
}
