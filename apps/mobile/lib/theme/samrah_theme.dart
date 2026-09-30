// «ديوانية» — Samrah's visual identity. Mirrors design/tokens.css (dark theme,
// the approved default). Brass (#E3A93F) is an ACCENT only: the single primary
// button per screen, the active-turn ring, and key score numbers — never a
// base colour for secondary UI. Everything else is neutral wine/espresso/cream.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/motion.dart';

class SamrahColors {
  SamrahColors._();

  // Theme-independent: table + cards are physical objects, same in any theme.
  static const tableCenter = Color(0xFF7A2A36);
  static const tableMid = Color(0xFF5B1C27);
  static const tableEdge = Color(0xFF3E1219);
  static const tableRim = Color(0xFF8F8272);
  static const onTable = Color(0xFFF5EBDD);
  static const onTableMuted = Color(0xFFE4D3BC);
  static const onTableAccent = Color(0xFFE3A93F);

  static const cardFace = Color(0xFFFBF4E6);
  static const cardEdge = Color(0xFFE3D3B4);
  static const cardBack = Color(0xFF6E1A28);
  static const cardBackStar = Color(0xFFC9A24E);
  static const cardVeil = Color(0x661A1210); // non-playable dim

  static const suitRed = Color(0xFFB3261E); // قلب / ديناري
  static const suitBlack = Color(0xFF1F1A17); // بستوني / سباتي

  // Dark shell («سهرة») — the default.
  static const bg = Color(0xFF17110F);
  static const surface = Color(0xFF221A17);
  static const surface2 = Color(0xFF2C231F);
  static const surface3 = Color(0xFF362B26);
  static const scorebox = Color(0xFF0F0B0A);
  static const line = Color(0xFF3D322C);
  static const fieldBorder = Color(0xFF7A6858);
  static const text = Color(0xFFF2E9DC);
  static const textMuted = Color(0xFFB9AC9A);
  static const icon = Color(0xFF8F8272);
  static const selectedBg = Color(0xFFF2E9DC);
  static const onSelected = Color(0xFF1A1210);
  static const disabledText = Color(0xFF6E6258);
  static const statusOpen = Color(0xFF7FBF8E);

  static const accent = Color(0xFFE3A93F); // brass — primary action / turn ring / key scores only
  static const onAccent = Color(0xFF1A1210);
  static const turnRing = Color(0xFFE3A93F);

  static const online = Color(0xFF2FB36B);
  static const panel = Color(0xF017110F); // 94% opaque espresso, for panels over the table

  // Seats around the table (design/layout-v2.md): name capsule + avatar ring.
  static const pillBg = Color(0xFF17110F);
  static const pillBorder = Color(0xFF8F8272);
  static const avatarBg = Color(0xFF3A2F29);
  static const avatarRing = Color(0xFF8F8272);
}

class SamrahTheme {
  SamrahTheme._();

  static ThemeData dark() {
    final uiText = GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme);
    final displayText = GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme);

    final base = ThemeData(
      brightness: Brightness.dark,
      // Cairo everywhere: a plain, highly legible Arabic face (owner asked to drop the decorative Kufi)
      fontFamily: GoogleFonts.cairo().fontFamily,
      scaffoldBackgroundColor: SamrahColors.bg,
      // every page change fades and rises (lib/widgets/motion.dart)
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
      }),
      colorScheme: const ColorScheme.dark(
        surface: SamrahColors.surface,
        primary: SamrahColors.accent,
        onPrimary: SamrahColors.onAccent,
        secondary: SamrahColors.accent,
        error: SamrahColors.suitRed,
      ),
      textTheme: uiText.copyWith(
        headlineSmall: displayText.headlineSmall,
        titleLarge: displayText.titleLarge,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SamrahColors.bg,
        foregroundColor: SamrahColors.text,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SamrahColors.accent,
          foregroundColor: SamrahColors.onAccent,
          disabledBackgroundColor: SamrahColors.surface2,
          disabledForegroundColor: SamrahColors.disabledText,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SamrahColors.text,
          side: const BorderSide(color: SamrahColors.fieldBorder),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SamrahColors.surface2,
        labelStyle: const TextStyle(color: SamrahColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SamrahColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SamrahColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SamrahColors.accent, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SamrahColors.surface2,
        labelStyle: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600),
        side: const BorderSide(color: SamrahColors.line),
        shape: const StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        color: SamrahColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: SamrahColors.line),
        ),
      ),
      dividerColor: SamrahColors.line,
    );
    return base;
  }
}
