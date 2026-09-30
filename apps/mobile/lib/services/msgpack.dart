// Minimal MessagePack (https://msgpack.org) encoder / decoder for the game
// protocol: the server packs every message with msgpackr (`useRecords: false`,
// i.e. plain MessagePack), and our messages are small maps of strings,
// numbers, booleans and lists. Extension types are not used by either side.
import 'dart:convert';
import 'dart:typed_data';

/// Appends the MessagePack encoding of [value] to [out].
void msgpackEncode(Object? value, BytesBuilder out) {
  if (value == null) {
    out.addByte(0xc0);
  } else if (value is bool) {
    out.addByte(value ? 0xc3 : 0xc2);
  } else if (value is int) {
    _encodeInt(value, out);
  } else if (value is double) {
    if (value == value.truncateToDouble() && value.abs() < 9007199254740992) {
      _encodeInt(value.toInt(), out);
    } else {
      out.addByte(0xcb);
      out.add((ByteData(8)..setFloat64(0, value)).buffer.asUint8List());
    }
  } else if (value is String) {
    final bytes = utf8.encode(value);
    final n = bytes.length;
    if (n < 32) {
      out.addByte(0xa0 | n);
    } else if (n < 0x100) {
      out.add([0xd9, n]);
    } else if (n < 0x10000) {
      out.add([0xda, n >> 8, n & 0xff]);
    } else {
      out.addByte(0xdb);
      out.add(_u32(n));
    }
    out.add(bytes);
  } else if (value is List) {
    final n = value.length;
    if (n < 16) {
      out.addByte(0x90 | n);
    } else if (n < 0x10000) {
      out.add([0xdc, n >> 8, n & 0xff]);
    } else {
      out.addByte(0xdd);
      out.add(_u32(n));
    }
    for (final v in value) {
      msgpackEncode(v, out);
    }
  } else if (value is Map) {
    final n = value.length;
    if (n < 16) {
      out.addByte(0x80 | n);
    } else if (n < 0x10000) {
      out.add([0xde, n >> 8, n & 0xff]);
    } else {
      out.addByte(0xdf);
      out.add(_u32(n));
    }
    value.forEach((k, v) {
      msgpackEncode(k.toString(), out);
      msgpackEncode(v, out);
    });
  } else {
    throw ArgumentError('msgpack: cannot encode ${value.runtimeType}');
  }
}

List<int> _u32(int n) => [(n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];

void _encodeInt(int v, BytesBuilder out) {
  if (v >= 0) {
    if (v < 0x80) {
      out.addByte(v);
    } else if (v < 0x100) {
      out.add([0xcc, v]);
    } else if (v < 0x10000) {
      out.add([0xcd, v >> 8, v & 0xff]);
    } else if (v < 0x100000000) {
      out.addByte(0xce);
      out.add(_u32(v));
    } else {
      out.addByte(0xcf);
      out.add((ByteData(8)..setUint64(0, v)).buffer.asUint8List());
    }
  } else {
    if (v >= -32) {
      out.addByte(v & 0xff);
    } else if (v >= -0x80) {
      out.add([0xd0, v & 0xff]);
    } else if (v >= -0x8000) {
      out.addByte(0xd1);
      out.add((ByteData(2)..setInt16(0, v)).buffer.asUint8List());
    } else if (v >= -0x80000000) {
      out.addByte(0xd2);
      out.add((ByteData(4)..setInt32(0, v)).buffer.asUint8List());
    } else {
      out.addByte(0xd3);
      out.add((ByteData(8)..setInt64(0, v)).buffer.asUint8List());
    }
  }
}

/// Reads MessagePack values one after another from [bytes], starting at [offset].
class MsgpackReader {
  MsgpackReader(this.bytes, [this.offset = 0]) : _data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData _data;
  int offset;

  bool get hasMore => offset < bytes.length;

  /// The next byte starts a string (used for the message type, which may also be a number).
  bool get nextIsString {
    final b = bytes[offset];
    return (b & 0xe0) == 0xa0 || b == 0xd9 || b == 0xda || b == 0xdb;
  }

  Object? read() {
    final b = bytes[offset++];
    if (b <= 0x7f) return b;
    if (b >= 0xe0) return b - 0x100;
    if ((b & 0xf0) == 0x80) return _map(b & 0x0f);
    if ((b & 0xf0) == 0x90) return _list(b & 0x0f);
    if ((b & 0xe0) == 0xa0) return _str(b & 0x1f);
    switch (b) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xc4:
        return _bin(_u8());
      case 0xc5:
        return _bin(_u16());
      case 0xc6:
        return _bin(_u32r());
      case 0xca:
        final v = _data.getFloat32(offset);
        offset += 4;
        return v;
      case 0xcb:
        final v = _data.getFloat64(offset);
        offset += 8;
        return v;
      case 0xcc:
        return _u8();
      case 0xcd:
        return _u16();
      case 0xce:
        return _u32r();
      case 0xcf:
        final v = _data.getUint64(offset);
        offset += 8;
        return v;
      case 0xd0:
        final v = _data.getInt8(offset);
        offset += 1;
        return v;
      case 0xd1:
        final v = _data.getInt16(offset);
        offset += 2;
        return v;
      case 0xd2:
        final v = _data.getInt32(offset);
        offset += 4;
        return v;
      case 0xd3:
        final v = _data.getInt64(offset);
        offset += 8;
        return v;
      case 0xd9:
        return _str(_u8());
      case 0xda:
        return _str(_u16());
      case 0xdb:
        return _str(_u32r());
      case 0xdc:
        return _list(_u16());
      case 0xdd:
        return _list(_u32r());
      case 0xde:
        return _map(_u16());
      case 0xdf:
        return _map(_u32r());
    }
    throw FormatException('msgpack: unsupported type 0x${b.toRadixString(16)} at ${offset - 1}');
  }

  int _u8() => bytes[offset++];
  int _u16() {
    final v = _data.getUint16(offset);
    offset += 2;
    return v;
  }

  int _u32r() {
    final v = _data.getUint32(offset);
    offset += 4;
    return v;
  }

  String _str(int n) {
    final s = utf8.decode(bytes.sublist(offset, offset + n));
    offset += n;
    return s;
  }

  Uint8List _bin(int n) {
    final v = bytes.sublist(offset, offset + n);
    offset += n;
    return v;
  }

  List<Object?> _list(int n) => [for (var i = 0; i < n; i++) read()];

  Map<String, Object?> _map(int n) {
    final m = <String, Object?>{};
    for (var i = 0; i < n; i++) {
      final k = read();
      m[k.toString()] = read();
    }
    return m;
  }
}
