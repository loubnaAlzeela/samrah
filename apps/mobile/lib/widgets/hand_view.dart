// The player's hand: a flat overlapping row across the full width (no fan),
// always left-to-right so each card covers the right side of the previous one
// and every top-left index stays readable. A card is played by dragging it
// with the finger up toward the table and letting go; a short drag springs
// back. Pick mode (187 hand-back, Hand melds) still toggles cards with a tap.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_card.dart';
import 'motion.dart';
import 'playing_card_view.dart';

class HandView extends StatefulWidget {
  const HandView({super.key, required this.cards, required this.trump, required this.legal, required this.onPlay, this.width = 378, this.picked, this.onPick, this.power});

  /// Pick mode (187, handing cards back): when [onPick] is set, a tap toggles
  /// a card instead of playing it, and [picked] cards are shown raised.
  final Set<String>? picked;
  final ValueChanged<String>? onPick;

  final List<String> cards;
  final String? trump;

  /// Strength of a card inside its suit, for games that do not rank by face
  /// value (Baloot); null = plain rank order.
  final int Function(String card)? power;

  /// Cards that may be played now; null when it isn't my turn to play
  /// (no dimming, no dragging).
  final List<String>? legal;
  final ValueChanged<String> onPlay;
  final double width;

  static const double cardWidth = 84;
  static const double height = cardWidth * PlayingCardView.aspect;

  /// How far up (in stage pixels) a card must be dragged to be played.
  static const double playDistance = 70;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  /// the card under the finger and how far it has moved
  String? _dragging;
  Offset _drag = Offset.zero;

  /// played, waiting for the server to take it out of the hand (stays hidden meanwhile)
  String? _sent;
  Timer? _sentTimer;

  /// cards already shown: a card not in here arrives with a motion (dealt, drawn, handed back)
  final Set<String> _seen = {};

  @override
  void dispose() {
    _sentTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(HandView old) {
    super.didUpdateWidget(old);
    if (_sent != null && !widget.cards.contains(_sent)) _sent = null;
    // the turn passed (timeout / autopilot) while a card was in the air
    if (_dragging != null && !_canDrag(_dragging!)) {
      _dragging = null;
      _drag = Offset.zero;
    }
  }

  bool _canDrag(String card) => widget.onPick == null && (widget.legal?.contains(card) ?? false);

  bool _raised(String card) => widget.onPick != null && (widget.picked?.contains(card) ?? false);

  void _end(String card) {
    final played = _drag.dy <= -HandView.playDistance;
    setState(() {
      _dragging = null;
      _drag = Offset.zero;
      if (played) _sent = card;
    });
    if (!played) return;
    widget.onPlay(card);
    // the server refused the card (no new state comes): show it back in the hand
    _sentTimer?.cancel();
    _sentTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _sent == card && widget.cards.contains(card)) setState(() => _sent = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    const cw = HandView.cardWidth;
    final sorted = sortForDisplay(widget.cards, widget.trump, power: widget.power);
    final n = sorted.length;
    final step = n > 1 ? ((widget.width - cw) / (n - 1)).clamp(0.0, 44.0) : 0.0;
    final offset = (widget.width - (cw + step * (n - 1))) / 2;
    final legal = widget.legal;
    // a new round deals many cards at once: they fly in one after another from the middle of the table;
    // a single new card (drawn, a joker taken back) drops in from above
    final fresh = [for (final c in sorted) if (!_seen.contains(c)) c];
    final dealing = fresh.length >= 3;
    _seen
      ..clear()
      ..addAll(sorted);

    Widget cardAt(int i) {
      final c = sorted[i];
      final dragging = _dragging == c;
      final canDrag = _canDrag(c);
      final ready = dragging && _drag.dy <= -HandView.playDistance;
      return AnimatedPositioned(
        key: ValueKey(c),
        // follow the finger exactly; spring back when released short
        duration: dragging ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        left: offset + i * step + (dragging ? _drag.dx : 0),
        top: _raised(c) ? -16 : (dragging ? _drag.dy : 0),
        child: Opacity(
          opacity: _sent == c ? 0 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPick != null ? () => widget.onPick!(c) : null,
            onPanStart: canDrag ? (_) => setState(() => _dragging = c) : null,
            onPanUpdate: canDrag ? (d) => setState(() => _drag += d.delta) : null,
            onPanEnd: canDrag ? (_) => _end(c) : null,
            onPanCancel: canDrag
                ? () => setState(() {
                      _dragging = null;
                      _drag = Offset.zero;
                    })
                : null,
            child: EnterFrom(
              offset: dealing ? Offset(widget.width / 2 - (offset + i * step + cw / 2), -260) : const Offset(0, -70),
              delay: dealing ? Motion.stagger(fresh.indexOf(c), stepMs: 45, maxSteps: 20) : Duration.zero,
              duration: const Duration(milliseconds: 420),
              child: Transform.scale(
                scale: dragging ? 1.08 : 1,
                child: PlayingCardView(
                  code: c,
                  width: cw,
                  dimmed: widget.onPick == null && legal != null && !legal.contains(c),
                  selected: _raised(c) || ready,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // the dragged card is drawn last so it floats above its neighbours
    final order = [for (var i = 0; i < n; i++) if (sorted[i] != _dragging) i, for (var i = 0; i < n; i++) if (sorted[i] == _dragging) i];
    return SizedBox(
      width: widget.width,
      height: HandView.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final i in order) cardAt(i)],
      ),
    );
  }
}
