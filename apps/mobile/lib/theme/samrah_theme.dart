// «ديوانية» — Samrah's visual identity. Mirrors design/tokens.css (dark theme,
// the approved default). Orange (#FA8112) is an ACCENT only: the single primary
// button per screen, the active-turn ring, and key score numbers — never a
// base colour for secondary UI. Everything else is neutral wine/espresso/cream.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/motion.dart';

class SamrahColors {
  SamrahColors._();

  // Theme-independent: table + cards are physical objects, same in any theme.
  static const tableCenter = Color(0xFFF9E6A8);
  static const tableMid = Color(0xFFF0D88E);
  static const tableEdge = Color(0xFFE0C474);
  static const tableRim = Color(0xFFFA8112);
  static const onTable = Color(0xFFFAF3E1);
  static const onTableMuted = Color(0xFFF5E7C6);
  // text drawn straight on the (light) felt, not on a dark pill
  static const onFelt = Color(0xFF222222);
  static const onFeltMuted = Color(0xFF5A4F36);
  static const onFeltAccent = Color(0xFFB85600);
  static const onTableAccent = Color(0xFFFA8112);

  static const cardFace = Color(0xFFFAF3E1);
  static const cardEdge = Color(0xFFE0CFA6);
  static const cardBack = Color(0xFFC8650C);
  static const cardBackStar = Color(0xFFFAF3E1);
  static const cardVeil = Color(0x33222222); // non-playable dim (light: the card stays readable)

  static const suitRed = Color(0xFFB3261E); // قلب / ديناري
  static const suitBlack = Color(0xFF1F1A17); // بستوني / سباتي

  // Dark shell («سهرة») — the default. Lighter than it first was, so screens read as a
  // warm evening rather than near-black; screens sit on [SamrahBackdrop] (lit in the middle).
  static const bg = Color(0xFF222222);
  static const surface = Color(0xFF2C2C2C);
  static const surface2 = Color(0xFF363636);
  static const surface3 = Color(0xFF424242);
  static const scorebox = Color(0xFF151515);
  static const line = Color(0xFF4C4C4C);
  static const fieldBorder = Color(0xFF7A7466);
  static const text = Color(0xFFFAF3E1);
  static const textMuted = Color(0xFFB8AF9C);
  static const icon = Color(0xFFF5E7C6);
  static const selectedBg = Color(0xFFFAF3E1);
  static const onSelected = Color(0xFF222222);
  static const disabledText = Color(0xFF77716A);
  static const statusOpen = Color(0xFF7FBF8E);

  static const accent = Color(0xFFFA8112); // orange — primary action / turn ring / key scores only
  static const onAccent = Color(0xFF222222);
  static const turnRing = Color(0xFFFA8112);

  static const online = Color(0xFF2FB36B);
  static const panel = Color(0xF0222222); // 94% opaque burgundy, for panels over the table

  // Seats around the table (design/layout-v2.md): name capsule + avatar ring.
  static const pillBg = Color(0xFF222222);
  static const pillBorder = Color(0xFFF5E7C6);
  static const avatarBg = Color(0xFF3A3A3A);
  static const avatarRing = Color(0xFFF5E7C6);
}

/// The screens' background: the shell colour, lit softly from the middle (a warm glow
/// just above centre fading to slightly deeper edges).
class SamrahBackdrop extends StatelessWidget {
  const SamrahBackdrop({super.key, required this.child});
  final Widget child;

  static const _light = Color(0xFF3A3A3A); // the glow at the centre
  static const _edge = Color(0xFF141414); // the corners

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.05,
          colors: [_light, SamrahColors.bg, _edge],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
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
      // screens are transparent: each page carries SamrahBackdrop (added by the page transition)
      scaffoldBackgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
          elevation: 3,
          shadowColor: const Color(0xAA000000),
          side: const BorderSide(color: Color(0xFFFFB066), width: 1.2),
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
