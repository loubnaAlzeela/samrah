// The end-of-match screen, shared by every game: a turning sunburst behind the
// Samrah mark, a ribbon ("مبروك الفوز!" or "انتهت المباراة"), the game's name,
// then one box per side — the winners' box framed in brass — and the two
// actions: play again at the same table, or go home.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/room_screen.dart' show variantNameAr;
import '../theme/samrah_theme.dart';
import 'motion.dart';

/// One side of the result: a team (one shared [score]) or a single player
/// (each member with its own score in [memberScores]).
class GameOverSide {
  const GameOverSide({required this.names, this.score, this.memberScores, this.won = false});
  final List<String> names;
  final int? score;
  final List<int>? memberScores;
  final bool won;

  /// Two teams of partners (seats t and t+2), the winning team first.
  static List<GameOverSide> teams(String Function(int) name, List<int> teamScores, int? winner) => [
        for (final t in winner == 1 ? const [1, 0] : const [0, 1])
          GameOverSide(names: [name(t), name(t + 2)], score: teamScores[t], won: t == winner),
      ];

  /// Every player for themself: the winners in one side, everyone else in
  /// another, each best score first ([lowerWins] for games like هاند).
  static List<GameOverSide> players(int count, String Function(int) name, List<int> scores, List<int> winners, {bool lowerWins = false}) {
    final order = [for (var i = 0; i < count; i++) i]..sort((a, b) => lowerWins ? scores[a] - scores[b] : scores[b] - scores[a]);
    GameOverSide side(Iterable<int> seats, bool won) {
      final list = seats.toList();
      return GameOverSide(names: [for (final s in list) name(s)], memberScores: [for (final s in list) scores[s]], won: won);
    }

    return [
      side(order.where(winners.contains), true),
      side(order.where((s) => !winners.contains(s)), false),
    ].where((s) => s.names.isNotEmpty).toList();
  }
}

/// Full-table overlay; put it last in the game screen's Stack.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.variant,
    required this.won,
    required this.sides,
    required this.onRematch,
    required this.onHome,
    this.note,
  });

  /// wire variant, e.g. 'tarneeb' (shown by its Arabic name)
  final String variant;

  /// did this player (or their team) win
  final bool won;

  /// winners first; boxes are drawn in this order
  final List<GameOverSide> sides;
  final VoidCallback onRematch;
  final VoidCallback onHome;

  /// optional line under the game name, e.g. «انتهت بقهوة»
  final String? note;

  static const _ribbonWin = [Color(0xFFF08A2C), Color(0xFFD9541E)];
  static const _ribbonLose = [Color(0xFF5E6A78), Color(0xFF3E4752)];
  static const _box = Color(0xFF333333);
  static const _boxInner = Color(0xFF222222);
  static const _green = [Color(0xFF3CC45A), Color(0xFF1E9A3C)];

  @override
  Widget build(BuildContext context) {
    final winners = sides.where((s) => s.won).toList();
    final others = sides.where((s) => !s.won).toList();
    return Positioned.fill(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ColoredBox(
          color: const Color(0xB3000000),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: PopIn(
                  from: 0.8,
                  duration: Motion.slow,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _emblem(),
                      _ribbon(),
                      _card(winners, others),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- top: rays + mark ------------------------------------------------------------

  Widget _emblem() {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          if (won) const Positioned(top: -70, child: _Sunburst(size: 340)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (won ? SamrahColors.accent : Colors.black).withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 4)],
              ),
              child: Image.asset('assets/brand/samrah-mark.png', height: 130, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ribbon() {
    final colors = won ? _ribbonWin : _ribbonLose;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // the folded ribbon ends peeking out behind
        Positioned.fill(
          top: 12,
          bottom: -6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 2; i++)
                Container(width: 26, decoration: BoxDecoration(color: Color.lerp(colors[1], Colors.black, 0.35), borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            borderRadius: BorderRadius.circular(6),
            border: Border(bottom: BorderSide(color: Color.lerp(colors[1], Colors.black, 0.3)!, width: 4)),
            boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Text(
            won ? 'مبروك الفوز!' : 'انتهت المباراة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.2,
              shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
  }

  // --- the card: game name, sides, actions ---------------------------------------------

  Widget _card(List<GameOverSide> winners, List<GameOverSide> others) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        color: _box,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        boxShadow: [BoxShadow(color: Color(0xB3000000), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // game name tab hanging from the ribbon
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6C9A0), Color(0xFFE9A874)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Text(variantNameAr(variant), style: GoogleFonts.cairo(color: const Color(0xFF5A3016), fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(note!, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (winners.isNotEmpty) _sideBox(winners, winnersBox: true),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _sideBox(others, winnersBox: false),
                ],
                const SizedBox(height: 18),
                _actions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One framed box holding one or more sides (several teams/players can share
  /// the losers' box).
  Widget _sideBox(List<GameOverSide> group, {required bool winnersBox}) {
    final box = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, winnersBox ? 22 : 14, 8, 14),
      decoration: BoxDecoration(
        color: _boxInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: winnersBox ? SamrahColors.accent : const Color(0xFF1C1816), width: winnersBox ? 3 : 1.5),
        boxShadow: winnersBox ? [BoxShadow(color: SamrahColors.accent.withValues(alpha: 0.25), blurRadius: 16)] : null,
      ),
      child: Column(
        children: [
          for (var i = 0; i < group.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFF443B36))),
            _side(group[i]),
          ],
        ],
      ),
    );
    if (!winnersBox) return box;
    final title = group.fold<int>(0, (n, s) => n + s.names.length) > 1 ? 'الفائزون' : 'الفائز';
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(padding: const EdgeInsets.only(top: 12), child: box),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF55504C), Color(0xFF34302D)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1C1816)),
          ),
          child: Text(title, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _side(GameOverSide s) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            for (var i = 0; i < s.names.length; i++)
              _player(s.names[i], s.memberScores == null ? null : s.memberScores![i], s.won),
          ],
        ),
        if (s.score != null) ...[
          const SizedBox(height: 10),
          _scoreChip(s.score!, s.won),
        ],
      ],
    );
  }

  Widget _player(String name, int? score, bool won) {
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(center: Alignment(0, -0.4), colors: [Color(0xFF5A5250), Color(0xFF151212)]),
              border: Border.all(color: won ? SamrahColors.accent : const Color(0xFF6B625D), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.person, color: Color(0xFFB8B0AA), size: 44),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1816),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8F8680)),
            ),
            child: Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
          ),
          if (score != null) ...[
            const SizedBox(height: 6),
            _scoreChip(score, won, small: true),
          ],
        ],
      ),
    );
  }

  Widget _scoreChip(int score, bool won, {bool small = false}) {
    return Container(
      width: small ? 64 : 110,
      padding: EdgeInsets.symmetric(vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF443B36))),
      child: Center(
        child: CountUp(
          value: score,
          format: (n) => n < 0 ? '−${-n}' : '$n',
          style: TextStyle(
            color: won ? SamrahColors.statusOpen : SamrahColors.text,
            fontSize: small ? 16 : 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        // RTL: home sits at the right edge, play-again fills the rest
        Pressable(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onHome,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5C542), Color(0xFFE09A1A)]),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(bottom: BorderSide(color: Color(0xFFA86F0E), width: 3)),
                ),
                child: const Tooltip(message: 'للصفحة الرئيسية', child: Icon(Icons.home_rounded, color: Colors.white, size: 32)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Pressable(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRematch,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _green),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(bottom: BorderSide(color: Color(0xFF14702B), width: 3)),
                  ),
                  child: Center(
                    child: Text(
                      'العب مرة أخرى',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2)]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft light rays turning slowly behind the mark.
class _Sunburst extends StatefulWidget {
  const _Sunburst({required this.size});
  final double size;

  @override
  State<_Sunburst> createState() => _SunburstState();
}

class _SunburstState extends State<_Sunburst> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RotationTransition(
        turns: _spin,
        child: CustomPaint(size: Size.square(widget.size), painter: _RaysPainter()),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFFFFE3A6).withValues(alpha: 0.4), const Color(0xFFFFE3A6).withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    const rays = 14;
    const half = math.pi / rays / 2;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - half), c.dy + r * math.sin(a - half))
        ..lineTo(c.dx + r * math.cos(a + half), c.dy + r * math.sin(a + half))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
