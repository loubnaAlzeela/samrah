// The way in: two tabs, "new account" and "sign in", each offering Google, Apple (iPhone) and email + password.
// Creating an account by email makes the account on the server (welcome balance included) and sets the email and
// password on it; signing in returns to an existing account.
import 'package:flutter/material.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'auth_flows.dart';
import 'home_screen.dart';
import 'legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _returning = false;
  bool _busy = false;
  bool _hidePass = true;
  String? _error;

  void _home() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(playerName: Account.instance.me?.name ?? 'لاعب')));
  }

  void _switch(bool returning) => setState(() {
        _returning = returning;
        _error = null;
      });

  /// Runs one attempt: shows the spinner, then either goes home or shows why not.
  Future<void> _attempt(Future<String?> Function() go) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? err;
    try {
      err = await go();
    } on ApiError catch (e) {
      err = errorText(e.code);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null && Account.instance.signedIn) _home();
  }

  Future<String?> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (name.length < 2) return 'اكتب اسماً من حرفين على الأقل';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return errorText('badEmail');
    if (pass.length < 8) return errorText('weakPassword');
    await Account.instance.signInAsGuest(name);
    try {
      await Account.instance.setEmail(email, pass);
    } catch (_) {
      await Account.instance.signOut();
      rethrow;
    }
    return null;
  }

  Future<String?> _signIn() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _passCtrl.text.isEmpty) return 'اكتب البريد وكلمة المرور';
    await Account.instance.signInWithEmail(email, _passCtrl.text);
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: PopIn(from: 0.7, duration: Motion.slow, child: Image.asset('assets/brand/samrah-mark.png', height: 110, fit: BoxFit.contain))),
              const SizedBox(height: 8),
              EnterFrom(
                delay: const Duration(milliseconds: 200),
                child: Center(child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 40, fit: BoxFit.contain, semanticLabel: 'سمرة')),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _segment('إنشاء حساب', !_returning, () => _switch(false))),
                  Expanded(child: _segment('تسجيل الدخول', _returning, () => _switch(true))),
                ]),
              ),
              const SizedBox(height: 20),
              if (!_returning) ...[
                TextField(
                  controller: _nameCtrl,
                  maxLength: 16,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسمك في اللعبة', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 4),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: _hidePass,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                autofillHints: [_returning ? AutofillHints.password : AutofillHints.newPassword],
                onSubmitted: (_) => _attempt(_returning ? _signIn : _register),
                decoration: InputDecoration(
                  labelText: _returning ? 'كلمة المرور' : 'كلمة المرور (8 أحرف على الأقل)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _hidePass = !_hidePass),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.suitRed)),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : () => _attempt(_returning ? _signIn : _register),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_returning ? 'تسجيل الدخول' : 'إنشاء الحساب'),
              ),
              ...[
                const SizedBox(height: 18),
                Row(children: const [
                  Expanded(child: Divider(color: SamrahColors.line)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: TextStyle(color: SamrahColors.textMuted))),
                  Expanded(child: Divider(color: SamrahColors.line)),
                ]),
                const SizedBox(height: 14),
                _provider(Icons.g_mobiledata_rounded, 'المتابعة بحساب Google', SamrahColors.surface2, () => _attempt(continueWithGoogle)),
                if (appleSignInAvailable) _provider(Icons.apple, 'المتابعة بحساب Apple', Colors.black, () => _attempt(continueWithApple)),
              ],
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, children: [
                const Text('بالمتابعة توافق على ', style: TextStyle(fontSize: 12, color: SamrahColors.textMuted)),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'terms'))),
                  child: const Text('شروط الاستخدام', style: TextStyle(fontSize: 12, color: SamrahColors.text, decoration: TextDecoration.underline)),
                ),
                const Text(' و', style: TextStyle(fontSize: 12, color: SamrahColors.textMuted)),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'privacy'))),
                  child: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 12, color: SamrahColors.text, decoration: TextDecoration.underline)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _provider(IconData icon, String label, Color color, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _busy ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 52,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? SamrahColors.selectedBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? SamrahColors.onSelected : SamrahColors.textMuted, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
