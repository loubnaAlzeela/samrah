// Building blocks of the game table: the felt, a seat (card-back fan +
// avatar with turn-timer ring + name capsule + small count box), and the
// score / last-trick badges. GameScreen places them on a fixed 390-wide
// canvas; these widgets only know how to draw themselves.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';
import 'motion.dart';
import 'playing_card_view.dart';

/// The table surface: wine felt with a raised warm-grey rim.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB066), SamrahColors.tableRim, Color(0xFFB85600)],
        ),
        boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 24, offset: Offset(0, 12))],
      ),
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.0,
            colors: [SamrahColors.tableCenter, SamrahColors.tableMid, SamrahColors.tableEdge],
            stops: [0, 0.6, 1],
          ),
        ),
      ),
    );
  }
}

/// Decorative fan of card backs behind an opponent's avatar. [mirror] sweeps
/// it to the right instead of the left (used by the right-hand seat so the
/// fan never leaves the screen).
class SeatFan extends StatelessWidget {
  const SeatFan({super.key, this.mirror = false, this.cardWidth = 34});
  final bool mirror;
  final double cardWidth;

  static const _angles = [-78.0, -64.0, -50.0, -36.0, -22.0, -8.0, 4.0];

  @override
  Widget build(BuildContext context) {
    final h = cardWidth * PlayingCardView.aspect;
    final box = h * 2 + cardWidth;
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final a in _angles)
            Positioned(
              // bottom-centre of every card sits on the pivot, slightly to the
              // fan's open side of the avatar centre
              left: box / 2 - cardWidth / 2 + (mirror ? -12 : 12),
              top: box / 2 - h,
              child: Transform.rotate(
                angle: (mirror ? -a : a) * math.pi / 180,
                alignment: Alignment.bottomCenter,
                child: CardBack(width: cardWidth),
              ),
            ),
        ],
      ),
    );
  }
}

/// Round avatar (first letter of the name) with the brass countdown ring
/// while it's this seat's turn. [frac] = share of the turn time still left.
class SeatAvatar extends StatelessWidget {
  const SeatAvatar({super.key, required this.name, required this.size, this.turn = false, this.frac = 0, this.bot = false});
  final String name;
  final double size;
  final bool turn;
  final double frac;
  final bool bot;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '؟';
    // whoever is to act breathes gently, so the eye finds them at once
    return Breathe(active: turn, amount: 0.05, child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size - 8,
            height: size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFF555555), SamrahColors.avatarBg], center: Alignment(-0.3, -0.4)),
              border: Border.all(color: SamrahColors.avatarRing, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: bot
                ? Icon(Icons.smart_toy_outlined, color: SamrahColors.text, size: size * 0.42)
                : Text(letter, style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
          ),
          if (turn)
            Positioned.fill(
              child: CustomPaint(painter: _RingPainter(frac.clamp(0.0, 1.0))),
            ),
        ],
      ),
    ));
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac);
  final double frac;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(2.5);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x55000000));
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * frac, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = SamrahColors.turnRing);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}

/// Name capsule under an avatar.
class NamePill extends StatelessWidget {
  const NamePill({super.key, required this.text, this.width = 84, this.highlight = false});
  final String text;
  final double width;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 21,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: SamrahColors.pillBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: highlight ? SamrahColors.text : SamrahColors.pillBorder, width: 1.2),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: SamrahColors.onTable, fontSize: 11, fontWeight: FontWeight.w500, height: 1.1),
      ),
    );
  }
}

/// Small black box under a seat: tricks taken (or the bid while bidding).
class CountBox extends StatelessWidget {
  const CountBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(5)),
      child: int.tryParse(text) != null
          ? CountUp(value: int.parse(text), style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w700, height: 1))
          : Text(text, style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w700, height: 1)),
    );
  }
}

/// Tiny «موزّع» tag next to the dealer's count box.
class DealerTag extends StatelessWidget {
  const DealerTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SamrahColors.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SamrahColors.fieldBorder),
      ),
      child: const Text('موزّع', style: TextStyle(color: SamrahColors.text, fontSize: 9, fontWeight: FontWeight.w600, height: 1)),
    );
  }
}

/// Diamond-shaped score box, top-left: top/bottom cells = us (partner / me),
/// left/right = them, centre = the target. Always laid out left-to-right.
class ScoreDiamond extends StatelessWidget {
  const ScoreDiamond({super.key, required this.top, required this.left, required this.right, required this.bottom, required this.center, this.usVertical = true});
  final int top, left, right, bottom;

  /// Middle cell: the target (tarneeb) or the kingdom number (trix).
  final String center;

  /// Tarneeb: the vertical pair is our team — give it a subtle outline.
  final bool usVertical;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool us = false, bool center = false}) => Container(
          width: 32,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SamrahColors.scorebox,
            borderRadius: BorderRadius.circular(8),
            border: us ? Border.all(color: const Color(0xFF8A8372)) : null,
          ),
          child: Builder(builder: (_) {
            final style = TextStyle(color: center ? SamrahColors.onTableAccent : SamrahColors.text, fontWeight: FontWeight.w700, fontSize: 13, height: 1);
            final n = int.tryParse(t);
            // scores roll to their new value at the end of a round
            return n != null && !center ? CountUp(value: n, style: style) : Text(t, style: style);
          }),
        );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 82,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // thin frame linking the cells
            Container(
              width: 64,
              height: 56,
              decoration: BoxDecoration(border: Border.all(color: SamrahColors.line, width: 1.5), borderRadius: BorderRadius.circular(8)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                cell('$top', us: usVertical),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [cell('$left'), const SizedBox(width: 2), cell(center, center: true), const SizedBox(width: 2), cell('$right')],
                ),
                const SizedBox(height: 2),
                cell('$bottom', us: usVertical),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small gold crown marking the kingdom owner (trix).
class CrownMark extends StatelessWidget {
  const CrownMark({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 6,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(5)),
      child: SizedBox(width: size, height: size * 0.8, child: CustomPaint(painter: _CrownPainter())),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w * 0.28, h * 0.55)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.72, h * 0.55)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.88, h * 0.82)
      ..lineTo(w * 0.12, h * 0.82)
      ..close();
    final paint = Paint()..color = SamrahColors.onTableAccent;
    canvas.drawPath(p, paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.12, h * 0.88, w * 0.76, h * 0.12), paint);
  }

  @override
  bool shouldRepaint(_CrownPainter old) => false;
}

/// The last completed trick as four tiny cards in a diamond (top, left,
/// right, bottom = where each player sits). [cardAt] maps a physical slot
/// (0 bottom, 1 right, 2 top, 3 left) to that player's card, or null.
class LastTrickDiamond extends StatelessWidget {
  const LastTrickDiamond({super.key, required this.cardAt});
  final String? Function(int slot) cardAt;

  @override
  Widget build(BuildContext context) {
    const w = 24.0;
    const h = w * PlayingCardView.aspect;
    Widget at(int slot, double left, double top) {
      final c = cardAt(slot);
      return Positioned(left: left, top: top, child: c == null ? const SizedBox.shrink() : PlayingCardView(code: c, width: w));
    }

    return SizedBox(
      width: 74,
      height: 78,
      child: Stack(
        children: [
          at(3, 0, 18),
          at(1, 74 - w, 18),
          at(2, (74 - w) / 2, 0),
          at(0, (74 - w) / 2, 78 - h),
        ],
      ),
    );
  }
}
