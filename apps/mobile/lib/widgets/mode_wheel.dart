// The home screen's mode picker: the cards sit on a turning wheel. The one in
// front is full size and lit; its neighbours lean back along an arc, smaller
// and dimmed, half hidden behind it. Swipe, tap a side card, or use the arrows
// to turn the wheel; tap the front card to act. A card morphs as it travels:
// its circle fills with brass and its footer lights up as it reaches the front.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/settings_screen.dart' show AppSettings;
import '../theme/samrah_theme.dart';
import 'motion.dart';

class ModeItem {
  const ModeItem({required this.icon, required this.title, required this.action, required this.onTap});
  final IconData icon;

  /// e.g. «لعبة ودية»
  final String title;

  /// footer line, e.g. «العب الآن»
  final String action;
  final VoidCallback onTap;
}

class ModeWheel extends StatefulWidget {
  const ModeWheel({super.key, required this.items, this.initial = 0});
  final List<ModeItem> items;
  final int initial;

  @override
  State<ModeWheel> createState() => _ModeWheelState();
}

class _ModeWheelState extends State<ModeWheel> with SingleTickerProviderStateMixin {
  static const _cardW = 150.0;
  static const _cardH = 200.0;

  /// horizontal distance between neighbouring cards
  static const _spacing = 104.0;
  static const _sideScale = 0.72;

  /// wheel position: item i is in front when _pos == i (mod n)
  late double _pos = widget.initial.toDouble();
  late final AnimationController _snap;
  Animation<double>? _snapAnim;

  int get _n => widget.items.length;
  int get _front => _pos.round() % _n;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(vsync: this, duration: Motion.normal)..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onSnapTick() => setState(() => _pos = _snapAnim!.value);

  void _animateTo(double target) {
    final landing = target.round() % _n;
    if (landing != _front) AppSettings.tick();
    _snapAnim = Tween(begin: _pos, end: target).animate(CurvedAnimation(parent: _snap, curve: Motion.curve));
    _snap.forward(from: 0);
  }

  /// turn one step; +1 brings the card on the left (RTL: the next one) to the front
  void _step(int dir) => _animateTo(_pos.roundToDouble() + dir);

  /// bring item [i] to the front by the shortest way round
  void _bringToFront(int i) {
    var d = (i - _pos) % _n;
    if (d > _n / 2) d -= _n;
    _animateTo(_pos + d);
  }

  /// signed distance of item [i] from the front, in (-n/2, n/2]
  double _offsetOf(int i) {
    var d = (i - _pos) % _n;
    if (d > _n / 2) d -= _n;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    // back cards first, the front card last (on top)
    final order = [for (var i = 0; i < _n; i++) i]..sort((a, b) => _offsetOf(b).abs().compareTo(_offsetOf(a).abs()));
    return SizedBox(
      width: double.infinity,
      height: _cardH + 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _snap.stop(),
        onHorizontalDragUpdate: (d) => setState(() => _pos += d.delta.dx / _spacing),
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          // a flick turns at least one step in its direction
          final target = v.abs() > 300 ? (v > 0 ? _pos.ceilToDouble() : _pos.floorToDouble()) : _pos.roundToDouble();
          _animateTo(target);
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (final i in order) _placed(i),
            Positioned(left: 0, child: _arrow(Icons.chevron_left, () => _step(1))),
            Positioned(right: 0, child: _arrow(Icons.chevron_right, () => _step(-1))),
          ],
        ),
      ),
    );
  }

  Widget _placed(int i) {
    final d = _offsetOf(i);
    final t = d.abs().clamp(0.0, 1.0); // 0 = front, 1 = side
    // beyond one step a card fades out behind the others while it swaps sides
    final fade = (1.5 - d.abs()).clamp(0.0, 0.5) * 2;
    final scale = 1 - (1 - _sideScale) * t;
    final matrix = Matrix4.identity()
      ..translateByDouble(-d * _spacing, 16 * d * d, 0, 1) // RTL: the next item waits on the left, lower on the arc
      ..rotateZ(-d * 0.10)
      ..scaleByDouble(scale, scale, 1, 1);
    // fill the wheel so taps land on the card where it is drawn (moved, tilted, scaled),
    // not only inside its untransformed box; the empty area around it passes taps through
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: fade < 0.2,
        child: Opacity(
          opacity: fade,
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: Center(
              child: GestureDetector(
                onTap: () => t < 0.05 ? widget.items[i].onTap() : _bringToFront(i),
                child: _card(widget.items[i], t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ModeItem item, double t) {
    final lit = 1 - t;
    final circle = Color.lerp(SamrahColors.surface2, SamrahColors.accent, lit)!;
    final iconColor = Color.lerp(SamrahColors.text, SamrahColors.onAccent, lit)!;
    return Container(
      width: _cardW,
      height: _cardH,
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color.lerp(SamrahColors.line, SamrahColors.fieldBorder, lit)!, width: 1 + lit),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35 + 0.35 * lit), blurRadius: 10 + 18 * lit, offset: Offset(0, 4 + 8 * lit))],
      ),
      foregroundDecoration: BoxDecoration(
        // side cards sink into the dark
        color: Colors.black.withValues(alpha: 0.45 * t),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 14),
          Text(item.title, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700, height: 1.2)),
          Expanded(
            child: Center(
              child: Breathe(
                active: t < 0.05,
                amount: 0.05,
                period: const Duration(milliseconds: 1400),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circle,
                    border: Border.all(color: Color.lerp(SamrahColors.fieldBorder, SamrahColors.accent, lit)!, width: 2),
                    boxShadow: [BoxShadow(color: SamrahColors.accent.withValues(alpha: 0.45 * lit), blurRadius: 24, spreadRadius: 1)],
                  ),
                  child: Icon(item.icon, color: iconColor, size: 40 + 4 * lit),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: SamrahColors.scorebox,
              border: Border(top: BorderSide(color: Color.lerp(SamrahColors.line, SamrahColors.accent, lit * 0.6)!)),
            ),
            child: Text(
              item.action,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color.lerp(SamrahColors.textMuted, SamrahColors.onTableAccent, lit), fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36,
      height: 44,
      child: IconButton(padding: EdgeInsets.zero, onPressed: onTap, icon: Icon(icon, color: SamrahColors.icon, size: 30)),
    );
  }
}
