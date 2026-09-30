// The pure-Dart client speaks MessagePack with the server (msgpackr, plain
// MessagePack): what we encode must decode back unchanged, including the
// large epoch-ms numbers and Arabic text the game sends.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/msgpack.dart';

Object? roundTrip(Object? v) {
  final b = BytesBuilder();
  msgpackEncode(v, b);
  return MsgpackReader(b.takeBytes()).read();
}

void main() {
  test('round trip: nested maps, lists, Arabic, negatives, big numbers, doubles', () {
    final v = {
      'name': 'سمرة',
      'seats': [null, 'H14', true, false],
      'n': [0, 127, 128, 255, 256, 65535, 65536, -1, -32, -33, -129, -40000],
      'serverNow': 1790000000123,
      'half': 15.5,
      'long': 'x' * 300,
      'many': List.generate(20, (i) => i),
    };
    expect(roundTrip(v), v);
  });

  test('reads a message frame: type string then payload', () {
    final b = BytesBuilder()..addByte(13);
    msgpackEncode('state', b);
    msgpackEncode({'status': 'playing'}, b);
    final r = MsgpackReader(b.takeBytes(), 1);
    expect(r.nextIsString, isTrue);
    expect(r.read(), 'state');
    expect(r.read(), {'status': 'playing'});
    expect(r.hasMore, isFalse);
  });

  test('decodes msgpackr float64 whole numbers and uint64', () {
    // 0xcb = float64 1790000000123.0 ; 0xcf = uint64 2^40
    final f = (ByteData(9)..setUint8(0, 0xcb)..setFloat64(1, 1790000000123.0)).buffer.asUint8List();
    expect(MsgpackReader(f).read(), 1790000000123.0);
    final u = (ByteData(9)..setUint8(0, 0xcf)..setUint64(1, 1 << 40)).buffer.asUint8List();
    expect(MsgpackReader(u).read(), 1 << 40);
  });
}
