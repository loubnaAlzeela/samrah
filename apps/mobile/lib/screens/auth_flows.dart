// The ways into an account, shared by the sign-in screen and the settings: email + password, a phone number
// with an SMS code, and Google. Signed in, each one links the method to the current account; signed out, it
// signs in to the account the method belongs to.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/config.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'profile_screen.dart' show say;

bool _googleReady = false;

/// Google sign-in: answers null when done, else the reason.
Future<String?> continueWithGoogle({String? name}) async {
  if (kGoogleServerClientId.isEmpty) return errorText('googleOff');
  try {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return errorText('badToken');
    final r = await Api.instance.post('/auth/google', {'idToken': idToken, 'name': ?name}) as Map;
    await Account.instance.applyProviderResult(r);
    return null;
  } on ApiError catch (e) {
    return errorText(e.code);
  } on GoogleSignInException catch (e) {
    return e.code == GoogleSignInExceptionCode.canceled ? null : 'تعذّر الدخول بحساب Google';
  } catch (_) {
    return 'تعذّر الدخول بحساب Google';
  }
}

/// Email + password: link them (signed in) or sign in with them. True when done.
Future<bool> showEmailSheet(BuildContext context, {required bool link}) async {
  final me = Account.instance.me;
  final email = TextEditingController(text: link ? (me?.email ?? '') : '');
  final pass = TextEditingController();
  final current = TextEditingController();
  final changing = link && (me?.hasPassword ?? false);
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SamrahColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(link ? (changing ? 'البريد وكلمة المرور' : 'اربط بريدك الإلكتروني') : 'الدخول بالبريد الإلكتروني',
                textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w700)),
            if (link)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('بهذا تستطيع الدخول إلى حسابك ورصيدك من أي هاتف.', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
            if (changing) ...[
              const SizedBox(height: 8),
              TextField(controller: current, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: pass,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: link ? (changing ? 'كلمة المرور الجديدة' : 'كلمة المرور (8 أحرف على الأقل)') : 'كلمة المرور', errorText: error),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      set(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (link) {
                          await Account.instance.setEmail(email.text, pass.text, current: changing ? current.text : null);
                        } else {
                          await Account.instance.signInWithEmail(email.text, pass.text);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiError catch (e) {
                        set(() {
                          busy = false;
                          error = errorText(e.code);
                        });
                      }
                    },
              child: Text(link ? 'احفظ' : 'ادخل'),
            ),
          ]),
        ),
      );
    },
  );
  email.dispose();
  pass.dispose();
  current.dispose();
  if (done == true && context.mounted) say(context, link ? 'حُفظ البريد وكلمة المرور' : 'أهلاً بعودتك!');
  return done == true;
}

/// A phone number and its SMS code: link (signed in) or sign in. True when done.
Future<bool> showPhoneSheet(BuildContext context, {String? name}) async {
  final phone = TextEditingController(text: Account.instance.me?.phone ?? '+');
  final code = TextEditingController();
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SamrahColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      var sent = false;
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, set) {
          Future<void> run(Future<void> Function() f) async {
            set(() {
              busy = true;
              error = null;
            });
            try {
              await f();
            } on ApiError catch (e) {
              set(() => error = errorText(e.code));
            }
            set(() => busy = false);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('رقم الهاتف', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                enabled: !sent,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'الرقم مع رمز الدولة', hintText: '+9665xxxxxxxx'),
              ),
              if (sent) ...[
                const SizedBox(height: 8),
                TextField(controller: code, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الرمز الذي وصلك')),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: SamrahColors.suitRed))),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          if (!sent) {
                            await Api.instance.post('/auth/phone/send', {'phone': phone.text});
                            set(() => sent = true);
                          } else {
                            final r = await Api.instance.post('/auth/phone/verify', {'phone': phone.text, 'code': code.text.trim(), 'name': ?name}) as Map;
                            await Account.instance.applyProviderResult(r);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          }
                        }),
                child: Text(sent ? 'تحقق' : 'أرسل الرمز'),
              ),
            ]),
          );
        },
      );
    },
  );
  phone.dispose();
  code.dispose();
  return done == true;
}
