// الأندية — permanent groups of players: a name, an emblem, a president and
// moderators, a chat, and weekly points the members earn by playing, ranked
// against the other clubs. DEMO: every club, member and message is made up and
// held in memory (like lib/services/store.dart); creating a club really takes
// «وحدات» from the wallet. Opens at level 5 (design/layout-v3.md §9) — levels
// are not real yet, so the screen offers a demo way in.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'store.dart';

enum ClubRole { president, moderator, member }

String clubRoleName(ClubRole r) => switch (r) {
      ClubRole.president => 'الرئيس',
      ClubRole.moderator => 'مشرف',
      ClubRole.member => 'عضو',
    };

class ClubMember {
  ClubMember(this.name, {this.role = ClubRole.member, this.weekPoints = 0, this.level = 5});
  final String name;
  ClubRole role;
  int weekPoints;
  final int level;
}

class ClubMessage {
  ClubMessage(this.from, this.text, {DateTime? at}) : at = at ?? DateTime.now();
  final String from;
  final String text;
  final DateTime at;
}

class Club {
  Club({required this.id, required this.name, required this.motto, required this.emblem, required this.color, required this.level, this.open = true, this.minLevel = 5});
  final String id;
  String name;
  String motto;
  final IconData emblem;
  final Color color;
  final int level;

  /// Anyone may join at once; otherwise a moderator approves the request.
  bool open;
  int minLevel;

  final List<ClubMember> members = [];
  final List<String> requests = [];
  final List<ClubMessage> chat = [];

  int get weekPoints => members.fold(0, (s, m) => s + m.weekPoints);
  bool get full => members.length >= Clubs.maxMembers;
}

class Clubs extends ChangeNotifier {
  Clubs._() {
    _seed();
  }
  static final instance = Clubs._();

  static const maxMembers = 30;
  static const createCost = 2000;
  static const unlockLevel = 5;

  static const emblems = [
    Icons.shield_rounded, Icons.local_fire_department_rounded, Icons.bolt_rounded, Icons.diamond_rounded,
    Icons.star_rounded, Icons.nightlight_round, Icons.castle_rounded, Icons.anchor_rounded,
  ];
  static const colors = [
    Color(0xFFFA8112), Color(0xFF3D6489), Color(0xFF3F7A4C), Color(0xFF8C3F43), Color(0xFFE8C77A), Color(0xFF6E4A9E),
  ];

  static const _names = [
    'سامر', 'خالد', 'ريم', 'أبو علي', 'نور', 'هادي', 'لين', 'جود', 'مازن', 'رامي', 'سلمى', 'فادي',
    'يزن', 'تالا', 'كرم', 'دانة', 'عمر', 'غيث', 'رهف', 'وسيم', 'زين', 'بشار', 'هلا', 'مجد',
  ];
  static const _chatter = [
    'مين جاهز لجولة طرنيب؟', 'مبروك للفريق، طلعنا بالترتيب!', 'أحد يدخل معي بلوت؟', 'يلا نجمع نقاط قبل نهاية الأسبوع',
    'جولة حلوة امبارح 👌', 'مين بيلعب تركس الليلة؟', 'نحتاج نقاط إضافية للمركز الأول', 'تمام، دقيقتين وبدخل',
  ];

  final _rng = math.Random(7);
  final List<Club> all = [];
  String me = 'أنت';
  String? _myClubId;
  int _nextId = 1;

  /// The club the player asked to join and is waiting on.
  String? pendingId;

  /// The demo way past the level-5 lock.
  bool demoUnlocked = false;

  Club? get myClub => all.where((c) => c.id == _myClubId).firstOrNull;
  ClubMember? get myMember => myClub?.members.where((m) => m.name == me).firstOrNull;
  bool get canManage => myMember != null && myMember!.role != ClubRole.member;

  /// Clubs by this week's points, best first.
  List<Club> get ranking => [...all]..sort((a, b) => b.weekPoints.compareTo(a.weekPoints));

  void setPlayer(String name) {
    if (name.trim().isNotEmpty && _myClubId == null) me = name.trim();
  }

  void unlockDemo() {
    demoUnlocked = true;
    notifyListeners();
  }

  void _seed() {
    Club make(String name, String motto, int emblem, int color, int level, int members, {bool open = true, int minLevel = 5}) {
      final c = Club(id: 'k${_nextId++}', name: name, motto: motto, emblem: emblems[emblem], color: colors[color], level: level, open: open, minLevel: minLevel);
      final names = [..._names]..shuffle(_rng);
      for (var i = 0; i < members; i++) {
        c.members.add(ClubMember(names[i % names.length] + (i >= names.length ? ' ${i ~/ names.length + 1}' : ''),
            role: i == 0 ? ClubRole.president : (i < 3 ? ClubRole.moderator : ClubRole.member),
            weekPoints: _rng.nextInt(400) + 20,
            level: 5 + _rng.nextInt(30)));
      }
      final now = DateTime.now();
      for (var i = 0; i < 5; i++) {
        c.chat.add(ClubMessage(c.members[_rng.nextInt(c.members.length)].name, _chatter[_rng.nextInt(_chatter.length)], at: now.subtract(Duration(minutes: (5 - i) * 13))));
      }
      return c;
    }

    all.addAll([
      make('صقور الطرنيب', 'نلعب بشرف ونفوز بذكاء', 0, 0, 7, 28, open: false, minLevel: 10),
      make('ديوانية السمر', 'سهرة كل ليلة', 5, 1, 5, 19),
      make('أبطال البلوت', 'الصكّة لنا', 1, 3, 6, 24, open: false),
      make('نجوم الشام', 'من الشام لكل العرب', 4, 4, 4, 15),
      make('ملوك التركس', 'كل الممالك تحت أمرنا', 6, 5, 3, 11),
      make('شباب الحارة', 'لمّة حلوة ولعب نظيف', 2, 2, 2, 7),
    ]);
  }

  /// Joins an open club at once, or sends a request to one that approves members.
  String? join(Club c) {
    if (myClub != null) return 'أنت عضو في نادٍ آخر، اخرج منه أولاً';
    if (c.full) return 'النادي ممتلئ';
    if (c.open) {
      c.members.add(ClubMember(me, level: unlockLevel));
      _myClubId = c.id;
      pendingId = null;
      c.chat.add(ClubMessage('النادي', '$me انضم إلى النادي'));
      _reply(c, 'أهلاً $me، نوّرت النادي!');
    } else {
      pendingId = c.id;
      // a moderator answers after a moment
      Timer(const Duration(seconds: 3), () {
        if (pendingId != c.id || myClub != null) return;
        pendingId = null;
        c.members.add(ClubMember(me, level: unlockLevel));
        _myClubId = c.id;
        c.chat.add(ClubMessage('النادي', 'قُبل طلب $me للانضمام'));
        notifyListeners();
      });
    }
    notifyListeners();
    return null;
  }

  void cancelRequest() {
    pendingId = null;
    notifyListeners();
  }

  /// Leaves the club. A president who leaves hands the club to the next moderator.
  void leave() {
    final c = myClub;
    if (c == null) return;
    final wasPresident = myMember!.role == ClubRole.president;
    c.members.removeWhere((m) => m.name == me);
    _myClubId = null;
    if (c.members.isEmpty) {
      all.remove(c);
    } else {
      if (wasPresident) {
        final next = c.members.firstWhere((m) => m.role == ClubRole.moderator, orElse: () => c.members.first);
        next.role = ClubRole.president;
      }
      c.chat.add(ClubMessage('النادي', '$me غادر النادي'));
    }
    notifyListeners();
  }

  /// Founds a club; the player becomes its president. Costs [createCost] «وحدات».
  String? create({required String name, required String motto, required IconData emblem, required Color color, required bool open}) {
    if (myClub != null) return 'أنت عضو في نادٍ آخر، اخرج منه أولاً';
    final n = name.trim();
    if (n.length < 3) return 'اسم النادي قصير جداً';
    if (all.any((c) => c.name == n)) return 'هذا الاسم مستخدم';
    if (!Store.instance.spend(createCost)) return 'رصيد الوحدات لا يكفي: تحتاج $createCost وحدة';
    final c = Club(id: 'k${_nextId++}', name: n, motto: motto.trim(), emblem: emblem, color: color, level: 1, open: open);
    c.members.add(ClubMember(me, role: ClubRole.president, level: unlockLevel));
    c.chat.add(ClubMessage('النادي', 'أسّس $me النادي'));
    all.add(c);
    _myClubId = c.id;
    pendingId = null;
    // a few people ask to join a new club
    for (var i = 0; i < 3; i++) {
      c.requests.add(_names[_rng.nextInt(_names.length)]);
    }
    notifyListeners();
    return null;
  }

  void accept(String who) {
    final c = myClub;
    if (c == null || !canManage || c.full) return;
    if (c.requests.remove(who)) {
      c.members.add(ClubMember(who, level: 5 + _rng.nextInt(20)));
      c.chat.add(ClubMessage('النادي', '$who انضم إلى النادي'));
    }
    notifyListeners();
  }

  void reject(String who) {
    myClub?.requests.remove(who);
    notifyListeners();
  }

  /// Moderators may remove members; only the president removes or promotes moderators.
  bool canAct(ClubMember target) {
    final mine = myMember;
    if (mine == null || target.name == me || target.role == ClubRole.president) return false;
    if (mine.role == ClubRole.president) return true;
    return mine.role == ClubRole.moderator && target.role == ClubRole.member;
  }

  void toggleModerator(ClubMember m) {
    if (myMember?.role != ClubRole.president || m.role == ClubRole.president) return;
    m.role = m.role == ClubRole.moderator ? ClubRole.member : ClubRole.moderator;
    notifyListeners();
  }

  void remove(ClubMember m) {
    final c = myClub;
    if (c == null || !canAct(m)) return;
    c.members.remove(m);
    c.chat.add(ClubMessage('النادي', 'أُخرج ${m.name} من النادي'));
    notifyListeners();
  }

  void updateSettings({required String motto, required bool open}) {
    final c = myClub;
    if (c == null || myMember?.role != ClubRole.president) return;
    c.motto = motto.trim();
    c.open = open;
    notifyListeners();
  }

  void send(String text) {
    final c = myClub;
    final t = text.trim();
    if (c == null || t.isEmpty) return;
    c.chat.add(ClubMessage(me, t));
    if (c.members.length > 1 && _rng.nextDouble() < 0.6) _reply(c, _chatter[_rng.nextInt(_chatter.length)]);
    notifyListeners();
  }

  void _reply(Club c, String text) {
    final others = c.members.where((m) => m.name != me).toList();
    if (others.isEmpty) return;
    final who = others[_rng.nextInt(others.length)].name;
    Timer(Duration(milliseconds: 1500 + _rng.nextInt(2000)), () {
      if (!all.contains(c)) return;
      c.chat.add(ClubMessage(who, text));
      notifyListeners();
    });
  }
}
