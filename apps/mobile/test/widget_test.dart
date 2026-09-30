// Smoke tests: the app boots to the login screen, and a name takes the
// player to the home screen (login/signup are UI-only, no backend yet).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    // the logo and wordmark fade in (a delayed start, then the animation's own frames)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('سمرة'), findsOneWidget); // the gold wordmark image
    expect(find.text('اسمك'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('entering a name and continuing reaches the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());

    await tester.enterText(find.byType(TextField).first, 'سامي');
    await tester.tap(find.text('دخول'));
    // not pumpAndSettle: the home screen's play button breathes forever
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('لعبة ودية'), findsOneWidget);
    expect(find.text('إنشاء لعبة'), findsOneWidget);
  });
}
