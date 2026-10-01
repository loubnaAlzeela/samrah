// Opening scene: an evening sky; the four suits come in from the four corners
// of the table — four players arriving for the سمرة — orbit in, meet in the
// middle with a brass flash, and the Samrah mark rises out of it, then the
// wordmark with a light passing over it. About 3 s; a tap skips it.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  /// the screen that follows (the login)
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _left = false;

  // phases, as fractions of the whole run
  static const _suitsIn = Interval(0.0, 0.42, curve: Curves.easeInOutCubic);
  static const _flash = Interval(0.38, 0.62, curve: Curves.easeOut);
  static const _markIn = Interval(0.46, 0.74, curve: Curves.elasticOut);
  static const _wordIn = Interval(0.58, 0.78, curve: Curves.easeOutCubic);
  static const _shine = Interval(0.72, 0.98, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _go();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => SamrahBackdrop(child: widget.next),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _go,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => LayoutBuilder(builder: (context, box) => _scene(box.biggest)),
        ),
      ),
    );
  }

  Widget _scene(Size size) {
    final t = _c.value;
    final c = Offset(size.width / 2, size.height * 0.42);
    final suitsT = _suitsIn.transform(t);
    final flashT = t < _flash.begin ? 0.0 : _flash.transform(t);
    final markT = t < _markIn.begin ? 0.0 : _markIn.transform(t);
    final wordT = t < _wordIn.begin ? 0.0 : _wordIn.transform(t);
    final shineT = t < _shine.begin ? -1.0 : _shine.transform(t);
    return Stack(
      children: [
        // evening sky: a warm glow over the table, and stars
        Positioned.fill(child: CustomPaint(painter: _SkyPainter(t: t, center: c))),

        // the four suits, each from its own corner, spiralling in
        if (suitsT < 1)
          for (var i = 0; i < 4; i++) _suit(i, suitsT, c, size),

        // the mark rises out of the flash
        if (markT > 0)
          Positioned(
            left: c.dx - 90,
            top: c.dy - 90,
            width: 180,
            height: 180,
            child: Transform.scale(
              scale: markT.clamp(0.0, 1.2),
              child: Opacity(
                opacity: (markT * 2).clamp(0.0, 1.0),
                child: Image.asset('assets/brand/samrah-mark.png', fit: BoxFit.contain),
              ),
            ),
          ),

        // brass flash where they meet: a ring that opens and fades
        if (flashT > 0 && flashT < 1)
          Positioned(
            left: c.dx - 160,
            top: c.dy - 160,
            width: 320,
            height: 320,
            child: CustomPaint(painter: _RingPainter(flashT)),
          ),

        // the wordmark slides up, then a light passes over it
        if (wordT > 0)
          Positioned(
            left: 0,
            right: 0,
            top: c.dy + 104 + 20 * (1 - wordT),
            child: Opacity(
              opacity: wordT,
              child: Center(
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment(-1 + 3 * shineT - 0.4, -0.3),
                    end: Alignment(-1 + 3 * shineT + 0.4, 0.3),
                    colors: const [Color(0x00FFFFFF), Color(0xCCFFF3D6), Color(0x00FFFFFF)],
                  ).createShader(r),
                  child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 64, semanticLabel: 'سمرة'),
                ),
              ),
            ),
          ),

        // the invitation line, last
        if (wordT > 0.5)
          Positioned(
            left: 0,
            right: 0,
            top: c.dy + 184,
            child: Opacity(
              opacity: ((wordT - 0.5) * 2).clamp(0.0, 1.0),
              child: const Text(
                'الطاولة جاهزة… والسهرة بدأت',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: SamrahColors.textMuted, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  static const _suits = ['♠', '♥', '♦', '♣'];

  Widget _suit(int i, double t, Offset c, Size size) {
    // start at a real corner of the screen (TL, TR, BR, BL), a little inside it,
    // and curl in (a small turn, so none swings off the screen on the way)
    const inset = 44.0;
    final corner = [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(size.width - inset, size.height - inset),
      Offset(inset, size.height - inset),
    ][i];
    final from = corner - c;
    final r = from.distance * math.pow(1 - t, 1.4);
    final a = from.direction + t * math.pi / 6;
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    final red = i == 1 || i == 2;
    const box = 70.0;
    return Positioned(
      left: p.dx - box / 2,
      top: p.dy - box / 2,
      width: box,
      height: box,
      child: Opacity(
        opacity: (t * 4).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (1 - t) * math.pi * 1.5,
          child: Transform.scale(
            scale: 0.7 + 0.5 * t,
            child: Center(
              child: Text(
                _suits[i],
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  color: red ? const Color(0xFFD9443B) : SamrahColors.cardFace,
                  shadows: [Shadow(color: SamrahColors.accent.withValues(alpha: 0.7 * t), blurRadius: 18)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Warm glow over the table and a field of stars that twinkle in.
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.t, required this.center});
  final double t;
  final Offset center;

  static final List<(double, double, double, double)> _stars = () {
    final rnd = math.Random(7);
    return [for (var i = 0; i < 70; i++) (rnd.nextDouble(), rnd.nextDouble() * 0.75, 0.6 + rnd.nextDouble() * 1.4, rnd.nextDouble())];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    // the glow grows as the table gathers
    final glowR = size.shortestSide * (0.55 + 0.25 * t);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          SamrahColors.tableMid.withValues(alpha: 0.55 * math.min(1, t * 2)),
          SamrahColors.bg.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: glowR)),
    );
    for (final (x, y, r, phase) in _stars) {
      // each star fades in at its own moment, then gently twinkles
      final appear = ((t - phase * 0.5) * 3).clamp(0.0, 1.0);
      if (appear == 0) continue;
      final twinkle = 0.55 + 0.45 * math.sin((t * 6 + phase * 10) * math.pi);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = SamrahColors.onTable.withValues(alpha: 0.6 * appear * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

/// An opening brass ring that fades as it grows.
class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    canvas.drawCircle(c, 40 + 150 * t, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * fade + 1
      ..color = SamrahColors.accent.withValues(alpha: fade));
    canvas.drawCircle(
      c,
      90 * (0.4 + t),
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFE3A6).withValues(alpha: 0.8 * fade), const Color(0x00FFE3A6)])
            .createShader(Rect.fromCircle(center: c, radius: 90 * (0.4 + t))),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
