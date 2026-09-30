// A card on the table with motion: it flies in from the player who threw it
// (a slight spin and grow, settling at a small resting tilt so the trick looks
// hand-thrown), and once the trick is decided it slides to the winner and
// fades. Key each one by its card code so a new card gets a new flight.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      child: PlayingCardView(code: widget.code, width: w, highlight: widget.highlight),
    );
  }
}
