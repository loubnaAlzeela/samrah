// Shared motion vocabulary, so the whole app moves the same way:
//  - PopIn: a panel / chip / card appears (fade + slight grow), optionally delayed.
//  - EnterFrom: an item slides into place and fades in; stagger lists with `delay`.
//  - CountUp: a number rolls to its new value instead of jumping.
//  - Breathe: a gentle looping pulse (whose turn it is, a waiting state).
//  - Pressable: shrinks a touch while pressed, springs back on release.
//  - FadeSlidePageTransitionsBuilder: every page change fades and rises.
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';

import '../services/sound.dart';

/// Durations and curves used everywhere.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 480);
  static const curve = Curves.easeOutCubic;

  /// Gap between items of a staggered list.
  static Duration stagger(int i, {int stepMs = 55, int maxSteps = 10}) => Duration(milliseconds: stepMs * i.clamp(0, maxSteps));
}

/// Runs [controller] forward after [delay] (none = at once), unless disposed first.
mixin _Delayed<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController controller = AnimationController(vsync: this, duration: duration);
  Timer? _timer;
  Duration get duration;
  Duration get delay;

  void startAfterDelay() {
    if (delay == Duration.zero) {
      controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }
}

/// Fades in while growing from [from] to full size.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.duration = Motion.normal, this.from = 0.86});
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double from;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with TickerProviderStateMixin, _Delayed {
  @override
  Duration get duration => widget.duration;
  @override
  Duration get delay => widget.delay;

  @override
  void initState() {
    super.initState();
    startAfterDelay();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: controller, curve: Curves.easeOutBack);
    final f = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: f,
      child: ScaleTransition(scale: Tween(begin: widget.from, end: 1.0).animate(a), child: widget.child),
    );
  }
}

/// Slides in from [offset] (in logical pixels) and fades in.
class EnterFrom extends StatefulWidget {
  const EnterFrom({super.key, required this.child, this.offset = const Offset(0, 24), this.delay = Duration.zero, this.duration = Motion.slow});
  final Widget child;
  final Offset offset;
  final Duration delay;
  final Duration duration;

  @override
  State<EnterFrom> createState() => _EnterFromState();
}

class _EnterFromState extends State<EnterFrom> with TickerProviderStateMixin, _Delayed {
  @override
  Duration get duration => widget.duration;
  @override
  Duration get delay => widget.delay;

  @override
  void initState() {
    super.initState();
    startAfterDelay();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Motion.curve.transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: widget.offset * (1 - t), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// A number that rolls to its new value (never animates on first show).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.format});
  final int value;
  final TextStyle? style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value.toDouble(), end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format?.call(n) ?? '$n', style: style);
      },
    );
  }
}

/// A slow grow-and-shrink loop while [active].
class Breathe extends StatefulWidget {
  const Breathe({super.key, required this.child, this.active = true, this.amount = 0.06, this.period = const Duration(milliseconds: 1100)});
  final Widget child;
  final bool active;
  final double amount;
  final Duration period;

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(Breathe old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) _c.animateTo(0, duration: Motion.fast);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value), child: child),
      child: widget.child,
    );
  }
}

/// Shrinks slightly while a finger is down on it. Does not handle the tap
/// itself: wrap a button / InkWell that does.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.96});
  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        _set(true);
        Sound.instance.play(Sfx.tap);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: Motion.fast, curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Page changes: the new page fades in while rising a little; the old one
/// fades back slightly.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final inT = CurvedAnimation(parent: animation, curve: Motion.curve, reverseCurve: Curves.easeInCubic);
    final outT = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(outT),
      child: FadeTransition(
        opacity: inT,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(inT), child: SamrahBackdrop(child: child)),
      ),
    );
  }
}

/// The same [Positioned] panel, appearing with a [PopIn] (Positioned must stay the Stack's direct child).
Positioned popInPositioned(Positioned p) => Positioned(
      left: p.left,
      top: p.top,
      right: p.right,
      bottom: p.bottom,
      width: p.width,
      height: p.height,
      child: PopIn(child: p.child),
    );
