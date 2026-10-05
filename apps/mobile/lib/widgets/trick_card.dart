// A card on the table with motion: it flies in from the player who threw it
// (a slight spin and grow, settling at a small resting tilt so the trick looks
// hand-thrown), and once the trick is decided it slides to the winner and
// fades. Key each one by its card code so a new card gets a new flight. A
// player who wears a «ضربة» from the store gets its burst as the card lands.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/store.dart';
import 'playing_card_view.dart';

class TrickCard extends StatefulWidget {
  const TrickCard({
    required super.key,
    required this.code,
    required this.from,
    required this.to,
    required this.width,
    this.highlight = false,
    this.collectTo,
    this.hit,
  });

  final String code;

  /// centre where the throw starts (the player's seat / my hand)
  final Offset from;

  /// centre of the card's place in the trick
  final Offset to;
  final double width;

  /// the card winning the finished trick
  final bool highlight;

  /// the trick is decided: slide to this centre (the winner) and fade
  final Offset? collectTo;

  /// the thrower's card-play effect (null or none = no burst)
  final HitStyle? hit;

  /// how long a winning trick stays in place before it is gathered
  static const collectDelay = Duration(milliseconds: 550);

  @override
  State<TrickCard> createState() => _TrickCardState();
}

class _TrickCardState extends State<TrickCard> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))..forward();
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Timer? _wait;

  /// stable per card, so a card never jitters on a rebuild
  late final double _rest = ((widget.code.hashCode % 9) - 4) * 0.018;
  late final double _spin = (widget.code.hashCode.isEven ? 1 : -1) * 0.5;

  /// thrown now (not already collecting when first built)
  late final bool _fresh = widget.collectTo == null;

  @override
  void initState() {
    super.initState();
    if (widget.collectTo != null) _scheduleCollect();
  }

  @override
  void didUpdateWidget(TrickCard old) {
    super.didUpdateWidget(old);
    if (widget.collectTo != null && old.collectTo == null) _scheduleCollect();
    if (widget.collectTo == null && old.collectTo != null) {
      _wait?.cancel();
      _out.value = 0;
    }
  }

  void _scheduleCollect() {
    _wait?.cancel();
    _wait = Timer(TrickCard.collectDelay, () {
      if (mounted) _out.forward();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * PlayingCardView.aspect;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_in.value);
        final u = Curves.easeInCubic.transform(_out.value);
        var pos = Offset.lerp(widget.from, widget.to, t)!;
        if (widget.collectTo != null) pos = Offset.lerp(pos, widget.collectTo!, u)!;
        // a small arc: the card rises a little mid-flight
        final arc = math.sin(t * math.pi) * 18;
        final scale = (0.72 + 0.28 * t) * (1 - 0.45 * u);
        final angle = _rest + _spin * (1 - t);
        return Positioned(
          left: pos.dx - w / 2,
          top: pos.dy - h / 2 - arc - (widget.highlight && u == 0 ? 4 : 0),
          child: Opacity(
            opacity: (1 - u).clamp(0.0, 1.0),
            child: Transform.rotate(angle: angle, child: Transform.scale(scale: scale, child: child)),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          PlayingCardView(code: widget.code, width: w, highlight: widget.highlight),
          // the burst starts as the card lands; a card already on the table when the screen opens does not burst
          if (widget.hit != null && !widget.hit!.none && _fresh)
            Positioned(
              left: -w * 0.6,
              top: h / 2 - w * 1.1,
              width: w * 2.2,
              height: w * 2.2,
              child: IgnorePointer(child: HitBurst(style: widget.hit!, size: w * 2.2, delay: const Duration(milliseconds: 260))),
            ),
        ],
      ),
    );
  }
}

/// A card-play effect once: a ring of the style's colour widening from the
/// centre and, with a glyph, eight of them thrown outwards and fading. Also the
/// store's preview ([loop]).
class HitBurst extends StatefulWidget {
  const HitBurst({super.key, required this.style, required this.size, this.delay = Duration.zero, this.loop = false});
  final HitStyle style;
  final double size;
  final Duration delay;
  final bool loop;

  @override
  State<HitBurst> createState() => _HitBurstState();
}

class _HitBurstState extends State<HitBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, _play);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && widget.loop) _start = Timer(const Duration(milliseconds: 900), _play);
    });
  }

  void _play() {
    if (mounted) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final st = widget.style;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          final e = Curves.easeOutCubic.transform(t);
          final fade = (1 - t).clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: s * (0.3 + 0.7 * e),
                height: s * (0.3 + 0.7 * e),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: st.color.withValues(alpha: fade), width: 3 * fade + 1)),
              ),
              if (st.glyph != null)
                for (var i = 0; i < 8; i++)
                  Transform.translate(
                    offset: Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4)) * (s * 0.48 * e),
                    child: Opacity(
                      opacity: fade,
                      child: Text(st.glyph!, style: TextStyle(color: st.color, fontSize: s * 0.13 * (0.6 + 0.4 * (1 - e)), height: 1)),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
