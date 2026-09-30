// Cards are played by dragging them up with the finger: a long drag plays,
// a short one springs back, a card that may not be played does not move,
// and a tap never plays.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/hand_view.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester, {List<String>? legal}) async {
    final played = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: HandView(cards: const ['S14', 'H10'], trump: null, legal: legal ?? const ['S14'], onPlay: played.add),
        ),
      ),
    ));
    return played;
  }

  // two cards are centred in the 378-wide strip, 44 apart: the ace (left) spans x 125..209, the ten 169..253;
  // the ace's visible strip is 125..169
  Offset aceSpot(WidgetTester tester) => tester.getTopLeft(find.byType(HandView)) + const Offset(145, 40);
  Offset tenSpot(WidgetTester tester) => tester.getTopLeft(find.byType(HandView)) + const Offset(230, 40);

  testWidgets('dragging a playable card up plays it', (tester) async {
    final played = await pump(tester);
    await tester.dragFrom(aceSpot(tester), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(played, ['S14']);
  });

  testWidgets('a short drag or a tap does not play', (tester) async {
    final played = await pump(tester);
    await tester.dragFrom(aceSpot(tester), const Offset(0, -30));
    await tester.pumpAndSettle();
    await tester.tapAt(aceSpot(tester));
    await tester.tapAt(aceSpot(tester));
    await tester.pumpAndSettle();
    expect(played, isEmpty);
  });

  testWidgets('a card that may not be played cannot be dragged', (tester) async {
    final played = await pump(tester);
    await tester.dragFrom(tenSpot(tester), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(played, isEmpty);
  });
}
