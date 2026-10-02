// Home-screen mode picker as a radial wheel: an upper half-donut split into
// equal wedges, one option per wedge (icon + short label), with a round action
// button in the hollow centre. Drag sideways to turn the wheel (it loops for
// ever); whichever wedge comes to the top (12 o'clock) is the active one — it
// pops outward and lights up gradually as it arrives — and the centre button
// shows and performs its action. Releasing snaps to the nearest wedge (a fast
// swipe travels further); tapping a wedge turns it to the top.
//
// Geometry: the wheel's full circle holds twice the options (so it can loop);
// only the upper half is drawn, and nothing below the baseline.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/settings_screen.dart' show AppSettings;

/// Accent for the active wedge's border and the centre button — change it here.
const kWheelAccent = Color(0xFFFA8112);

/// The centre button's pulse ring: a lighter tone of the accent.
const kWheelPulse = Color(0xFFFFB066);

/// Icon and label on the accent-filled centre button.
const kWheelOnAccent = Color(0xFF222222);

class RadialOption {
  const RadialOption({required this.label, required this.icon, required this.action, required this.onSelected});
  final String label;
  final IconData icon;

  /// the short action word on the centre button, e.g. «العب»
  final String action;
  final VoidCallback onSelected;
}

class RadialModeWheel extends StatefulWidget {
  const RadialModeWheel({super.key, required this.options, this.initialIndex = 0}) : assert(options.length >= 3);
  final List<RadialOption> options;
  final int initialIndex;

  static const minRadius = 120.0;
  static const maxRadius = 190.0;

  /// how far the top wedge reaches past the others
  static const pop = 10.0;

  @override
  State<RadialModeWheel> createState() => _RadialModeWheelState();
}

/// Sizes for one outer radius; everything is measured from the baseline centre.
class _Geo {
  _Geo(this.w, this.outer) : inner = outer * 0.55 {
    buttonR = math.min(inner - 30, 56);
    // the button sits in the hollow, lifted so most of it is above the baseline
    buttonLift = buttonR * 0.55;
    top = outer + RadialModeWheel.pop + 2;
    height = top + (buttonR - buttonLift) + 2;
  }

  final double w, outer, inner;
  late final double buttonR, buttonLift, top, height;

  Offset get centre => Offset(w / 2, top);
  Offset get button => Offset(w / 2, top - buttonLift);

  /// the pulse ring's largest radius
  double get pulseMax => buttonR + 14;
}

class _RadialModeWheelState extends State<RadialModeWheel> with TickerProviderStateMixin {
  static const _gapDeg = 3.0;

  /// the wheel's turn, in wedges: option i is at the top when [_turn] == i (mod n)
  late double _turn = widget.initialIndex.toDouble();
  late final AnimationController _spin = AnimationController(vsync: this)..addListener(_onSpin);
  Animation<double>? _spinAnim;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  bool _dragging = false;

  int get _n => widget.options.length;

  /// the full circle holds the options twice, so the half we draw is always full
  int get _slots => 2 * _n;
  double get _slotDeg => 360 / _slots;

  int get _active => _turn.round() % _n;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _lastTick = _turn.round();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// +1: the next option waits on the right (RTL); -1: on the left
  double get _side => _rtl ? 1 : -1;

  void _onSpin() {
    setState(() => _turn = _spinAnim!.value);
    _tick();
  }

  /// a click each time a new option passes the top
  void _tick() {
    final r = _turn.round();
    if (r != _lastTick) {
      _lastTick = r;
      AppSettings.tick();
    }
  }

  void _setMoving(bool moving) {
    if (moving) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  void _spinTo(double target) {
    final dist = (target - _turn).abs();
    _spin.duration = Duration(milliseconds: (450 + 90 * math.max(0, dist - 1)).clamp(450, 1200).round());
    _spinAnim = Tween(begin: _turn, end: target).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic));
    _setMoving(true);
    _spin.forward(from: 0).whenComplete(() {
      if (!mounted || _dragging) return;
      if (AppSettings.vibration) HapticFeedback.lightImpact();
      _setMoving(false);
      setState(() {});
    });
  }

  /// degrees of turn for [dx] pixels at the band's middle
  double _wedgesFor(double dx, _Geo g) {
    final mid = (g.inner + g.outer) / 2;
    final deg = dx / mid * 180 / math.pi;
    return deg / _slotDeg;
  }

  /// where option-slot offset [p] (0 = top) sits on the circle, in degrees (270 = up)
  double _angleOf(double p) => 270 + _side * p * _slotDeg;

  /// the offset (in wedges from the top) of option [i]'s nearest copy; the others are ±n away
  double _offsetOf(int i) {
    var p = (i - _turn) % _n;
    if (p >= _n / 2) p -= _n;
    return p;
  }

  void _onTapUp(TapUpDetails d, _Geo g) {
    final v = d.localPosition - g.centre;
    final dist = v.distance;
    // the centre button
    if ((d.localPosition - g.button).distance <= g.buttonR) {
      widget.options[_active].onSelected();
      return;
    }
    if (v.dy > 0 || dist < g.inner || dist > g.outer + RadialModeWheel.pop) return;
    final a = (math.atan2(v.dy, v.dx) * 180 / math.pi) % 360;
    final u = ((a - 270) / (_slotDeg * _side)).roundToDouble();
    if (u == 0) return;
    _spinTo(_turn.roundToDouble() + u);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      // the popped wedge stays 12 clear of the screen edges; the height is what we are given
      var outer = math.min(w / 2 - 12 - RadialModeWheel.pop, RadialModeWheel.maxRadius);
      if (box.maxHeight.isFinite) {
        while (outer > RadialModeWheel.minRadius && _Geo(w, outer).height > box.maxHeight) {
          outer -= 1;
        }
      }
      outer = math.max(outer, RadialModeWheel.minRadius);
      final g = _Geo(w, outer);
      return SizedBox(
        width: w,
        height: g.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onTapUp(d, g),
          onHorizontalDragStart: (_) {
            _dragging = true;
            _spin.stop();
            _setMoving(true);
          },
          onHorizontalDragUpdate: (d) {
            // the wheel follows the finger: dragging right turns the top to the right
            setState(() => _turn -= _side * _wedgesFor(d.delta.dx, g));
            _tick();
          },
          onHorizontalDragEnd: (d) {
            _dragging = false;
            // a fling carries on for about a quarter second's worth of its speed
            final carry = -_side * _wedgesFor(d.primaryVelocity ?? 0, g) * 0.25;
            _spinTo((_turn + carry).roundToDouble());
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WheelPainter(
                      geo: g,
                      wedges: [
                        for (var i = 0; i < _n; i++)
                          for (final copy in [0, _n, -_n])
                            // the half circle spans n/2 wedges each side of the top; one more is drawn clipped
                            if ((_offsetOf(i) + copy).abs() <= _n / 2 + 1) (i, _offsetOf(i) + copy),
                      ],
                      options: widget.options,
                      angleOf: _angleOf,
                      slotDeg: _slotDeg,
                      gapDeg: _gapDeg,
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      baseStyle: DefaultTextStyle.of(context).style,
                    ),
                  ),
                ),
                if (_pulse.isAnimating) _pulseRing(g),
                _centreButton(g),
                ..._semantics(g),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _pulseRing(_Geo g) {
    final p = _pulse.value;
    final r = g.buttonR + (g.pulseMax - g.buttonR) * p;
    return Positioned(
      left: g.button.dx - r,
      top: g.button.dy - r,
      width: 2 * r,
      height: 2 * r,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kWheelPulse.withValues(alpha: 0.45 * (1 - p)), width: 1.5)),
        ),
      ),
    );
  }

  Widget _centreButton(_Geo g) {
    final o = widget.options[_active];
    return Positioned(
      left: g.button.dx - g.buttonR,
      top: g.button.dy - g.buttonR,
      width: 2 * g.buttonR,
      height: 2 * g.buttonR,
      child: Semantics(
        button: true,
        label: '${o.action} · ${o.label}',
        onTap: o.onSelected,
        excludeSemantics: true,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kWheelAccent,
              boxShadow: [BoxShadow(color: kWheelAccent.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 1)],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(_active),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(o.icon, color: kWheelOnAccent, size: 30),
                  const SizedBox(height: 2),
                  Text(o.action, style: const TextStyle(color: kWheelOnAccent, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// invisible nodes over the visible wedges, for screen readers (touch is handled by angle)
  List<Widget> _semantics(_Geo g) {
    final out = <Widget>[];
    final mid = (g.inner + g.outer) / 2;
    for (var i = 0; i < _n; i++) {
      final p = _offsetOf(i);
      if (p.abs() > _n / 2 - 0.5) continue; // only wedges fully above the baseline
      final a = _angleOf(p) * math.pi / 180;
      final at = g.centre + Offset(math.cos(a), math.sin(a)) * mid;
      out.add(Positioned(
        left: at.dx - 22,
        top: at.dy - 22,
        width: 44,
        height: 44,
        child: Semantics(
          button: true,
          selected: i == _active,
          label: widget.options[i].label,
          onTap: () => _spinTo(_turn.roundToDouble() + p.roundToDouble()),
          child: const IgnorePointer(child: SizedBox.expand()),
        ),
      ));
    }
    return out;
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.geo,
    required this.wedges,
    required this.options,
    required this.angleOf,
    required this.slotDeg,
    required this.gapDeg,
    required this.textDirection,
    required this.textScaler,
    required this.baseStyle,
  });

  final _Geo geo;

  /// (option index, offset from the top in wedges) for every wedge that may show
  final List<(int, double)> wedges;
  final List<RadialOption> options;
  final double Function(double) angleOf;
  final double slotDeg, gapDeg;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// the app's text style (its font), so wedge labels match the rest of the screen
  final TextStyle baseStyle;

  // each wedge is a light-to-dark gradient, the top one brighter
  static const _fillTop = Color(0xFF3E3E3E);
  static const _fillBottom = Color(0xFF2A2A2A);
  static const _activeTop = Color(0xFFFF9A3D);
  static const _activeBottom = Color(0xFFE06F08);
  static const _border = Color(0xFF8A8372);
  static const _ink = Color(0xFFF5E7C6);
  static const _activeInk = Color(0xFF222222);

  @override
  void paint(Canvas canvas, Size size) {
    final c = geo.centre;
    // nothing below the baseline
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, c.dy));
    for (final (i, p) in wedges) {
      // how "at the top" this wedge is: 1 exactly there, 0 one wedge away or more
      final h = (1 - p.abs()).clamp(0.0, 1.0);
      final outer = geo.outer + RadialModeWheel.pop * h;
      final mid = angleOf(p) * math.pi / 180;
      final half = (slotDeg - gapDeg) / 2 * math.pi / 180;
      final path = Path()
        ..arcTo(Rect.fromCircle(center: c, radius: outer), mid - half, 2 * half, true)
        ..arcTo(Rect.fromCircle(center: c, radius: geo.inner), mid + half, -2 * half, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(_fillTop, _activeTop, h)!, Color.lerp(_fillBottom, _activeBottom, h)!],
          ).createShader(path.getBounds()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + h
          ..color = Color.lerp(_border, kWheelAccent, h)!,
      );

      // icon above the label, upright, at the band's middle
      final ink = Color.lerp(_ink, _activeInk, h)!;
      final r = (geo.inner + outer) / 2;
      final at = c + Offset(math.cos(mid), math.sin(mid)) * r;
      final o = options[i];
      final chord = 2 * r * math.sin(half) - 6;
      final icon = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(o.icon.codePoint),
          style: TextStyle(fontFamily: o.icon.fontFamily, package: o.icon.fontPackage, fontSize: 20 + 3 * h, color: ink),
        ),
        textDirection: textDirection,
      )..layout();
      final label = TextPainter(
        text: TextSpan(text: o.label, style: baseStyle.merge(TextStyle(fontSize: 10.5 + 1 * h, height: 1.15, color: ink, fontWeight: h > 0.5 ? FontWeight.w700 : FontWeight.w500))),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 2,
      )..layout(maxWidth: math.max(chord, 40));
      final total = icon.height + 1 + label.height;
      icon.paint(canvas, Offset(at.dx - icon.width / 2, at.dy - total / 2));
      label.paint(canvas, Offset(at.dx - label.width / 2, at.dy - total / 2 + icon.height + 1));
      icon.dispose();
      label.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}
