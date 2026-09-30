// A small, pure-Dart Colyseus 0.18 client: just what this game uses (create /
// join a room by id, JSON-like messages both ways, leave). It replaces the
// native `package:colyseus`, whose own name resolver fails on Android
// ("TemporaryNameServerFailure") for any host name; this client goes through
// dart:io, i.e. the phone's own DNS, TLS certificates and network stack.
//
// Protocol (node_modules/@colyseus/sdk + @colyseus/core):
//   1. POST {http}/matchmake/{create|joinById}/{name|roomId} with the options
//      as JSON -> a seat reservation {name, roomId, sessionId, processId, publicAddress?}.
//   2. WebSocket {ws}/{processId}/{roomId}?sessionId=... (binary frames).
//   3. Server -> JOIN_ROOM (10); the client acknowledges with a single [10] byte.
//   4. Messages both ways: [ROOM_DATA (13)][msgpack type][msgpack payload?].
//      Server errors: [ERROR (11)][code][message]; leave: [LEAVE_ROOM (12)].
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'msgpack.dart';

class _Code {
  static const joinRoom = 10;
  static const error = 11;
  static const leaveRoom = 12;
  static const roomData = 13;

  /// the low 5 bits are the code, the high 3 are modifiers
  static const mask = 0x1f;
}

/// A matchmaking or room error from the server (e.g. a bad name, a full table).
class ColyseusLiteError implements Exception {
  ColyseusLiteError(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => message;
}

class LiteRoom {
  LiteRoom._(this.id, this.sessionId, this._socket);

  /// the room code (players share it to join)
  final String id;
  final String sessionId;
  final WebSocket _socket;
  final _messages = <String, StreamController<Object?>>{};

  /// messages that arrived before anyone listened for their type (the server greets
  /// right after the join, possibly before the app has subscribed): delivered on first listen
  final _early = <String, List<Object?>>{};
  final _leave = StreamController<int>.broadcast();
  bool _left = false;

  /// Messages of one type from the server, e.g. `state`.
  Stream<Object?> onMessage(String type) {
    final c = _messages[type] ??= StreamController<Object?>.broadcast(onListen: () {
      final held = _early.remove(type);
      if (held != null) scheduleMicrotask(() => held.forEach(_messages[type]!.add));
    });
    return c.stream;
  }

  /// Fires once when the connection closes, with the WebSocket close code.
  Stream<int> get onLeave => _leave.stream;

  void send(String type, [Object? payload]) {
    if (_left) return;
    final out = BytesBuilder(copy: false)..addByte(_Code.roomData);
    msgpackEncode(type, out);
    if (payload != null) msgpackEncode(payload, out);
    _socket.add(out.takeBytes());
  }

  Future<void> leave() async {
    if (_left) return;
    try {
      _socket.add(Uint8List.fromList([_Code.leaveRoom]));
    } catch (_) {}
    // the server closes the socket; do not wait for ever
    await _socket.close(1000).timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  void _onFrame(Object? frame, Completer<void> joined) {
    if (frame is! List<int>) return;
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    if (bytes.isEmpty) return;
    final code = bytes[0] & _Code.mask;
    if (code == _Code.joinRoom) {
      // acknowledge; the handshake body (reconnection token, serializer) is not needed here
      _socket.add(Uint8List.fromList([_Code.joinRoom]));
      if (!joined.isCompleted) joined.complete();
    } else if (code == _Code.roomData) {
      final r = MsgpackReader(bytes, 1);
      final type = r.read().toString();
      final payload = r.hasMore ? r.read() : null;
      final c = _messages[type];
      if (c != null && c.hasListener) {
        c.add(payload);
      } else {
        (_early[type] ??= []).add(payload);
      }
    } else if (code == _Code.error) {
      final r = MsgpackReader(bytes, 1);
      final c = r.read();
      final message = r.hasMore ? r.read() : '';
      if (!joined.isCompleted) joined.completeError(ColyseusLiteError(c is int ? c : 0, '$message'));
    } else if (code == _Code.leaveRoom) {
      unawaited(leave());
    }
  }

  void _closed(Completer<void> joined) {
    if (_left) return;
    _left = true;
    final code = _socket.closeCode ?? 1006;
    if (!joined.isCompleted) joined.completeError(ColyseusLiteError(code, 'connection closed (${_socket.closeReason ?? code})'));
    _leave.add(code);
    unawaited(_leave.close());
  }
}

class ColyseusLite {
  /// [endpoint] like `wss://host` or `ws://10.0.2.2:2567`.
  ColyseusLite(String endpoint) : _ws = Uri.parse(endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint);

  final Uri _ws;
  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  Uri get _httpBase => _ws.replace(scheme: _ws.scheme == 'wss' ? 'https' : 'http');

  Future<LiteRoom> create(String roomName, {Map<String, Object?> options = const {}}) => _matchmake('create', roomName, options);

  Future<LiteRoom> joinById(String roomId, {Map<String, Object?> options = const {}}) => _matchmake('joinById', roomId, options);

  Future<LiteRoom> _matchmake(String method, String target, Map<String, Object?> options) async {
    final uri = _httpBase.replace(path: '${_httpBase.path}/matchmake/$method/$target');
    final req = await _http.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.add(utf8.encode(jsonEncode(options)));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final body = await res.transform(utf8.decoder).join();
    final Object? data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw ColyseusLiteError(res.statusCode, 'HTTP ${res.statusCode}');
    }
    if (res.statusCode >= 400 || data is! Map || data['roomId'] == null) {
      final m = data is Map ? (data['error'] ?? data['message'] ?? 'HTTP ${res.statusCode}') : 'HTTP ${res.statusCode}';
      throw ColyseusLiteError(data is Map && data['code'] is int ? data['code'] as int : res.statusCode, '$m');
    }
    return _connect(data);
  }

  Future<LiteRoom> _connect(Map seat) async {
    final public = seat['publicAddress'] as String?;
    final base = public != null ? _ws.replace(host: public, path: '') : _ws;
    final url = base.replace(
      path: '${base.path}/${seat['processId']}/${seat['roomId']}',
      queryParameters: {'sessionId': '${seat['sessionId']}'},
    );
    final socket = await WebSocket.connect(url.toString()).timeout(const Duration(seconds: 15));
    socket.pingInterval = const Duration(seconds: 10);
    final room = LiteRoom._('${seat['roomId']}', '${seat['sessionId']}', socket);
    final joined = Completer<void>();
    socket.listen((f) => room._onFrame(f, joined), onDone: () => room._closed(joined), onError: (_) => room._closed(joined), cancelOnError: true);
    await joined.future.timeout(const Duration(seconds: 15));
    return room;
  }

  void dispose() => _http.close(force: true);
}
