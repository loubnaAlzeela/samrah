// What the app keeps on the phone between launches (shared_preferences): the session token, the last copy of
// the account (so the home screen shows balances at once, even offline), and the switches that are the phone's
// own (sound, voice, vibration). Loaded once in main() before the first screen.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  Prefs._();
  static SharedPreferences? _p;

  /// In tests (and if the platform store fails) everything stays in memory.
  static final Map<String, Object> _memory = {};

  static Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {
      _p = null;
    }
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
