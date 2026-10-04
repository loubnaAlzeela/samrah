// Samrah (سمرة) — mobile client. Entry point only: load what the phone kept, then the opening scene, then the
// home screen (signed in) or the way in.
import 'package:flutter/material.dart';

import 'app_nav.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/account.dart';
import 'services/prefs.dart';
import 'services/sound.dart';
import 'theme/samrah_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // the session, the last copy of the account and the switches kept on the phone
  await Prefs.load();
  Account.instance.restore();
  // signed out (here, from another phone, or the account was deleted): back to the way in
  Account.instance.onSignedOut = () => navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  // the game falls silent in the background (a table left open keeps playing)
  Sound.instance.watchAppLifecycle();
  runApp(const SamrahApp());
  // load every sound and voice clip once, in the background, while the player logs in
  Sound.instance.warmUp();
}

class SamrahApp extends StatelessWidget {
  const SamrahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Account.instance.me;
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Samrah',
      theme: SamrahTheme.dark(),
      darkTheme: SamrahTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: SplashScreen(next: Account.instance.signedIn ? HomeScreen(playerName: me!.name) : const LoginScreen()),
    );
  }
}
