// What the app keeps on the phone between launches: the session token (encrypted, via
// flutter_secure_storage/Keychain/Keystore — it unlocks the account's wallet and chat, so it never goes into
// plaintext shared_preferences), the last copy of the account (so the home screen shows balances at once, even
// offline), and the switches that are the phone's own (sound, voice, vibration). Loaded once in main() before
// the first screen.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  Prefs._();
  static SharedPreferences? _p;
  static const _secure = FlutterSecureStorage();

  /// In tests (and if the platform store fails) everything stays in memory.
  static final Map<String, Object> _memory = {};

  /// The session token, cached in memory after [load] so [getToken] can stay synchronous
  /// like the rest of this class. The source of truth is the encrypted store.
  static String? _tokenCache;

  static Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {
      _p = null;
    }
    try {
      _tokenCache = await _secure.read(key: token);
    } catch (_) {
      _tokenCache = null;
    }
    // Migrate a token an older app version left in plaintext shared_preferences.
    final legacy = _p?.getString(token);
    if (legacy != null) {
      _tokenCache ??= legacy;
      if (_tokenCache == legacy) {
        try {
          await _secure.write(key: token, value: legacy);
        } catch (_) {}
      }
      await _p?.remove(token);
    }
  }

  /// The session token. Synchronous: reads the in-memory cache [load] filled from secure storage.
  static String? getToken() => _tokenCache;

  /// Writes (or, with `null`, clears) the session token in secure storage. Fire-and-forget from
  /// callers that aren't already `async` — the in-memory cache updates immediately regardless.
  static Future<void> setToken(String? v) async {
    _tokenCache = v;
    try {
      if (v == null) {
        await _secure.delete(key: token);
      } else {
        await _secure.write(key: token, value: v);
      }
    } catch (_) {}
  }

  static String? getString(String k) => _p?.getString(k) ?? _memory[k] as String?;
  static bool? getBool(String k) => _p?.getBool(k) ?? _memory[k] as bool?;

  static void setString(String k, String? v) {
    if (v == null) {
      _memory.remove(k);
      _p?.remove(k);
    } else {
      _memory[k] = v;
      _p?.setString(k, v);
    }
  }

  static void setBool(String k, bool v) {
    _memory[k] = v;
    _p?.setBool(k, v);
  }

  static Map<String, dynamic>? getJson(String k) {
    final s = getString(k);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void setJson(String k, Object? v) => setString(k, v == null ? null : jsonEncode(v));

  // keys
  static const token = 'auth.token';
  static const me = 'auth.me';
  static const effects = 'sound.effects';
  static const voice = 'sound.voice';
  static const vibration = 'app.vibration';
  static const pendingPurchases = 'store.pending';
}
