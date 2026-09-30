// Suit shapes drawn as vector paths (design/card-spec.md «الأشكال: SVG لا
// يونيكود») — the Unicode glyphs ♥♦ render as colour emoji on some devices
// and ignore our suit colours. Paths are the spec's 100×100 symbols.
import 'package:flutter/material.dart';

import '../models/game_card.dart';
import '../theme/samrah_theme.dart';

class SuitIcon extends StatelessWidget {
  const SuitIcon({super.key, required this.suit, required this.size, this.color});

  /// Wire suit letter: 'S' | 'H' | 'D' | 'C'.
  final String suit;
  final double size;

  /// Defaults to the suit's own red/black.
  final Color? color;

  static Color colorOf(String suit) => suit == 'H' || suit == 'D' ? SamrahColors.suitRed : SamrahColors.suitBlack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SuitPainter(suit, color ?? colorOf(suit))),
    );
  }
}

/// Suit symbol on a small cream chip, so red stays legible on dark panels
/// (card-spec §0 `.suitchip`).
class SuitChip extends StatelessWidget {
  const SuitChip({super.key, required this.suit, this.size = 22});
  final String suit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: SamrahColors.cardFace, borderRadius: BorderRadius.circular(size * 0.27)),
      alignment: Alignment.center,
      child: SuitIcon(suit: suit, size: size * 0.68),
    );
  }
}

/// «قلب ♥» — suit name with its chip, never the name alone.
class SuitLabel extends StatelessWidget {
  const SuitLabel({super.key, required this.suit, this.style});
  final String suit;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(suitNameArFromCode(suit), style: style),
        const SizedBox(width: 4),
        SuitChip(suit: suit, size: 20),
      ],
    );
  }
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color);
  final String suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s, s);
    canvas.drawPath(_path(suit), Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  static Path _path(String suit) {
    switch (suit) {
      case 'S':
        return Path()
          ..moveTo(50, 4)
          ..cubicTo(62, 25, 95, 40, 95, 62)
          ..cubicTo(95, 76, 84, 85, 72, 85)
          ..cubicTo(63, 85, 56, 80, 53, 75)
          ..cubicTo(54, 84, 58, 91, 67, 97)
          ..lineTo(33, 97)
          ..cubicTo(42, 91, 46, 84, 47, 75)
          ..cubicTo(44, 80, 37, 85, 28, 85)
          ..cubicTo(16, 85, 5, 76, 5, 62)
          ..cubicTo(5, 40, 38, 25, 50, 4)
          ..close();
      case 'H':
        return Path()
          ..moveTo(50, 92)
          ..cubicTo(20, 68, 4, 50, 4, 31)
          ..cubicTo(4, 15, 16, 5, 30, 5)
          ..cubicTo(40, 5, 47, 11, 50, 19)
          ..cubicTo(53, 11, 60, 5, 70, 5)
          ..cubicTo(84, 5, 96, 15, 96, 31)
          ..cubicTo(96, 50, 80, 68, 50, 92)
          ..close();
      case 'D':
        return Path()
          ..moveTo(50, 2)
          ..lineTo(88, 50)
          ..lineTo(50, 98)
          ..lineTo(12, 50)
          ..close();
      default: // 'C'
        return Path()
          ..addOval(Rect.fromCircle(center: const Offset(50, 27), radius: 21))
          ..addOval(Rect.fromCircle(center: const Offset(26, 58), radius: 21))
          ..addOval(Rect.fromCircle(center: const Offset(74, 58), radius: 21))
          ..moveTo(42, 44)
          ..lineTo(58, 44)
          ..lineTo(55, 66)
          ..cubicTo(56, 80, 60, 89, 68, 97)
          ..lineTo(32, 97)
          ..cubicTo(40, 89, 44, 80, 45, 66)
          ..close();
    }
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}
