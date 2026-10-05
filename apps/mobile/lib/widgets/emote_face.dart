// The store's emotes: Samrah's own round mascot (the same coin look as the «وحدات» icon — see UnitIcon in
// store_screen.dart), one fixed colour, pulling one of its faces. One painter draws any face, no image files,
// no colour picks to buy — just the expression; everything is laid out on a 100×100 grid and scaled to the size
// asked. There is no cast of named characters — just the one mascot.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The mascot's one fixed colour (the store's brand orange).
const _mascotColor = Color(0xFFC8650C);
const _mascotRim = Color(0xFFFFD2A0);

/// One face.
class EmoteFaceDef {
  const EmoteFaceDef(this.id, this.label, this.price);
  final String id;
  final String label;
  final int price;
}

// The server keeps the same list, with the same ids and prices (apps/server/src/accounts.ts).
const kEmoteFaces = [
  EmoteFaceDef('laugh', 'يضحك', 0),
  EmoteFaceDef('wink', 'يغمز', 300),
  EmoteFaceDef('shock', 'مصدوم', 300),
  EmoteFaceDef('cry', 'يبكي', 300),
  EmoteFaceDef('sleep', 'نعسان', 300),
  EmoteFaceDef('think', 'يفكّر', 300),
  EmoteFaceDef('nervous', 'متوتر', 300),
  EmoteFaceDef('angry', 'معصّب', 400),
  EmoteFaceDef('tease', 'يمزح', 400),
  EmoteFaceDef('cool', 'واثق', 600),
  EmoteFaceDef('love', 'معجب', 600),
  EmoteFaceDef('star', 'مبهور', 600),
  EmoteFaceDef('sad', 'حزين', 300),
  EmoteFaceDef('bored', 'زهقان', 300),
  EmoteFaceDef('shy', 'خجلان', 400),
  EmoteFaceDef('surprised', 'متفاجئ', 400),
  EmoteFaceDef('proud', 'فخور', 400),
  EmoteFaceDef('dizzy', 'دايخ', 600),
  EmoteFaceDef('clap', 'يصفّق', 600),
  EmoteFaceDef('thumbsup', 'تمام', 600),
  EmoteFaceDef('strong', 'قوي', 800),
  EmoteFaceDef('kiss', 'بوسة', 800),
];

EmoteFaceDef emoteFaceDef(String id) => kEmoteFaces.firstWhere((f) => f.id == id, orElse: () => kEmoteFaces.first);

/// An emote by its store id (`emo_<face>`).
class EmoteFace extends StatelessWidget {
  const EmoteFace({super.key, required this.id, required this.size});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = id.split('_');
    final f = parts.length > 1 ? parts[1] : 'laugh';
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EmotePainter(f)),
    );
  }
}

// ── the drawing ──────────────────────────────────────────────────────────────

const _ink = Color(0xFF2B1F1A);
const _cx = 50.0;
const _cy = 53.0;
const _r = 34.0;

enum _Eyes { open, wide, up, happy, closed, wink, angry, hearts, stars, small }

enum _Brows { normal, raised, angry, sad, oneUp }

enum _Mouth { smile, laugh, o, frown, wobbly, smirk, tongue, grimace, grin, flat }

class _Face {
  const _Face(this.eyes, this.brows, this.mouth, {this.shades = false, this.props = const []});
  final _Eyes eyes;
  final _Brows brows;
  final _Mouth mouth;
  final bool shades;
  final List<String> props;
}

const _faces = {
  'laugh': _Face(_Eyes.happy, _Brows.raised, _Mouth.laugh, props: ['joy']),
  'wink': _Face(_Eyes.wink, _Brows.normal, _Mouth.smirk),
  'shock': _Face(_Eyes.wide, _Brows.raised, _Mouth.o, props: ['sweat']),
  'cry': _Face(_Eyes.closed, _Brows.sad, _Mouth.wobbly, props: ['tears']),
  'sleep': _Face(_Eyes.closed, _Brows.normal, _Mouth.o, props: ['zzz']),
  'think': _Face(_Eyes.up, _Brows.oneUp, _Mouth.flat, props: ['question']),
  'nervous': _Face(_Eyes.small, _Brows.sad, _Mouth.grimace, props: ['sweat', 'sweat2']),
  'angry': _Face(_Eyes.angry, _Brows.angry, _Mouth.grimace, props: ['red', 'vein']),
  'tease': _Face(_Eyes.wink, _Brows.raised, _Mouth.tongue),
  'cool': _Face(_Eyes.open, _Brows.normal, _Mouth.smirk, shades: true, props: ['glint']),
  'love': _Face(_Eyes.hearts, _Brows.raised, _Mouth.smile, props: ['blush', 'hearts']),
  'star': _Face(_Eyes.stars, _Brows.raised, _Mouth.grin, props: ['sparkles']),
  'sad': _Face(_Eyes.closed, _Brows.sad, _Mouth.frown),
  'bored': _Face(_Eyes.small, _Brows.normal, _Mouth.flat),
  'shy': _Face(_Eyes.happy, _Brows.normal, _Mouth.smirk, props: ['blush']),
  'surprised': _Face(_Eyes.wide, _Brows.raised, _Mouth.grin),
  'proud': _Face(_Eyes.open, _Brows.raised, _Mouth.grin),
  'dizzy': _Face(_Eyes.wide, _Brows.oneUp, _Mouth.wobbly, props: ['swirl']),
  'clap': _Face(_Eyes.happy, _Brows.raised, _Mouth.grin, props: ['claps']),
  'thumbsup': _Face(_Eyes.open, _Brows.normal, _Mouth.smile, props: ['thumb']),
  'strong': _Face(_Eyes.open, _Brows.angry, _Mouth.smirk, props: ['muscle']),
  'kiss': _Face(_Eyes.closed, _Brows.raised, _Mouth.o, props: ['kissmark']),
};

class _EmotePainter extends CustomPainter {
  _EmotePainter(this.faceId);
  final String faceId;

  late final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  Paint _fill(Color color) => Paint()..color = color;

  Paint _stroke(Color color, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  Color _shade(Color c, double by) => Color.lerp(c, Colors.black, by)!;
  Color _tint(Color c, double by) => Color.lerp(c, Colors.white, by)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 100, 100));
    final f = _faces[faceId] ?? _faces['laugh']!;
    const center = Offset(_cx, _cy);

    // a round coin, like the «وحدات» mark
    canvas.drawCircle(const Offset(_cx, _cy + 2), _r, _fill(const Color(0x33000000)));
    final coin = Paint()
      ..shader = RadialGradient(colors: [_tint(_mascotColor, 0.3), _mascotColor, _shade(_mascotColor, 0.25)], stops: const [0, 0.6, 1], center: const Alignment(-0.3, -0.4))
          .createShader(Rect.fromCircle(center: center, radius: _r));
    canvas.drawCircle(center, _r, coin);
    if (f.props.contains('red')) canvas.drawCircle(center, _r, _fill(const Color(0x40E0302A)));
    canvas.drawCircle(center, _r, _stroke(_mascotRim, _r * 0.1));
    canvas.drawCircle(center, _r, _outline);

    if (f.props.contains('blush')) {
      for (final x in [36.0, 64.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, 64), width: 8, height: 4.5), _fill(const Color(0x66FF6B81)));
      }
    }
    final brow = _tint(_mascotColor, 0.72);
    _brows(canvas, f.brows, brow);
    if (f.shades) {
      _shades(canvas);
    } else {
      _eye(canvas, 41, 53, f.eyes, left: true);
      _eye(canvas, 59, 53, f.eyes == _Eyes.wink ? _Eyes.happy : f.eyes, left: false);
      if (f.eyes == _Eyes.wink) _eye(canvas, 41, 53, _Eyes.open, left: true);
    }
    _mouth(canvas, f.mouth);
    for (final p in f.props) {
      _prop(canvas, p);
    }
    canvas.restore();
  }

  // ── the face ───────────────────────────────────────────────────────────────

  void _brows(Canvas canvas, _Brows kind, Color color) {
    for (final left in [true, false]) {
      final x = left ? 41.0 : 59.0;
      final s = left ? 1.0 : -1.0; // inner end is towards the middle
      var y = 44.0;
      var inner = 0.0; // + = inner end lower
      switch (kind) {
        case _Brows.normal:
          break;
        case _Brows.raised:
          y = 41;
        case _Brows.angry:
          inner = 3.5;
        case _Brows.sad:
          inner = -3;
        case _Brows.oneUp:
          if (!left) y = 40.5;
      }
      final outer = Offset(x - 5 * s, y + (inner > 0 ? -1 : 1));
      final inn = Offset(x + 5 * s, y + inner);
      canvas.drawPath(
        Path()
          ..moveTo(outer.dx, outer.dy)
          ..quadraticBezierTo(x, y - 2.5 + inner / 2, inn.dx, inn.dy),
        _stroke(color, 2.4),
      );
    }
  }

  void _eye(Canvas canvas, double x, double y, _Eyes kind, {required bool left}) {
    final white = _fill(Colors.white);
    void openEye({double rx = 5, double ry = 6, double pr = 2.8, Offset look = Offset.zero}) {
      final r = Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2);
      canvas.drawOval(r, white);
      canvas.drawOval(r, _outline);
      canvas.drawCircle(Offset(x, y + 0.6) + look, pr, _fill(_ink));
      canvas.drawCircle(Offset(x + 0.9, y - 0.6) + look, pr * 0.32, white);
    }

    switch (kind) {
      case _Eyes.open:
      case _Eyes.wink:
        openEye();
      case _Eyes.wide:
        openEye(rx: 6, ry: 7.2, pr: 2);
      case _Eyes.small:
        openEye(pr: 1.6);
      case _Eyes.up:
        openEye(look: const Offset(1.2, -2.6));
      case _Eyes.happy:
        canvas.drawPath(Path()..moveTo(x - 5, y + 1.5)..quadraticBezierTo(x, y - 6, x + 5, y + 1.5), _stroke(_ink, 2.2));
      case _Eyes.closed:
        canvas.drawPath(Path()..moveTo(x - 5, y - 0.5)..quadraticBezierTo(x, y + 4.5, x + 5, y - 0.5), _stroke(_ink, 2.2));
      case _Eyes.angry:
        openEye(pr: 2.4);
        final s = left ? 1.0 : -1.0;
        final lid = Path()
          ..moveTo(x - 7 * s, y - 8)
          ..lineTo(x + 7 * s, y - 8)
          ..lineTo(x + 7 * s, y - 0.5)
          ..lineTo(x - 7 * s, y - 5)
          ..close();
        canvas.drawPath(lid, _fill(_mascotColor));
        canvas.drawLine(Offset(x - 5.5 * s, y - 4.6), Offset(x + 5.5 * s, y - 1), _stroke(_ink, 1.6));
      case _Eyes.hearts:
        _heart(canvas, Offset(x, y), 6.5, const Color(0xFFE5304B));
      case _Eyes.stars:
        _star(canvas, Offset(x, y), 6.5, const Color(0xFFF2C230));
    }
  }

  void _shades(Canvas canvas) {
    final lens = Paint()..color = const Color(0xFF151515);
    for (final x in [41.0, 59.0]) {
      final r = RRect.fromLTRBR(x - 7.5, 48, x + 7.5, 58, const Radius.circular(4));
      canvas.drawRRect(r, lens);
    }
    canvas.drawLine(const Offset(33.5, 50), const Offset(66.5, 50), _stroke(const Color(0xFF151515), 2.4));
  }

  void _mouth(Canvas canvas, _Mouth kind) {
    const y = 69.0;
    final dark = _fill(const Color(0xFF5A1E1E));
    switch (kind) {
      case _Mouth.smile:
        canvas.drawPath(Path()..moveTo(43, y - 1)..quadraticBezierTo(50, y + 5, 57, y - 1), _stroke(_ink, 2));
      case _Mouth.smirk:
        canvas.drawPath(Path()..moveTo(44, y)..quadraticBezierTo(52, y + 3, 57, y - 3), _stroke(_ink, 2));
      case _Mouth.flat:
        canvas.drawLine(const Offset(45, y + 1), const Offset(55, y), _stroke(_ink, 2));
      case _Mouth.frown:
        canvas.drawPath(Path()..moveTo(44, y + 2)..quadraticBezierTo(50, y - 3, 56, y + 2), _stroke(_ink, 2));
      case _Mouth.o:
        final r = Rect.fromCenter(center: const Offset(50, y + 1), width: 6.5, height: 7.5);
        canvas.drawOval(r, dark);
        canvas.drawOval(r, _outline);
      case _Mouth.laugh:
      case _Mouth.grin:
        final wide = kind == _Mouth.laugh ? 9.0 : 8.0;
        final deep = kind == _Mouth.laugh ? 10.0 : 7.0;
        final p = Path()
          ..moveTo(50 - wide, y - 2)
          ..quadraticBezierTo(50, y - 3.5, 50 + wide, y - 2)
          ..quadraticBezierTo(50 + wide, y + deep, 50, y + deep)
          ..quadraticBezierTo(50 - wide, y + deep, 50 - wide, y - 2)
          ..close();
        canvas.drawPath(p, dark);
        canvas.save();
        canvas.clipPath(p);
        canvas.drawRect(Rect.fromLTRB(40, y - 4, 60, y + 1.2), _fill(Colors.white));
        if (kind == _Mouth.laugh) canvas.drawOval(Rect.fromCenter(center: Offset(50, y + deep), width: 11, height: 8), _fill(const Color(0xFFE5677A)));
        canvas.restore();
        canvas.drawPath(p, _outline);
      case _Mouth.wobbly:
        final p = Path()
          ..moveTo(42, y + 4)
          ..quadraticBezierTo(44, y - 3, 50, y - 2)
          ..quadraticBezierTo(56, y - 3, 58, y + 4)
          ..quadraticBezierTo(50, y + 1, 42, y + 4)
          ..close();
        canvas.drawPath(p, dark);
        canvas.drawPath(p, _outline);
      case _Mouth.tongue:
        canvas.drawPath(Path()..moveTo(43, y - 1)..quadraticBezierTo(50, y + 4, 57, y - 1), _stroke(_ink, 2));
        final t = RRect.fromLTRBR(46.5, y + 1, 54.5, y + 9, const Radius.circular(4));
        canvas.drawRRect(t, _fill(const Color(0xFFE5677A)));
        canvas.drawRRect(t, _outline);
        canvas.drawLine(Offset(50.5, y + 2.5), Offset(50.5, y + 6), _stroke(const Color(0xFFC04558), 1));
      case _Mouth.grimace:
        final r = RRect.fromLTRBR(41, y - 3, 59, y + 4, const Radius.circular(3));
        canvas.drawRRect(r, _fill(Colors.white));
        canvas.drawLine(Offset(41, y + 0.5), Offset(59, y + 0.5), _stroke(_ink, 1));
        for (final x in [45.5, 50.0, 54.5]) {
          canvas.drawLine(Offset(x, y - 3), Offset(x, y + 4), _stroke(_ink, 1));
        }
        canvas.drawRRect(r, _outline);
    }
  }

  // ── around the face ────────────────────────────────────────────────────────

  void _prop(Canvas canvas, String p) {
    const blue = Color(0xFF5BB8F5);
    switch (p) {
      case 'joy':
        for (final (o, a) in [(const Offset(26, 50), -0.6), (const Offset(74, 50), 0.6)]) {
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(a);
          _drop(canvas, Offset.zero, 3.6, blue);
          canvas.restore();
        }
      case 'tears':
        for (final x in [40.0, 60.0]) {
          final t = Path()
            ..moveTo(x - 2, 56)
            ..lineTo(x - 3, 74)
            ..quadraticBezierTo(x, 78, x + 3, 74)
            ..lineTo(x + 2, 56)
            ..close();
          canvas.drawPath(t, _fill(blue.withValues(alpha: 0.85)));
        }
      case 'sweat':
        _drop(canvas, const Offset(76, 32), 4.4, blue);
      case 'sweat2':
        _drop(canvas, const Offset(22, 38), 3.4, blue);
      case 'zzz':
        _text(canvas, 'z', const Offset(76, 22), 10);
        _text(canvas, 'z', const Offset(85, 12), 13);
        _text(canvas, 'Z', const Offset(93, 0), 16);
      case 'question':
        _text(canvas, '؟', const Offset(80, 16), 18, color: const Color(0xFFFA8112));
      case 'vein':
        final v = _stroke(const Color(0xFFD7263D), 2.4);
        const o = Offset(76, 26);
        for (final a in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
          final d = Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4));
          canvas.drawPath(Path()..moveTo(o.dx + d.dx * 1.5, o.dy + d.dy * 1.5)..quadraticBezierTo(o.dx + d.dx * 4 + d.dy * 2, o.dy + d.dy * 4 - d.dx * 2, o.dx + d.dx * 6, o.dy + d.dy * 6), v);
        }
      case 'glint':
        _sparkle(canvas, const Offset(55, 50), 4, Colors.white);
      case 'hearts':
        _heart(canvas, const Offset(84, 22), 6.5, const Color(0xFFE5304B));
        _heart(canvas, const Offset(13, 30), 5, const Color(0xFFFF6B81));
      case 'sparkles':
        _sparkle(canvas, const Offset(86, 20), 6.5, const Color(0xFFF2C230));
        _sparkle(canvas, const Offset(12, 32), 5, const Color(0xFFF2C230));
        _sparkle(canvas, const Offset(88, 46), 4, const Color(0xFFFFE08A));
      case 'swirl':
        _spiral(canvas, const Offset(50, 15), 8, blue);
      case 'claps':
        _hand(canvas, const Offset(19, 70), true);
        _hand(canvas, const Offset(81, 70), false);
        for (final o in [const Offset(35, 64), const Offset(50, 60), const Offset(65, 64)]) {
          _sparkle(canvas, o, 2.6, const Color(0xFFFFE08A));
        }
      case 'thumb':
        _thumbUp(canvas, const Offset(83, 68));
      case 'muscle':
        _bicep(canvas, const Offset(16, 58));
      case 'kissmark':
        _heart(canvas, const Offset(50, 87), 5, const Color(0xFFFF6B81));
        _heart(canvas, const Offset(80, 32), 4, const Color(0xFFFF93A8));
    }
  }

  void _spiral(Canvas canvas, Offset o, double r, Color color) {
    final p = Path();
    for (var i = 0; i <= 54; i++) {
      final t = i / 54.0;
      final a = t * math.pi * 3;
      final rad = t * r;
      final pt = Offset(o.dx + math.cos(a) * rad, o.dy + math.sin(a) * rad);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p, _stroke(color, 1.6));
  }

  void _hand(Canvas canvas, Offset o, bool left) {
    final s = left ? 1.0 : -1.0;
    final cream = _fill(const Color(0xFFFAF3E1));
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 10, height: 13), const Radius.circular(5));
    canvas.drawRRect(r, cream);
    canvas.drawRRect(r, _outline);
    canvas.drawCircle(Offset(o.dx + 6 * s, o.dy + 2), 3, cream);
    canvas.drawCircle(Offset(o.dx + 6 * s, o.dy + 2), 3, _outline);
  }

  void _thumbUp(Canvas canvas, Offset o) {
    final cream = _fill(const Color(0xFFFAF3E1));
    final fist = RRect.fromRectAndRadius(Rect.fromCenter(center: o + const Offset(0, 4), width: 9, height: 8), const Radius.circular(3));
    canvas.drawRRect(fist, cream);
    canvas.drawRRect(fist, _outline);
    final thumb = RRect.fromRectAndRadius(Rect.fromCenter(center: o + const Offset(-1, -4), width: 4, height: 8), const Radius.circular(2));
    canvas.drawRRect(thumb, cream);
    canvas.drawRRect(thumb, _outline);
  }

  void _bicep(Canvas canvas, Offset o) {
    final tone = _tint(_mascotColor, 0.25);
    final p = Path()
      ..moveTo(o.dx - 6, o.dy + 10)
      ..quadraticBezierTo(o.dx - 10, o.dy - 2, o.dx, o.dy - 9)
      ..quadraticBezierTo(o.dx + 9, o.dy - 6, o.dx + 6, o.dy + 2)
      ..quadraticBezierTo(o.dx + 4, o.dy + 8, o.dx - 6, o.dy + 10)
      ..close();
    canvas.drawPath(p, _fill(tone));
    canvas.drawPath(p, _outline);
  }

  void _drop(Canvas canvas, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r * 1.8)
      ..quadraticBezierTo(o.dx + r * 1.2, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r * 1.2, o.dy, o.dx, o.dy - r * 1.8)
      ..close();
    canvas.drawPath(p, _fill(color));
    canvas.drawPath(p, _stroke(_shade(color, 0.3), 0.8));
  }

  void _heart(Canvas canvas, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r)
      ..cubicTo(o.dx - r * 1.6, o.dy - r * 0.2, o.dx - r * 0.7, o.dy - r * 1.3, o.dx, o.dy - r * 0.4)
      ..cubicTo(o.dx + r * 0.7, o.dy - r * 1.3, o.dx + r * 1.6, o.dy - r * 0.2, o.dx, o.dy + r)
      ..close();
    canvas.drawPath(p, _fill(color));
    canvas.drawPath(p, _stroke(_shade(color, 0.35), 1));
  }

  void _star(Canvas canvas, Offset o, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final d = i.isEven ? r : r * 0.45;
      final pt = Offset(o.dx + math.cos(a) * d, o.dy + math.sin(a) * d);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(p, _fill(color));
    canvas.drawPath(p, _stroke(_shade(color, 0.35), 1));
  }

  void _sparkle(Canvas canvas, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    canvas.drawPath(p, _fill(color));
  }

  void _text(Canvas canvas, String t, Offset o, double size, {Color color = const Color(0xFF5B6BD6)}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_EmotePainter old) => old.faceId != faceId;
}
