// Standalone verification script (not shipped in the app): connects to the
// live LammaRoom exactly like the Flutter client does, creates a room, and
// prints every 'state' broadcast so we can see other players join in real
// time. Run with:
//   COLYSEUS_LIBRARY_PATH=<path-to-dll> dart run tool/verify_connection.dart
// ignore_for_file: avoid_print — this is a console diagnostic tool, printing is the point.
import 'dart:async';
import 'package:colyseus/colyseus.dart';

void main() async {
  final client = ColyseusClient('ws://localhost:2567');
  print('connecting...');
  final room = await client.create('lamma', options: {'variant': 'tarneeb', 'name': 'فلاتر-تحقق'});
  print('ROOM CREATED: id=${room.id} sessionId=${room.sessionId}');

  room.onMessage('welcome').listen((m) => print('welcome: $m'));
  room.onMessage('state').listen((m) {
    final map = m as Map;
    final seats = (map['seats'] as List?) ?? const [];
    final names = seats.map((s) => s == null ? '-' : (s as Map)['name']).toList();
    print('STATE update: status=${map['status']} seats=$names');
  });
  room.onMessage('error').listen((m) => print('error: $m'));
  room.onLeave.listen((c) => print('left: $c'));

  // Keep the process (and the poll loop) alive for 60s so we can watch bots join.
  await Future.delayed(const Duration(seconds: 60));
  await room.leave();
  client.dispose();
}
