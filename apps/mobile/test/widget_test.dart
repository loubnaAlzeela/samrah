// Smoke tests: the app boots to the way in, and a new player's name creates an account and reaches the home
// screen (the server is a fake here, see fake_server.dart).
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
    var name = 'لبنى';
    server.on('POST', '/auth/guest', (body, _) {
      name = body['name'] as String;
      return {'token': 'session-token-1', 'me': meJson(name: name)};
    });
    server.on('GET', '/me', (_, _) => meJson(name: name));
    server.on('GET', '/challenges', (_, _) => []);
    server.on('GET', '/clubs/mine', (_, _) => {'club': null, 'invites': [], 'requestedId': null, 'unlockLevel': 1, 'level': 1});
  });

  testWidgets('boots to the way in', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('سمرة'), findsOneWidget); // the gold wordmark image
    expect(find.text('اسمك في اللعبة'), findsOneWidget);
    expect(find.text('ابدأ اللعب'), findsOneWidget);
  });

  testWidgets('a new player\'s name creates the account and reaches the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);

    await tester.enterText(find.byType(TextField).first, 'سامي');
    await tester.tap(find.text('ابدأ اللعب'));
    // not pumpAndSettle: the home screen's play button breathes forever
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(server.calls, contains('POST /auth/guest'));
    expect(Account.instance.me?.name, 'سامي');
    expect(_mode('لعبة ودية'), findsWidgets);
    expect(_mode('إنشاء لعبة'), findsWidgets);
    expect(find.text('سامي'), findsWidgets);
    // the home screen's timers stop with it, and the account's refresh
    await tester.pumpWidget(const SizedBox());
    Account.instance.stop();
  });
}
