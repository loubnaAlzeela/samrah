// The room connection the screens use, over our own pure-Dart Colyseus client
// (colyseus_lite.dart). The native `package:colyseus` could not resolve host
// names on Android, so it is no longer used.
//
// LammaRoom (apps/server/src/LammaRoom.ts) never calls Colyseus's schema
// `setState()` — every message is plain JSON via `client.send`/
// `room.onMessage`. So this layer only needs message-type listeners, no generated
// schema classes.
//
// Reconnection: LammaRoom does NOT use Colyseus's built-in
// `allowReconnection()` — it holds a disconnected seat itself
// (`RECONNECT_SECONDS`) and lets the same client rejoin by sending its own
// `token` (from the `welcome` message) back in the `joinById` options. So
// this layer drives its own retry loop, with the same token.
import 'dart:async';

import 'colyseus_lite.dart';

import '../models/room_view.dart';

enum ConnStatus { connecting, connected, reconnecting, closed }

/// One live connection to a "lamma" room. Screens talk to this, never to
/// the transport directly.
class RoomConnection {
  RoomConnection._(this._client, String code, this._playerName) : _code = code;

  final ColyseusLite _client;
  final String _code;
  final String _playerName;
  LiteRoom? _room;
  String? _token;
  bool _closedByUs = false;
  StreamSubscription? _leaveSub;

  final _stateCtrl = StreamController<RoomView>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _statusCtrl = StreamController<ConnStatus>.broadcast();

  /// The room code the server assigned (shown to the player to share).
  String get code => _room?.id ?? _code;

  ConnStatus status = ConnStatus.connecting;

  /// Fires on every `state` broadcast from the server.
  Stream<RoomView> get onState => _stateCtrl.stream;

  /// Fires on every `error` message, e.g. `{error: "badBid"}`.
  Stream<String> get onError => _errorCtrl.stream;

  /// Fires when the connection status changes (connected / reconnecting / closed for good).
  Stream<ConnStatus> get onStatus => _statusCtrl.stream;

  Future<void> _attach(LiteRoom room) async {
    _room = room;
    room.onMessage('welcome').listen((m) {
      final token = (m as Map)['token'] as String?;
      if (token != null) _token = token;
    });
    room.onMessage('state').listen((m) => _stateCtrl.add(RoomView.fromJson(m as Map)));
    room.onMessage('error').listen((m) => _errorCtrl.add((m as Map)['error']?.toString() ?? 'unknown'));
    unawaited(_leaveSub?.cancel());
    _leaveSub = room.onLeave.listen(_onLeave);
    status = ConnStatus.connected;
    _statusCtrl.add(status);
  }

  void _onLeave(int code) {
    _room = null;
    if (_closedByUs) return;
    // App-level close codes the server sends on purpose (see protocol.ts):
    // replaced by another tab, room filled without this seat, or kicked.
    // None of these are recoverable by rejoining.
    const fatalCodes = {4001, 4002, 4003};
    if (fatalCodes.contains(code)) {
      status = ConnStatus.closed;
      _statusCtrl.add(status);
      return;
    }
    unawaited(_reconnectLoop());
  }

  /// Rejoin with the seat token the server handed us in `welcome`: retry
  /// every 2s for up to 100s
  /// (under the server's 90s seat-hold window), then give up.
  Future<void> _reconnectLoop() async {
    status = ConnStatus.reconnecting;
    _statusCtrl.add(status);
    final deadline = DateTime.now().add(const Duration(seconds: 100));
    while (!_closedByUs && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 2));
      if (_closedByUs) return;
      try {
        final room = await _client.joinById(_code, options: {'name': _playerName, if (_token != null) 'token': _token});
        await _attach(room);
        return;
      } catch (_) {
        // keep retrying: network hiccup, or the server isn't back yet
      }
    }
    if (!_closedByUs) {
      status = ConnStatus.closed;
      _statusCtrl.add(status);
    }
  }

  void send(String type, [Object? data]) => _room?.send(type, data);

  Future<void> leave() async {
    _closedByUs = true;
    await _leaveSub?.cancel();
    await _room?.leave();
    _room = null;
  }
}

/// Connects to the game server and opens "lamma" rooms.
class GameServerClient {
  GameServerClient(String endpoint) : _client = ColyseusLite(endpoint);
  final ColyseusLite _client;

  /// Creates a new room and returns the live connection to it.
  /// [settings] is a partial `RoomSettings` (packages/rules/src/protocol.ts);
  /// the server merges it over its defaults and rejects invalid values.
  Future<RoomConnection> openRoom({required String playerName, String variant = 'tarneeb', Map<String, Object?>? settings}) async {
    final room = await _client.create('lamma', options: {'variant': variant, 'name': playerName, 'settings': ?settings});
    final conn = RoomConnection._(_client, room.id, playerName);
    await conn._attach(room);
    return conn;
  }

  void dispose() => _client.dispose();
}
