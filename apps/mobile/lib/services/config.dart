// Build-time settings (--dart-define). Everything has a default so a plain `flutter run` works against the live
// server; the optional services (push, Google sign-in) stay off until their keys are given.

/// Defaults to the live server on Railway. A local server needs --dart-define
/// (the emulator reaches the dev machine at ws://10.0.2.2:2567, a phone at its LAN IP).
const String kGameServer = String.fromEnvironment('GAME_SERVER', defaultValue: 'wss://samrah-production.up.railway.app');

/// Google sign-in: the OAuth "web" client id the server checks the ID token against (GOOGLE_CLIENT_IDS there).
const String kGoogleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// The app's version as shown in the settings.
const String kAppVersion = '1.1.0';
