// Push notifications (Firebase Cloud Messaging). Off until the build carries the Firebase project's keys
// (--dart-define FIREBASE_API_KEY / FIREBASE_APP_ID / FIREBASE_SENDER_ID / FIREBASE_PROJECT_ID, see config.dart)
// and the server has its service account; until then the notifications still arrive in the app's own list.
//
// A notification that arrives while the app is open shows as a banner at the top; tapping one (open or not)
// leads to its screen (a chat, a club, a competition, a match).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../app_nav.dart';
import 'account.dart';
import 'api.dart';
import 'config.dart';

class Push {
  Push._();
  static final instance = Push._();

  bool ready = false;
  bool _starting = false;

  /// After sign-in: ask permission, register the phone's token with the account, listen.
  Future<void> start() async {
    if (ready || _starting || !kPushConfigured || kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _starting = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(apiKey: kFirebaseApiKey, appId: kFirebaseAppId, messagingSenderId: kFirebaseSenderId, projectId: kFirebaseProjectId),
        );
      }
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      final token = await fm.getToken();
      if (token != null) await _register(token);
      fm.onTokenRefresh.listen(_register);
      FirebaseMessaging.onMessage.listen((m) {
        // the badges and lists catch up; a banner says what came
        unawaited(Account.instance.refresh());
        final n = m.notification;
        if (n != null) showBanner(n.title ?? '', n.body ?? '', m.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => openTarget(m.data));
      final first = await fm.getInitialMessage();
      if (first != null) openTarget(first.data);
      ready = true;
    } catch (e) {
      debugPrint('[push] $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _register(String token) async {
    if (!Account.instance.signedIn) return;
    try {
      await Api.instance.post('/me/push', {'token': token});
    } catch (_) {}
  }
}
