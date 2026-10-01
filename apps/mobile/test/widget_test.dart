// Smoke tests: the app boots to the login screen, and a name takes the
// player to the home screen (login/signup are UI-only, no backend yet).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

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
  testWidgets('boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);
    // the logo and wordmark fade in (a delayed start, then the animation's own frames)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('سمرة'), findsOneWidget); // the gold wordmark image
    expect(find.text('اسمك'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('entering a name and continuing reaches the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SamrahApp());
    await _pastSplash(tester);

    await tester.enterText(find.byType(TextField).first, 'سامي');
    await tester.tap(find.text('دخول'));
    // not pumpAndSettle: the home screen's play button breathes forever
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // shown as text, or (the orbit picker's icon-only buttons) as a button label
    expect(_mode('لعبة ودية'), findsWidgets);
    expect(_mode('إنشاء لعبة'), findsWidgets);
  });
}
