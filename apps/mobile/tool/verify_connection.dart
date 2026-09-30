// Standalone check (not shipped in the app): connects to a game server with
// the app's own client (lib/services/colyseus_lite.dart), creates a room,
// starts it with computer players and prints what arrives. Run with:
//   dart run tool/verify_connection.dart [endpoint] [variant] [seconds]
//   e.g. dart run tool/verify_connection.dart wss://samrah-production.up.railway.app baloot 8
// ignore_for_file: avoid_print — this is a console diagnostic tool, printing is the point.
import 'dart:async';
import 'dart:io';

import 'package:mobile/services/colyseus_lite.dart';

Future<void> main(List<String> args) async {
  final endpoint = args.isNotEmpty ? args[0] : 'ws://localhost:2567';
  final variant = args.length > 1 ? args[1] : 'tarneeb';
  final seconds = args.length > 2 ? int.parse(args[2]) : 10;
  final client = ColyseusLite(endpoint);
  final t0 = DateTime.now();
  print('connecting to $endpoint ...');
  final room = await client.create('lamma', options: {'variant': variant, 'name': 'فلاتر-تحقق'});
  print('ROOM CREATED: id=${room.id} in ${DateTime.now().difference(t0).inMilliseconds} ms');

  var states = 0;
  Map? last;
  room.onMessage('welcome').listen((m) => print('welcome: $m'));
  room.onMessage('state').listen((m) {
    states++;
    last = m as Map;
  });
  room.onMessage('error').listen((m) => print('error: $m'));
  room.onLeave.listen((c) => print('left: $c'));

  await Future.delayed(const Duration(milliseconds: 500));
  room.send('start');
  await Future.delayed(Duration(seconds: seconds));
  final g = last?['game'] as Map?;
  print('states received: $states; status=${last?['status']} variant=${g?['variant']} phase=${g?['phase']} hand=${(g?['myHand'] as List?)?.length}');
  await room.leave();
  client.dispose();
  exit(states > 0 && last?['status'] == 'playing' ? 0 : 1);
}
