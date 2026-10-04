// الأندية — permanent groups of players (apps/server/src/clubs.ts): a president, moderators, a chat, and weekly
// points the members earn by playing. A new club costs 5000 «وحدات» and opens once the Samrah team approves it;
// it is open (anyone joins), closed (a request a moderator accepts) or private (by invitation only).
import 'dart:async';

import 'package:flutter/material.dart';

import 'account.dart';
import 'api.dart';
import 'error_text.dart';

enum ClubRole { president, moderator, member }

ClubRole? clubRoleOf(Object? s) => switch (s) {
      'president' => ClubRole.president,
      'moderator' => ClubRole.moderator,
      'member' => ClubRole.member,
      _ => null,
    };

String clubRoleName(ClubRole r) => switch (r) {
      ClubRole.president => 'الرئيس',
      ClubRole.moderator => 'مشرف',
      ClubRole.member => 'عضو',
    };

String clubTypeName(String t) => switch (t) {
      'open' => 'مفتوح',
      'private' => 'خاص',
      _ => 'مغلق',
    };

class ClubCard {
  ClubCard(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get name => j['name'] as String;
  String get motto => j['motto'] as String? ?? '';
  IconData get emblem => Clubs.emblems[((j['emblem'] as num?) ?? 0).toInt() % Clubs.emblems.length];
  Color get color => Clubs.colors[((j['color'] as num?) ?? 0).toInt() % Clubs.colors.length];
  int get emblemIndex => ((j['emblem'] as num?) ?? 0).toInt();
  int get colorIndex => ((j['color'] as num?) ?? 0).toInt();
  String get type => j['type'] as String? ?? 'closed';
  String get status => j['status'] as String? ?? 'active';
  bool get pending => status == 'pending';
  int get minLevel => ((j['minLevel'] as num?) ?? 1).toInt();
  int get memberCount => ((j['members'] is List ? (j['members'] as List).length : j['members']) as num? ?? 0).toInt();
  int get maxMembers => ((j['maxMembers'] as num?) ?? 30).toInt();
  bool get full => memberCount >= maxMembers;
  int get weekPoints => ((j['weekPoints'] as num?) ?? 0).toInt();
  String get president => j['president'] as String? ?? '';
}

class ClubPerson {
  ClubPerson(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  int get no => ((j['no'] as num?) ?? 0).toInt();
  String get name => j['name'] as String? ?? 'لاعب';
  int get level => ((j['level'] as num?) ?? 1).toInt();
  bool get online => j['online'] == true;
  ClubRole get role => clubRoleOf(j['role']) ?? ClubRole.member;
  int get weekPoints => ((j['weekPoints'] as num?) ?? 0).toInt();
  int get totalPoints => ((j['totalPoints'] as num?) ?? 0).toInt();
}

class ClubDetail extends ClubCard {
  ClubDetail(super.j);
  ClubRole? get myRole => clubRoleOf(j['myRole']);
  bool get requested => j['requested'] == true;
  bool get invited => j['invited'] == true;
  String? get note => j['note'] as String?;
  List<ClubPerson> get members => [for (final m in j['members'] as List? ?? const []) ClubPerson(Map<String, dynamic>.from(m as Map))];
  List<ClubPerson> get requests => [for (final m in j['requests'] as List? ?? const []) ClubPerson(Map<String, dynamic>.from(m as Map))];
  List<ClubPerson> get invites => [for (final m in j['invites'] as List? ?? const []) ClubPerson(Map<String, dynamic>.from(m as Map))];
  bool get canManage => myRole == ClubRole.president || myRole == ClubRole.moderator;
}

class ClubMessage {
  ClubMessage(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String? get from => j['from'] as String?;
  String get name => j['name'] as String? ?? '';
  String get text => j['text'] as String? ?? '';
  DateTime get at => DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt());
  bool get notice => from == null;
}

class Clubs extends ChangeNotifier {
  Clubs._();
  static final instance = Clubs._();

  static const emblems = [
    Icons.shield_rounded, Icons.local_fire_department_rounded, Icons.bolt_rounded, Icons.diamond_rounded,
    Icons.star_rounded, Icons.nightlight_round, Icons.castle_rounded, Icons.anchor_rounded,
  ];
  static const colors = [
    Color(0xFFFA8112), Color(0xFF3D6489), Color(0xFF3F7A4C), Color(0xFF8C3F43), Color(0xFFE8C77A), Color(0xFF6E4A9E),
  ];

  static int get createCost => ((Account.instance.config['clubs'] as Map?)?['createCost'] as num? ?? 5000).toInt();
  static int get maxModerators => ((Account.instance.config['clubs'] as Map?)?['maxModerators'] as num? ?? 4).toInt();

  /// The player's club (or the one they founded, still pending), invitations and their request.
  ClubDetail? mine;
  List<ClubCard> invites = [];
  String? requestedId;
  int unlockLevel = 1;
  int level = 1;
  bool loaded = false;
  String? error;

  bool get unlocked => level >= unlockLevel;

  /// The club chat (only while a club page is open).
  List<ClubMessage> chat = [];
  Timer? _chatTimer;

  Future<void> loadMine() async {
    try {
      final r = await Api.instance.get('/clubs/mine') as Map;
      mine = r['club'] == null ? null : ClubDetail(Map<String, dynamic>.from(r['club'] as Map));
      invites = [for (final c in r['invites'] as List) ClubCard(Map<String, dynamic>.from(c as Map))];
      requestedId = r['requestedId'] as String?;
      unlockLevel = (r['unlockLevel'] as num).toInt();
      level = (r['level'] as num).toInt();
      loaded = true;
      error = null;
    } on ApiError catch (e) {
      error = errorText(e.code);
    }
    notifyListeners();
  }

  Future<List<ClubCard>> list([String q = '']) async =>
      [for (final c in await Api.instance.get('/clubs', {if (q.isNotEmpty) 'q': q}) as List) ClubCard(Map<String, dynamic>.from(c as Map))];

  Future<List<ClubCard>> ranking() async => [for (final c in await Api.instance.get('/clubs-ranking') as List) ClubCard(Map<String, dynamic>.from(c as Map))];

  Future<ClubDetail> detail(String id) async => ClubDetail(Map<String, dynamic>.from(await Api.instance.get('/clubs/$id') as Map));

  /// Runs an action; null when done (the player's club is reloaded), else the reason in Arabic.
  Future<String?> _act(Future<dynamic> Function() f) async {
    try {
      await f();
      await loadMine();
      return null;
    } on ApiError catch (e) {
      return errorText(e.code);
    }
  }

  Future<String?> create({required String name, required String motto, required int emblem, required int color, required String type}) => _act(() async {
        final r = await Api.instance.post('/clubs', {'name': name.trim(), 'motto': motto.trim(), 'emblem': emblem, 'color': color, 'type': type, 'agree': true}) as Map;
        Account.instance.apply(r['me']);
      });

  /// 'joined' or 'requested', or an error.
  Future<(String?, String?)> join(String id) async {
    try {
      final r = await Api.instance.post('/clubs/$id/join') as Map;
      await loadMine();
      return (r['result'] as String, null);
    } on ApiError catch (e) {
      return (null, errorText(e.code));
    }
  }

  Future<String?> cancelRequest(String id) => _act(() => Api.instance.post('/clubs/$id/cancel-request'));
  Future<String?> decline(String id) => _act(() => Api.instance.post('/clubs/$id/decline'));
  Future<String?> leave() => _act(() async {
        Account.instance.apply(await Api.instance.post('/clubs/leave'));
        chat = [];
      });
  Future<String?> answer(String userId, bool accept) => _act(() => Api.instance.post('/clubs/${mine!.id}/requests/$userId', {'accept': accept}));
  Future<String?> invite(String ref) => _act(() => Api.instance.post('/clubs/${mine!.id}/invite', {'ref': ref.trim()}));
  Future<String?> cancelInvite(String userId) => _act(() => Api.instance.delete('/clubs/${mine!.id}/invite/$userId'));
  Future<String?> remove(String userId) => _act(() => Api.instance.delete('/clubs/${mine!.id}/members/$userId'));
  Future<String?> setRole(String userId, String role) => _act(() => Api.instance.post('/clubs/${mine!.id}/members/$userId/role', {'role': role}));
  Future<String?> update(Map<String, Object?> patch) => _act(() => Api.instance.patch('/clubs/${mine!.id}', patch));

  // ── chat ──────────────────────────────────────────────────────────────────

  /// Polls the club chat every few seconds while the page is open.
  void openChat() {
    _chatTimer?.cancel();
    unawaited(_fetchChat());
    _chatTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchChat());
  }

  void closeChat() {
    _chatTimer?.cancel();
    _chatTimer = null;
  }

  Future<void> _fetchChat() async {
    final c = mine;
    if (c == null || c.pending) return;
    try {
      final after = chat.isEmpty ? null : chat.last.at.millisecondsSinceEpoch;
      final list = await Api.instance.get('/clubs/${c.id}/chat', {if (after != null) 'after': '$after'}) as List;
      if (list.isEmpty) return;
      final known = {for (final m in chat) m.id};
      chat = [...chat, for (final m in list) if (!known.contains((m as Map)['id'])) ClubMessage(Map<String, dynamic>.from(m))];
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> send(String text) async {
    final c = mine;
    final t = text.trim();
    if (c == null || t.isEmpty) return null;
    try {
      chat = [...chat, ClubMessage(Map<String, dynamic>.from(await Api.instance.post('/clubs/${c.id}/chat', {'text': t}) as Map))];
      notifyListeners();
      return null;
    } on ApiError catch (e) {
      return errorText(e.code);
    }
  }
}
