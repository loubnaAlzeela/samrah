// The room's `state` broadcast (packages/rules/src/protocol.ts `RoomView`),
// narrowed to what this slice's UI needs. Every client receives its own
// view: `game` is already filtered to that seat's own hand + public info.
import 'b187_view.dart';
import 'baloot_view.dart';
import 'hand_view.dart';
import 'json_num.dart';
import 'player_view.dart';
import 'seat_info.dart';
import 'trix_view.dart';

export 'player_view.dart';
export 'seat_info.dart';
export 'trix_view.dart';
export 'b187_view.dart';
export 'baloot_view.dart';
export 'hand_view.dart';

class RoomView {
  final String code;
  final String variant;
  final int target;
  final String status; // waiting | playing | finished
  final List<SeatInfo?> seats;
  final int? mySeat;
  /// Tarneeb / Syrian 41 game view (null for trix rooms).
  final PlayerView? game;

  /// Trix game view (Trix and Trix Complex rooms only).
  final TrixView? trix;

  /// 187 game view (b187 rooms only).
  final B187View? b187;

  /// Baloot game view (baloot rooms only).
  final BalootView? baloot;

  /// Saudi Hand game view (hand rooms only).
  final HandGameView? hand;
  final bool isOwner;
  final int? ownerSeat;

  /// the viewer joined a running game and will take a computer seat once the
  /// current trick ends.
  final bool pending;

  /// server epoch ms when the current turn times out; null when nobody acts.
  final int? turnDeadline;

  /// server epoch ms when this message was built (client-clock-independent
  /// countdown: remaining = turnDeadline - serverNow, then tick locally).
  final int serverNow;

  /// the table's chat is on (the host's setting)
  final bool chatOn;

  RoomView({
    required this.code,
    required this.variant,
    required this.target,
    required this.status,
    required this.seats,
    required this.mySeat,
    required this.game,
    this.trix,
    this.b187,
    this.baloot,
    this.hand,
    required this.isOwner,
    required this.ownerSeat,
    required this.pending,
    required this.turnDeadline,
    required this.serverNow,
    this.chatOn = true,
  });

  factory RoomView.fromJson(Map json) {
    final seatsRaw = (json['seats'] as List?) ?? const [];
    final variant = (json['variant'] as String?) ?? 'tarneeb';
    final gameRaw = json['game'] as Map?;
    final trix = isTrixVariant(variant);
    final b187 = isB187Variant(variant);
    final baloot = isBalootVariant(variant);
    final hand = isHandVariant(variant);
    return RoomView(
      code: (json['code'] as String?) ?? '',
      variant: variant,
      target: asIntOr(json['target'], 41),
      status: (json['status'] as String?) ?? '',
      seats: seatsRaw.map(SeatInfo.fromJson).toList(),
      mySeat: asIntOrNull(json['mySeat']),
      game: gameRaw != null && !trix && !b187 && !baloot && !hand ? PlayerView.fromJson(gameRaw) : null,
      trix: gameRaw != null && trix ? TrixView.fromJson(gameRaw) : null,
      b187: gameRaw != null && b187 ? B187View.fromJson(gameRaw) : null,
      baloot: gameRaw != null && baloot ? BalootView.fromJson(gameRaw) : null,
      hand: gameRaw != null && hand ? HandGameView.fromJson(gameRaw) : null,
      isOwner: json['isOwner'] == true,
      ownerSeat: asIntOrNull(json['ownerSeat']),
      pending: json['pending'] == true,
      turnDeadline: asIntOrNull(json['turnDeadline']),
      serverNow: asIntOr(json['serverNow'], DateTime.now().millisecondsSinceEpoch),
      chatOn: (json['settings'] as Map?)?['chat'] != false,
    );
  }
}
