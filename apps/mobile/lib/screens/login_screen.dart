// The way in. A new player picks a name and plays at once (an account is created on the server with the
// welcome balance); a returning player signs in with the email, phone or Google account they linked.
import 'package:flutter/material.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/config.dart';
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
  bool _returning = false;
  bool _busy = false;
  String? _error;

  void _home() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(playerName: Account.instance.me?.name ?? 'لاعب')));
  }

  Future<void> _newPlayer() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) return setState(() => _error = 'اكتب اسماً من حرفين على الأقل');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Account.instance.signInAsGuest(name);
      _home();
    } on ApiError catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e.code);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: PopIn(from: 0.7, duration: Motion.slow, child: Image.asset('assets/brand/samrah-mark.png', height: 130, fit: BoxFit.contain))),
              const SizedBox(height: 8),
              EnterFrom(
                delay: const Duration(milliseconds: 200),
                child: Center(child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 44, fit: BoxFit.contain, semanticLabel: 'سمرة')),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _segment('لاعب جديد', !_returning, () => setState(() => _returning = false))),
                  Expanded(child: _segment('لديّ حساب', _returning, () => setState(() => _returning = true))),
                ]),
              ),
              const SizedBox(height: 20),
              if (!_returning) ...[
                TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.center,
                  maxLength: 16,
                  decoration: InputDecoration(labelText: 'اسمك في اللعبة', errorText: _error),
                  onSubmitted: (_) => _newPlayer(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _newPlayer,
                  child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('ابدأ اللعب'),
                ),
                const SizedBox(height: 8),
                const Text('يمكنك ربط بريدك أو هاتفك لاحقاً من الإعدادات لتحفظ حسابك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: SamrahColors.textMuted)),
              ] else ...[
                _provider(Icons.mail_outline, 'البريد الإلكتروني', const Color(0xFF2E9E4F), () async {
                  if (await showEmailSheet(context, link: false)) _home();
                }),
                _provider(Icons.phone_rounded, 'رقم الهاتف', const Color(0xFFD9A21E), () async {
                  if (await showPhoneSheet(context)) _home();
                }),
                if (appleSignInAvailable)
                  _provider(Icons.apple, 'حساب Apple', Colors.black, () async {
                    final err = await continueWithApple();
                    if (err != null) {
                      setState(() => _error = err);
                    } else if (Account.instance.signedIn) {
                      _home();
                    }
                  }),
                if (kGoogleServerClientId.isNotEmpty)
                  _provider(Icons.g_mobiledata_rounded, 'حساب Google', SamrahColors.surface2, () async {
                    final err = await continueWithGoogle();
                    if (err != null) {
                      setState(() => _error = err);
                    } else if (Account.instance.signedIn) {
                      _home();
                    }
                  }),
                if (_error != null) Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.suitRed)),
              ],
              const SizedBox(height: 16),
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
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 52,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text('الدخول عبر $label', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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
