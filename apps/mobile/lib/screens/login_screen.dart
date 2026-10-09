// The way in: Google (everywhere) and Apple (iPhone), nothing else. A first sign-in makes the account on the server
// (the welcome balance included); a later one returns to it. The player's name comes from the Google / Apple account.
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
  bool _busy = false;
  String? _error;

  void _home() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            HomeScreen(playerName: Account.instance.me?.name ?? 'لاعب'),
      ),
    );
  }

  /// Runs one attempt: shows the spinner, then either goes home or shows why not. Whatever goes wrong, the buttons come back.
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
    } catch (e) {
      debugPrint('[sign-in] $e');
      err = 'حدث خطأ غير متوقع، حاول مرة أخرى';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null && Account.instance.signedIn) _home();
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
              const SizedBox(height: 24),
              Center(
                child: PopIn(
                  from: 0.7,
                  duration: Motion.slow,
                  child: Image.asset(
                    'assets/brand/samrah-mark.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              EnterFrom(
                delay: const Duration(milliseconds: 200),
                child: Center(
                  child: Image.asset(
                    'assets/brand/samrah-wordmark-ar.png',
                    height: 44,
                    fit: BoxFit.contain,
                    semanticLabel: 'سمرة',
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'سجّل دخولك لتبدأ اللعب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SamrahColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'حسابك ورصيدك يبقيان معك على أي هاتف.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SamrahColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _provider(
                  Icons.g_mobiledata_rounded,
                  'المتابعة بحساب Google',
                  SamrahColors.surface2,
                  () => _attempt(continueWithGoogle),
                ),
                if (appleSignInAvailable)
                  _provider(
                    Icons.apple,
                    'المتابعة بحساب Apple',
                    Colors.black,
                    () => _attempt(continueWithApple),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SamrahColors.suitRed),
                  ),
                ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'بالمتابعة توافق على ',
                    style: TextStyle(
                      fontSize: 12,
                      color: SamrahColors.textMuted,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(doc: 'terms'),
                      ),
                    ),
                    child: const Text(
                      'شروط الاستخدام',
                      style: TextStyle(
                        fontSize: 12,
                        color: SamrahColors.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(
                    ' و',
                    style: TextStyle(
                      fontSize: 12,
                      color: SamrahColors.textMuted,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(doc: 'privacy'),
                      ),
                    ),
                    child: const Text(
                      'سياسة الخصوصية',
                      style: TextStyle(
                        fontSize: 12,
                        color: SamrahColors.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _provider(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
