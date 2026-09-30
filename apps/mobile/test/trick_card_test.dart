// A thrown card flies from the player's seat to its place in the trick, and
// once the trick is decided it slides to the winner and fades out.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/playing_card_view.dart';
import 'package:mobile/widgets/trick_card.dart';

void main() {
  Widget table({Offset? collectTo}) => MaterialApp(
        home: SizedBox(
          width: 390,
          height: 793,
          child: Stack(children: [
            TrickCard(key: const ValueKey('S14'), code: 'S14', from: const Offset(346, 326), to: const Offset(243, 322), width: 58, collectTo: collectTo),
          ]),
        ),
      );

  Offset cardCentre(WidgetTester tester) => tester.getCenter(find.byType(PlayingCardView));

  testWidgets('flies in from the seat and settles in its place', (tester) async {
    await tester.pumpWidget(table());
    final start = cardCentre(tester);
    expect(start.dx, greaterThan(300)); // still near the seat on the right
    await tester.pumpAndSettle();
    expect(cardCentre(tester).dx, closeTo(243, 1));
    expect(cardCentre(tester).dy, closeTo(322, 1));
  });

  testWidgets('a decided trick slides to the winner and fades', (tester) async {
    await tester.pumpWidget(table());
    await tester.pumpAndSettle();
    await tester.pumpWidget(table(collectTo: const Offset(195, 118)));
    await tester.pump(TrickCard.collectDelay);
    await tester.pumpAndSettle();
    expect(cardCentre(tester).dy, closeTo(118, 1));
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.byType(PlayingCardView), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 0);
  });
}
