// The game server's HTTP API (apps/server/src/api.ts), on the same address as the game rooms: wss://… becomes
// https://…/api. Every answer is JSON; a refusal is {error: code} with a 4xx status and arrives here as an
// [ApiError] whose [code] errorText() turns into Arabic.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiError implements Exception {
  ApiError(this.code, {this.status = 0, this.extra = const {}});
  final String code;
  final int status;
  final Map<String, dynamic> extra;
  @override
  String toString() => code;
}

/// `wss://host` → `https://host`, `ws://host:2567` → `http://host:2567`.
String httpBase(String ws) => ws.replaceFirst(RegExp(r'^ws'), 'http');

class Api {
  Api._();
  static final instance = Api._();

  String base = '${httpBase(kGameServer)}/api';
  /// Replaced in tests by a fake server (package:http/testing.dart).
  http.Client client = http.Client();

  /// The session token (set by Account).
  String? token;

  /// Called when the server says the session is gone (signed out elsewhere, account deleted).
  void Function()? onSignedOut;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query == null || query.isEmpty ? null : query);
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 15)));
    } on TimeoutException {
      throw ApiError('network');
    } catch (_) {
      throw ApiError('network');
    }
    dynamic json;
    try {
      json = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      json = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    final code = map['error']?.toString() ?? 'server';
    if (res.statusCode == 401 && code == 'signedOut') onSignedOut?.call();
    throw ApiError(code, status: res.statusCode, extra: map);
  }
}
