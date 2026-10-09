// Build-time settings (--dart-define). Everything has a default so a plain `flutter run` works against the live
// server; the optional services (push, Google sign-in) stay off until their keys are given.

/// Defaults to the live server on AWS. A local server needs --dart-define
/// (the emulator reaches the dev machine at ws://10.0.2.2:2567, a phone at its LAN IP).
const String kGameServer = String.fromEnvironment('GAME_SERVER', defaultValue: 'wss://samrah.ms-scan.com');

/// Firebase (push notifications): the values of the Firebase project's Android / iOS app.
const String kFirebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyB2lsrOZulLdEryylQvbjAElaWWXG7mw_E');
const String kFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:982062117132:android:c15c1d7d91047bacf6d929');
const String kFirebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '982062117132');
const String kFirebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'samrha-bff97');
bool get kPushConfigured => kFirebaseApiKey.isNotEmpty && kFirebaseAppId.isNotEmpty && kFirebaseSenderId.isNotEmpty && kFirebaseProjectId.isNotEmpty;

/// Google sign-in: the OAuth "web" client id the server checks the ID token against (GOOGLE_CLIENT_IDS there).
const String kGoogleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '1003483154426-hjtilfmlmefn8q8e888evmvtald1bg6p.apps.googleusercontent.com');

/// The app's version as shown in the settings.
const String kAppVersion = '1.2.0';
