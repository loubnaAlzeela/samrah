// The two ways into an account, shared by the sign-in screen and the settings: Google, and Apple (iPhone only).
// Signed in, each one links the method to the current account; signed out, it signs in to the account the method
// belongs to (the first time, it makes the account).
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/config.dart';
import '../services/error_text.dart';

bool _googleReady = false;

/// Sign in with Apple is offered on iPhone only.
bool get appleSignInAvailable => !kIsWeb && Platform.isIOS;

/// Apple sign-in: answers null when done, else the reason. Apple gives the name only the first time, so it is sent along.
Future<String?> continueWithApple() async {
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.fullName],
    );
    final idToken = credential.identityToken;
    if (idToken == null) return errorText('badToken');
    final full = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().join(' ').trim();
    // the authorization code lets the server revoke this sign-in with Apple when the account is deleted
    final r =
        await Api.instance.post('/auth/apple', {
              'idToken': idToken,
              'authorizationCode': credential.authorizationCode,
              if (full.length >= 2) 'name': full,
            })
            as Map;
    await Account.instance.applyProviderResult(r);
    return null;
  } on ApiError catch (e) {
    return errorText(e.code);
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) return null;
    debugPrint('[apple sign-in] ${e.code.name}: ${e.message}');
    return 'تعذّر الدخول بحساب Apple (الرمز: ${e.code.name})';
  } catch (e) {
    debugPrint('[apple sign-in] $e');
    return 'تعذّر الدخول بحساب Apple';
  }
}

/// Google sign-in: answers null when done, else the reason.
Future<String?> continueWithGoogle({String? name}) async {
  try {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        serverClientId: kGoogleServerClientId.isEmpty
            ? null
            : kGoogleServerClientId,
      );
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return errorText('badToken');
    final r =
        await Api.instance.post('/auth/google', {
              'idToken': idToken,
              'name': ?name,
            })
            as Map;
    await Account.instance.applyProviderResult(r);
    return null;
  } on ApiError catch (e) {
    return errorText(e.code);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    // for now the code is shown, to tell a wrong Google Cloud setup (a missing Android client or SHA-1) from the rest
    debugPrint('[google sign-in] ${e.code.name}: ${e.description}');
    return 'تعذّر الدخول بحساب Google (الرمز: ${e.code.name})';
  } catch (e) {
    debugPrint('[google sign-in] $e');
    return 'تعذّر الدخول بحساب Google (${e.runtimeType})';
  }
}
