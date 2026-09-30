// Samrah (سمرة) — mobile client. Entry point only; no logic here.
// See lib/screens/room_screen.dart and lib/services/colyseus_client.dart.
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/samrah_theme.dart';

void main() {
  runApp(const SamrahApp());
}

class SamrahApp extends StatelessWidget {
  const SamrahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Samrah',
      theme: SamrahTheme.dark(),
      darkTheme: SamrahTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const LoginScreen(),
    );
  }
}
