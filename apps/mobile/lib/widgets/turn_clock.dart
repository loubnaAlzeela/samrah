// Turn countdown from server time (turnDeadline - serverNow), ticked locally
// so the device clock is never trusted. Shared by the Tarneeb and Trix
// table screens.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/room_view.dart';
import '../services/game_audio.dart';
import '../services/sound.dart';

mixin TurnClock<T extends StatefulWidget> on State<T> {
  Timer? _tick;
  int? _deadlineKey;
  int _totalMs = 1;
  int? _msAtReceive;
  DateTime _receivedAt = DateTime.now();
  RoomView? _view;
  int? _lastTickSecond;

  /// Call from initState.
  void startClock(RoomView v) {
    syncClock(v);
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _msAtReceive != null) setState(() {});
      _warn();
    });
  }

  /// Call whenever a new view arrives.
  void syncClock(RoomView v) {
    _view = v;
    _receivedAt = DateTime.now();
    _msAtReceive = v.turnDeadline == null ? null : (v.turnDeadline! - v.serverNow).clamp(0, 1 << 31);
    if (v.turnDeadline != _deadlineKey) {
      _deadlineKey = v.turnDeadline;
      _totalMs = (_msAtReceive ?? 1).clamp(1, 1 << 31);
    }
  }

  void stopClock() => _tick?.cancel();

  /// A soft tick each second of the last five of my own turn.
  void _warn() {
    final v = _view;
    final m = msLeft;
    if (v == null || m == null || m <= 0 || m > 5000 || !isMyTurn(v)) return;
    final sec = (m / 1000).ceil();
    if (sec == _lastTickSecond) return;
    _lastTickSecond = sec;
    Sound.instance.play(Sfx.tick);
  }

  /// ms left in the current turn, or null when nobody is to act.
  int? get msLeft {
    final m = _msAtReceive;
    if (m == null) return null;
    return (m - DateTime.now().difference(_receivedAt).inMilliseconds).clamp(0, m);
  }

  /// Share of the turn still left, 0..1 (drives the avatar ring).
  double get turnFrac {
    final m = msLeft;
    return m == null ? 0 : m / _totalMs;
  }
}
