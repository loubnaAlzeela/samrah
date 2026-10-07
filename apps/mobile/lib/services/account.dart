// The player's account, as the server keeps it (apps/server/src/accounts.ts): the session, the balances, the
// level, what the player owns, settings and blocked players. The last copy is saved on the phone, so the app
// opens with the right numbers even before (or without) the network. Every change goes through the server;
// the answer replaces the local copy.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'prefs.dart';

class Me {
  Me(this.raw);
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  int get no => (raw['no'] as num).toInt();
  String get name => raw['name'] as String? ?? 'لاعب';
  String? get country => raw['country'] as String?;
  String? get email => raw['email'] as String?;
  bool get hasPassword => raw['hasPassword'] == true;
  String? get phone => raw['phone'] as String?;
  bool get google => raw['google'] == true;
  bool get apple => raw['apple'] == true;
  int get units => (raw['units'] as num? ?? 0).toInt();
  int get stars => (raw['stars'] as num? ?? 0).toInt();
  bool get vip => raw['vip'] == true;
  DateTime? get vipUntil => raw['vipUntil'] == null ? null : DateTime.fromMillisecondsSinceEpoch((raw['vipUntil'] as num).toInt());
  List<String> get owned => List<String>.from(raw['owned'] as List? ?? const []);
  String get backId => raw['backId'] as String? ?? 'orange';
  String get tableId => raw['tableId'] as String? ?? 'cream';
  bool get giftTaken => raw['giftTaken'] == true;
  int get giftAmount => (raw['giftAmount'] as num? ?? 100).toInt();
  int get level => (raw['level'] as num? ?? 1).toInt();
  int get xp => (raw['xp'] as num? ?? 0).toInt();
  int get levelFrom => (raw['levelFrom'] as num? ?? 0).toInt();
  int get levelTo => (raw['levelTo'] as num? ?? 100).toInt();

  /// Progress from this level to the next, 0..1.
  double get levelProgress => levelTo <= levelFrom ? 1 : ((xp - levelFrom) / (levelTo - levelFrom)).clamp(0, 1).toDouble();
  Map<String, dynamic> get stats => Map<String, dynamic>.from(raw['stats'] as Map? ?? const {});
  int get played => (stats['played'] as num? ?? 0).toInt();
  int get won => (stats['won'] as num? ?? 0).toInt();
  Map<String, dynamic> get settings => Map<String, dynamic>.from(raw['settings'] as Map? ?? const {});
  bool setting(String k, [bool d = true]) => settings[k] is bool ? settings[k] as bool : d;
  String get allowMessages => settings['allowMessages'] as String? ?? 'all';
  bool notifyOn(String kind) => (settings['notify'] as Map?)?[kind] != false;
  List<Map<String, dynamic>> get blocked => [for (final b in raw['blocked'] as List? ?? const []) Map<String, dynamic>.from(b as Map)];
  String? get clubId => raw['clubId'] as String?;
  int get sessions => (raw['sessions'] as num? ?? 1).toInt();
  DateTime? get renamedAt => raw['renamedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch((raw['renamedAt'] as num).toInt());
}

class Account extends ChangeNotifier {
  Account._();
  static final instance = Account._();

  Me? me;
  String? get token => Api.instance.token;
  bool get signedIn => token != null && me != null;

  /// Unread private messages and notifications (the badges).
  int unreadMessages = 0;
  int unreadNotifications = 0;

  /// The server's public settings (GET /config): prices, gifts, products, clubs, competitions…
  Map<String, dynamic> config = const {};

  Timer? _poll;

  /// Fired after a sign-out (here or from the server): the app goes back to the sign-in screen.
  VoidCallback? onSignedOut;

  /// Restores the saved session (no network needed).
  void restore() {
    Api.instance.token = Prefs.getString(Prefs.token);
    final saved = Prefs.getJson(Prefs.me);
    if (Api.instance.token != null && saved != null) me = Me(saved);
    Api.instance.onSignedOut = _signedOutByServer;
  }

  void _signedOutByServer() {
    if (token == null) return;
    _clear();
    onSignedOut?.call();
  }

  void apply(Object? json) {
    if (json is! Map) return;
    me = Me(Map<String, dynamic>.from(json));
    Prefs.setJson(Prefs.me, me!.raw);
    notifyListeners();
  }

  void _setSession(String token, Object? meJson) {
    Api.instance.token = token;
    Prefs.setString(Prefs.token, token);
    apply(meJson);
    start();
  }

  void _clear() {
    _poll?.cancel();
    _poll = null;
    Api.instance.token = null;
    me = null;
    unreadMessages = 0;
    unreadNotifications = 0;
    Prefs.setString(Prefs.token, null);
    Prefs.setString(Prefs.me, null);
    notifyListeners();
  }

  /// Starts the background refresh: the account and the badges every 30 seconds while the app runs.
  void start() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    unawaited(refresh());
    unawaited(loadConfig());
  }

  /// Stops the background refresh (tests; the app keeps it for its whole life).
  void stop() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> loadConfig() async {
    try {
      config = Map<String, dynamic>.from(await Api.instance.get('/config') as Map);
      notifyListeners();
    } catch (_) {}
  }

  /// Fresh account and badges; quiet when offline.
  Future<void> refresh() async {
    if (token == null) return;
    try {
      apply(await Api.instance.get('/me'));
      final u = await Api.instance.get('/unread') as Map;
      unreadMessages = (u['messages'] as num).toInt();
      unreadNotifications = (u['notifications'] as num).toInt();
      notifyListeners();
    } catch (_) {}
  }

  // ── signing in ────────────────────────────────────────────────────────────

  Future<void> signInAsGuest(String name) async {
    final r = await Api.instance.post('/auth/guest', {'name': name}) as Map;
    _setSession(r['token'] as String, r['me']);
  }

  Future<void> signInWithEmail(String email, String password) async {
    final r = await Api.instance.post('/auth/login', {'email': email.trim(), 'password': password}) as Map;
    _setSession(r['token'] as String, r['me']);
  }

  /// Phone or Google: links to this account when signed in, or signs in (a new account if never linked).
  Future<void> applyProviderResult(Map r) async {
    final t = r['token'] as String?;
    if (t != null) {
      _setSession(t, r['me']);
    } else {
      apply(r['me']);
    }
  }

  Future<void> signOut() async {
    try {
      await Api.instance.post('/auth/logout');
    } catch (_) {}
    _clear();
    onSignedOut?.call();
  }

  Future<void> deleteAccount() async {
    await Api.instance.delete('/me');
    _clear();
    onSignedOut?.call();
  }

  // ── changes ───────────────────────────────────────────────────────────────

  Future<void> update(Map<String, Object?> patch) async => apply(await Api.instance.patch('/me', patch));

  Future<void> updateSettings(Map<String, Object?> settings) => update({'settings': settings});

  Future<void> setEmail(String email, String password, {String? current}) async =>
      apply(await Api.instance.post('/me/email', {'email': email.trim(), 'password': password, 'current': ?current}));

  Future<void> signOutOthers() async => apply(await Api.instance.post('/me/signout-others'));

  Future<void> block(String userId) async => apply(await Api.instance.post('/users/$userId/block'));
  Future<void> unblock(String userId) async => apply(await Api.instance.delete('/users/$userId/block'));
  bool hasBlocked(String userId) => me?.blocked.any((b) => b['id'] == userId) ?? false;

  /// Store calls answer with the account: apply it.
  Future<void> call(String path, [Object? body]) async => apply(await Api.instance.post(path, body));

  void markMessagesRead(int n) {
    unreadMessages = (unreadMessages - n).clamp(0, 1 << 30);
    notifyListeners();
  }

  void markNotificationsRead() {
    unreadNotifications = 0;
    notifyListeners();
  }

  @visibleForTesting
  void setForTest(Map<String, dynamic>? json) {
    me = json == null ? null : Me(json);
    Api.instance.token = json == null ? null : 'test';
    notifyListeners();
  }
}
