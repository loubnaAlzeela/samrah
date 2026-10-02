// التحديات — daily and weekly tasks that pay «نجوم». DEMO: the list and each
// task's progress are made up and held in memory (like lib/services/store.dart);
// claiming really adds the stars to the wallet. Later, finished hands and games
// will call [Challenges.record] so progress comes from real play.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'store.dart';

class Challenge {
  Challenge({required this.id, required this.title, required this.icon, required this.goal, required this.reward, this.progress = 0, this.game});
  final String id;
  final String title;
  final IconData icon;
  final int goal;

  /// «نجوم».
  final int reward;

  /// The game it counts in (a wire variant); null = any game.
  final String? game;
  int progress;
  bool claimed = false;

  bool get done => progress >= goal;
  bool get claimable => done && !claimed;
}

class Challenges extends ChangeNotifier {
  Challenges._();
  static final instance = Challenges._();

  final daily = <Challenge>[
    Challenge(id: 'd-play3', title: 'العب 3 جولات من أي لعبة', icon: Icons.style_outlined, goal: 3, reward: 5, progress: 3),
    Challenge(id: 'd-tarneeb2', title: 'افز بجولتين طرنيب', icon: Icons.emoji_events_outlined, goal: 2, reward: 8, progress: 1, game: 'tarneeb'),
    Challenge(id: 'd-bid10', title: 'اطلب 10 في الطرنيب ونفّذها', icon: Icons.track_changes_rounded, goal: 1, reward: 15, game: 'tarneeb'),
    Challenge(id: 'd-trixhand', title: 'العب جولة تركس وجولة هاند', icon: Icons.shuffle_rounded, goal: 2, reward: 6, progress: 2),
    Challenge(id: 'd-friend', title: 'العب مع صديق في غرفة خاصة', icon: Icons.group_outlined, goal: 1, reward: 5),
  ];

  final weekly = <Challenge>[
    Challenge(id: 'w-play25', title: 'العب 25 جولة', icon: Icons.style_outlined, goal: 25, reward: 30, progress: 17),
    Challenge(id: 'w-baloot10', title: 'افز بـ10 جولات بلوت', icon: Icons.emoji_events_outlined, goal: 10, reward: 40, progress: 4, game: 'baloot'),
    Challenge(id: 'w-400', title: 'اجمع مشروع «أربعمية» في البلوت', icon: Icons.auto_awesome_outlined, goal: 1, reward: 50, game: 'baloot'),
    Challenge(id: 'w-variety', title: 'جرّب 4 ألعاب مختلفة', icon: Icons.grid_view_rounded, goal: 4, reward: 25, progress: 4),
    Challenge(id: 'w-comp', title: 'اشترك في مسابقة', icon: Icons.military_tech_outlined, goal: 1, reward: 20),
  ];

  /// Finished tasks whose stars are still waiting (the badge on the nav).
  int get claimableCount => [...daily, ...weekly].where((c) => c.claimable).length;

  /// Adds the reward to the wallet once.
  void claim(Challenge c) {
    if (!c.claimable) return;
    c.claimed = true;
    Store.instance.earnStars(c.reward);
    notifyListeners();
  }

  /// Daily tasks start over at midnight.
  static DateTime nextDailyReset([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  /// Weekly tasks start over on Saturday at midnight.
  static DateTime nextWeeklyReset([DateTime? now]) {
    final n = now ?? DateTime.now();
    final days = (DateTime.saturday - n.weekday) % 7;
    return DateTime(n.year, n.month, n.day + (days == 0 ? 7 : days));
  }
}
