// التحديات — daily and weekly tasks that pay «نجوم». The server counts every finished game for them
// (apps/server/src/accounts.ts CHALLENGES) and pays the reward when the player claims it; this class keeps the
// last list it sent.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'account.dart';
import 'api.dart';
import 'error_text.dart';

class Challenge {
  Challenge({required this.id, required this.title, required this.icon, required this.goal, required this.reward, this.progress = 0, this.game, this.claimed = false});
  final String id;
  final String title;
  final IconData icon;
  final int goal;

  /// «نجوم».
  final int reward;

  /// The game it counts in (a wire variant); null = any game.
  final String? game;
  int progress;
  bool claimed;

  bool get done => progress >= goal;
  bool get claimable => done && !claimed;

  static IconData iconOf(String? name) => switch (name) {
        'trophy' => Icons.emoji_events_outlined,
        'target' => Icons.track_changes_rounded,
        'shuffle' => Icons.shuffle_rounded,
        'group' => Icons.group_outlined,
        'star' => Icons.star_outline_rounded,
        'grid' => Icons.grid_view_rounded,
        'medal' => Icons.military_tech_outlined,
        _ => Icons.style_outlined,
      };

  factory Challenge.fromJson(Map j) => Challenge(
        id: j['id'] as String,
        title: j['title'] as String,
        icon: iconOf(j['icon'] as String?),
        goal: (j['goal'] as num).toInt(),
        reward: (j['reward'] as num).toInt(),
        progress: (j['progress'] as num? ?? 0).toInt(),
        game: j['game'] as String?,
        claimed: j['claimed'] == true,
      );
}

class Challenges extends ChangeNotifier {
  Challenges._();
  static final instance = Challenges._();

  List<Challenge> daily = [];
  List<Challenge> weekly = [];
  bool loaded = false;
  String? error;

  /// Finished tasks whose stars are still waiting (the badge on the nav).
  int get claimableCount => [...daily, ...weekly].where((c) => c.claimable).length;

  void _apply(Object? list) {
    if (list is! List) return;
    final all = [for (final j in list) Challenge.fromJson(j as Map)];
    final periods = {for (final j in list) (j as Map)['id']: j['period']};
    daily = all.where((c) => periods[c.id] == 'day').toList();
    weekly = all.where((c) => periods[c.id] == 'week').toList();
    loaded = true;
    error = null;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      _apply(await Api.instance.get('/challenges'));
    } on ApiError catch (e) {
      error = errorText(e.code);
      notifyListeners();
    }
  }

  /// Adds the reward to the wallet once; null when done, else the reason.
  Future<String?> claim(Challenge c) async {
    if (!c.claimable) return null;
    try {
      final r = await Api.instance.post('/challenges/${c.id}/claim') as Map;
      _apply(r['challenges']);
      Account.instance.apply(r['me']);
      return null;
    } on ApiError catch (e) {
      return errorText(e.code);
    }
  }

  /// The day turns at midnight in the Gulf and the Levant (UTC+3), as on the server.
  static DateTime nextDailyReset([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    return DateTime.utc(n.year, n.month, n.day + 1).subtract(const Duration(hours: 3)).toLocal();
  }

  /// Weekly tasks start over on Saturday at midnight (UTC+3).
  static DateTime nextWeeklyReset([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    final days = (DateTime.saturday - n.weekday) % 7;
    return DateTime.utc(n.year, n.month, n.day + (days == 0 ? 7 : days)).subtract(const Duration(hours: 3)).toLocal();
  }
}
