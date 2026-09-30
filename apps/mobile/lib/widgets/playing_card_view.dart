// One playing card (design/card-spec.md): cream face, rank + suit in the
// top-left corner, a large suit mark in the bottom-right. Every size derives
// from the card width, so the same widget serves the hand (84), the trick on
// the table (58) and the last-trick preview (22).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_card.dart';
import '../theme/samrah_theme.dart';
import 'suit_icon.dart';

class PlayingCardView extends StatelessWidget {
  const PlayingCardView({super.key, required this.code, this.width = 44, this.dimmed = false, this.selected = false, this.highlight = false});

  final String code;
  final double width;

  /// Not playable right now: a dark veil over the face (never opacity —
  /// the table would bleed through, card-spec §2).
  final bool dimmed;

  /// Picked in the hand, waiting for the second tap.
  final bool selected;

  /// The card currently winning the finished trick.
  final bool highlight;

  static const double aspect = 1.42;

  @override
  Widget build(BuildContext context) {
    // Hand: two decks, so a card code may carry a copy letter ("S5a"); jokers are "Xa" / "Xb"
    if (code.startsWith('X')) return _joker();
    final card = GameCard.parse(code.replaceFirst(RegExp(r'[ab]$'), ''));
    final w = width;
    final h = w * aspect;
    final color = card.isRed ? SamrahColors.suitRed : SamrahColors.suitBlack;
    final radius = BorderRadius.circular(w * 0.1);
    final tiny = w < 34;
    final ten = card.rank == 10;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: SamrahColors.cardFace,
          borderRadius: radius,
          border: Border.all(
            color: selected ? SamrahColors.turnRing : (highlight ? SamrahColors.text : SamrahColors.cardEdge),
            width: selected ? 3 : (highlight ? 2.5 : 1),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: w * 0.08, offset: Offset(-w * 0.02, w * 0.03))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned(
                top: w * (tiny ? 0.02 : 0.04),
                left: w * (tiny ? 0.06 : 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      card.rankLabel,
                      style: GoogleFonts.cairo(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: w * (tiny ? 0.5 : (ten ? 0.3 : 0.34)),
                        height: 1,
                        letterSpacing: ten ? -w * 0.03 : -w * 0.01,
                      ),
                    ),
                    SizedBox(height: w * 0.02),
                    SuitIcon(suit: card.suitCode, size: w * (tiny ? 0.42 : 0.26)),
                  ],
                ),
              ),
              if (!tiny)
                Positioned(
                  right: w * 0.07,
                  bottom: w * 0.07,
                  child: SuitIcon(suit: card.suitCode, size: w * 0.5),
                ),
              if (dimmed) const Positioned.fill(child: ColoredBox(color: SamrahColors.cardVeil)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on PlayingCardView {
  Widget _joker() {
    final w = width;
    final radius = BorderRadius.circular(w * 0.1);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w,
        height: w * PlayingCardView.aspect,
        decoration: BoxDecoration(
          color: SamrahColors.cardFace,
          borderRadius: radius,
          border: Border.all(color: selected ? SamrahColors.turnRing : (highlight ? SamrahColors.text : SamrahColors.cardEdge), width: selected ? 3 : (highlight ? 2.5 : 1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: w * 0.08, offset: Offset(-w * 0.02, w * 0.03))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned(
                top: w * 0.04,
                left: w * 0.06,
                child: Text('J', style: GoogleFonts.cairo(color: SamrahColors.suitRed, fontWeight: FontWeight.w700, fontSize: w * (w < 34 ? 0.5 : 0.34), height: 1)),
              ),
              if (w >= 34)
                Center(child: Icon(Icons.auto_awesome, color: SamrahColors.suitRed, size: w * 0.46)),
              if (w >= 34)
                Positioned(
                  bottom: w * 0.05,
                  left: 0,
                  right: 0,
                  child: Text('جوكر', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.suitBlack, fontSize: w * 0.17, fontWeight: FontWeight.w700, height: 1)),
                ),
              if (dimmed) const Positioned.fill(child: ColoredBox(color: SamrahColors.cardVeil)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Face-down card: wine with a cream rim and an inner brass rule and diamond.
class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 28});
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Container(
      width: w,
      height: w * PlayingCardView.aspect,
      decoration: BoxDecoration(
        color: SamrahColors.cardBack,
        border: Border.all(color: SamrahColors.cardFace, width: (w * 0.06).clamp(1.0, 3.0)),
        borderRadius: BorderRadius.circular(w * 0.12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: EdgeInsets.all(w * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: SamrahColors.cardBackStar.withValues(alpha: 0.6), width: 1),
            borderRadius: BorderRadius.circular(w * 0.06),
          ),
          child: Center(
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: w * 0.22, height: w * 0.22, color: SamrahColors.cardBackStar),
            ),
          ),
        ),
      ),
    );
  }
}
