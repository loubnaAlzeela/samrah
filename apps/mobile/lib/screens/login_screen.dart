// Preliminary auth screens — UI only, no backend yet (no database exists).
// Both "تسجيل دخول" and "إنشاء حساب" just carry the name forward to
// HomeScreen for now. Replace with real auth once a database is built.
import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';
import 'home_screen.dart';
import '../widgets/motion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _isSignup = false;

  void _continue() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(playerName: name)));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
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
              Center(
                child: PopIn(
                  from: 0.7,
                  duration: Motion.slow,
                  child: Image.asset('assets/brand/samrah-mark.png', height: 130, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
              EnterFrom(
                delay: const Duration(milliseconds: 200),
                child: Center(
                  child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 44, fit: BoxFit.contain, semanticLabel: 'سمرة'),
                ),
              ),
              const SizedBox(height: 36),

              // Mode switch: دخول / حساب جديد — neutral segmented control (brass stays for the one primary button below).
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(child: _segment('تسجيل دخول', !_isSignup, () => setState(() => _isSignup = false))),
                    Expanded(child: _segment('حساب جديد', _isSignup, () => setState(() => _isSignup = true))),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'اسمك'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: _isSignup ? 'رقم الجوال أو البريد الإلكتروني' : 'رقم الجوال أو البريد الإلكتروني'),
              ),
              const SizedBox(height: 4),
              const Text(
                '(مؤقت — لا توجد حسابات حقيقية بعد، بانتظار قاعدة البيانات)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: SamrahColors.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _continue, child: Text(_isSignup ? 'إنشاء الحساب' : 'دخول')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  final n = _nameCtrl.text.trim();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(playerName: n.isEmpty ? 'ضيف' : n)));
                },
                child: const Text('متابعة كضيف', style: TextStyle(color: SamrahColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
