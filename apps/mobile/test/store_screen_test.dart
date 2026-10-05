import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/screens/store_screen.dart';
import 'package:mobile/theme/samrah_theme.dart';

import 'fake_server.dart';

void main() {
  setUp(() => FakeServer().install());

  testWidgets('every store tab builds and lays out at phone and desktop widths', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.reset);
    for (final w in [320.0, 390.0, 600.0, 1400.0]) {
      for (var tab = 0; tab <= StoreScreen.membershipTab; tab++) {
        tester.view.physicalSize = Size(w, 900);
        tester.view.devicePixelRatio = 1;
        // a fresh screen each time, or the tab controller keeps the first tab
        await tester.pumpWidget(MaterialApp(
          theme: SamrahTheme.dark(),
          home: Directionality(textDirection: TextDirection.rtl, child: StoreScreen(key: UniqueKey(), initialTab: tab)),
        ));
        // the cards come in with a short stagger: let every one of them build
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull, reason: 'width $w tab $tab');
      }
    }
  });
}
