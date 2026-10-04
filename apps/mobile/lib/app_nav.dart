// App-wide navigation that does not start from a screen: a notification tap (push or the in-app list) leads to
// its screen, and a banner can be shown over whatever is open.
import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';
import 'screens/clubs_screen.dart';
import 'screens/competitions_screen.dart';
import 'screens/room_screen.dart';
import 'theme/samrah_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Opens the screen a notification points at: {screen: chat|club|competition|match, …}.
void openTarget(Map<String, dynamic>? data) {
  final nav = navigatorKey.currentState;
  if (nav == null || data == null) return;
  switch (data['screen']) {
    case 'chat':
      final id = data['userId'] as String?;
      if (id != null) nav.push(MaterialPageRoute(builder: (_) => ChatScreen(userId: id)));
    case 'club':
      nav.push(MaterialPageRoute(builder: (_) => const ClubsScreen()));
    case 'competition':
      final id = data['id'] as String?;
      if (id != null) nav.push(MaterialPageRoute(builder: (_) => CompetitionScreen(compId: id)));
    case 'match':
      final code = data['code'] as String?;
      if (code != null) nav.push(MaterialPageRoute(builder: (_) => RoomScreen(joinCode: code)));
  }
}

/// A short banner at the top (a notification that came while the app was open); tapping it opens its screen.
void showBanner(String title, String body, Map<String, dynamic>? data) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentMaterialBanner();
  m.showMaterialBanner(
    MaterialBanner(
      backgroundColor: SamrahColors.surface2,
      leading: const Icon(Icons.notifications_active_outlined, color: SamrahColors.accent),
      content: InkWell(
        onTap: () {
          m.hideCurrentMaterialBanner();
          openTarget(data);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: m.hideCurrentMaterialBanner, child: const Text('إغلاق'))],
    ),
  );
  Future.delayed(const Duration(seconds: 5), () => messengerKey.currentState?.hideCurrentMaterialBanner());
}
