import 'json_num.dart';

/// One seat as broadcast by the server's `state` message
/// (see apps/server/src/LammaRoom.ts `broadcastViews` /
/// packages/rules/src/protocol.ts `SeatPublic`).
class SeatInfo {
  final String name;
  final bool connected;
  final bool bot;

  /// ms until a disconnected player's seat is released (relative, so client
  /// clock skew does not matter); null when not held.
  final int? heldMsLeft;

  /// the autopilot is playing this seat (away too long, or 3 timeouts).
  final bool auto;
  final int level;

  SeatInfo({
    required this.name,
    required this.connected,
    required this.bot,
    this.heldMsLeft,
    this.auto = false,
    this.level = 1,
  });

  static SeatInfo? fromJson(Object? json) {
    if (json == null) return null;
    final m = json as Map;
    return SeatInfo(
      name: (m['name'] as String?) ?? '?',
      connected: m['connected'] == true,
      bot: m['bot'] == true,
      heldMsLeft: asIntOrNull(m['heldMsLeft']),
      auto: m['auto'] == true,
      level: asIntOr(m['level'], 1),
    );
  }
}
