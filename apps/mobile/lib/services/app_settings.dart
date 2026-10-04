// The phone's own switches that are not sound (kept on the phone); the account's settings (online status,
// messages, notifications…) live on the server, in Account.me.settings.
import 'package:flutter/services.dart';

import 'prefs.dart';

class AppSettings {
  static bool get vibration => Prefs.getBool(Prefs.vibration) ?? true;
  static set vibration(bool v) => Prefs.setBool(Prefs.vibration, v);

  /// a light tap on the hand, if the player allows it
  static void tick() {
    if (vibration) HapticFeedback.selectionClick();
  }
}
