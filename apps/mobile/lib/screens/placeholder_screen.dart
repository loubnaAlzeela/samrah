// Generic "قريباً" screen for tabs with no backend yet (المتجر، الأندية،
// التحديات) — see design/layout-v3.md §9: "شكل بس بهالمرحلة".
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  IconData get _icon => switch (title) {
        'المتجر' => Icons.storefront_outlined,
        'الأندية' => Icons.shield_outlined,
        'التحديات' => Icons.flag_outlined,
        _ => Icons.hourglass_empty,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: GoogleFonts.cairo(fontSize: 20))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
              child: Icon(_icon, size: 44, color: SamrahColors.icon),
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.cairo(fontSize: 24, color: SamrahColors.text)),
            const SizedBox(height: 8),
            const Text('قريباً', style: TextStyle(color: SamrahColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
