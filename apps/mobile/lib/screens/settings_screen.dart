// Settings — the player card, linked accounts, general settings, help and the
// app's version. Sound switches are live (Sound.instance); vibration is kept in
// AppSettings. Accounts, blocking, privacy, help… have no backend yet: they say
// «قريباً».
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/sound.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';

/// App-wide switches that are not sound (in memory for now, like the sound ones).
class AppSettings {
  static bool vibration = true;
  static bool showOnline = true;

  /// a light tap on the hand, if the player allows it
  static void tick() {
    if (vibration) HapticFeedback.selectionClick();
  }
}

const String kAppVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.playerName});
  final String playerName;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — قريباً'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الإعدادات', style: GoogleFonts.cairo(fontSize: 20))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          EnterFrom(child: _profileCard()),
          _sectionTitle('الحسابات'),
          _group([
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              child: Column(
                children: [
                  _accountButton(Icons.mail_outline, 'البريد الإلكتروني', const Color(0xFF2E9E4F)),
                  _accountButton(Icons.g_mobiledata_rounded, 'تسجيل الدخول باستخدام Google', SamrahColors.surface2, outlined: true),
                  _accountButton(Icons.phone_rounded, 'رقم الهاتف', const Color(0xFFD9A21E)),
                ],
              ),
            ),
            _divider(),
            InkWell(
              onTap: () => _soon('الدخول بحساب آخر'),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'الدخول بحساب آخر',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SamrahColors.text, decoration: TextDecoration.underline, decorationColor: SamrahColors.textMuted),
                ),
              ),
            ),
          ]),
          _sectionTitle('إعدادات عامة'),
          _group([
            _toggle('المؤثرات الصوتية', Sound.instance.effects, (v) => Sound.instance.effects = v),
            _divider(),
            _toggle('نطق الخيارات', Sound.instance.voice, (v) => Sound.instance.voice = v),
            _divider(),
            _toggle('الظهور أونلاين', AppSettings.showOnline, (v) => AppSettings.showOnline = v),
            _divider(),
            _toggle('الاهتزازات', AppSettings.vibration, (v) => AppSettings.vibration = v),
            _divider(),
            _row('اللغة', trailing: _pill('العربية', SamrahColors.accent, SamrahColors.onAccent)),
            _divider(),
            _row('الدولة', trailing: _pill('تغيير', SamrahColors.surface3, SamrahColors.text), onTap: () => _soon('تغيير الدولة')),
            _divider(),
            _link('قائمة المحظورين'),
            _divider(),
            _link('الأمان'),
            _divider(),
            _link('إعدادات الإشعارات'),
            _divider(),
            _link('إعدادات الخصوصية'),
          ]),
          _sectionTitle('المساعدة'),
          _group([
            _link('المساعدة'),
            _divider(),
            _link('شاركنا رأيك'),
          ]),
          _sectionTitle('إعدادات متقدمة'),
          _group([_link('إعدادات الحساب')]),
          const SizedBox(height: 22),
          Center(
            child: OutlinedButton(
              onPressed: () => _soon('سياسة الخصوصية والأحكام'),
              style: OutlinedButton.styleFrom(foregroundColor: SamrahColors.textMuted, side: const BorderSide(color: SamrahColors.fieldBorder)),
              child: const Text('سياسة الخصوصية والأحكام'),
            ),
          ),
          const SizedBox(height: 14),
          const Text('الإصدار $kAppVersion', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.accent, fontSize: 13)),
          const SizedBox(height: 24),
          Center(child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 40, semanticLabel: 'سمرة')),
        ],
      ),
    );
  }

  // --- player card ------------------------------------------------------------------

  Widget _profileCard() {
    final name = widget.playerName.trim();
    final letter = name.isNotEmpty ? name.substring(0, 1) : '؟';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SamrahColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    _smallButton(Icons.edit_outlined, 'تغيير', () => _soon('تغيير الاسم')),
                  ],
                ),
                const SizedBox(height: 14),
                // level progress: 1 → 2
                Row(
                  children: [
                    _levelBadge(1, SamrahColors.accent, SamrahColors.onAccent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: const LinearProgressIndicator(value: 0, minHeight: 10, color: SamrahColors.accent, backgroundColor: SamrahColors.scorebox),
                        ),
                      ),
                    ),
                    _levelBadge(2, SamrahColors.scorebox, SamrahColors.textMuted),
                  ],
                ),
                const SizedBox(height: 4),
                const Center(child: Text('0/100', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: SamrahColors.surface3,
                child: Text(letter, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 30, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              _smallButton(Icons.photo_camera_outlined, 'تغيير', () => _soon('تغيير الصورة')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(int n, Color bg, Color fg) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
        child: Text('$n', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
      );

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) => Material(
        color: SamrahColors.surface3,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: SamrahColors.text),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  // --- building blocks --------------------------------------------------------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: SamrahColors.line, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(title, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const Expanded(child: Divider(color: SamrahColors.line, thickness: 1)),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: SamrahColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SamrahColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _divider() => const Divider(height: 1, indent: 14, endIndent: 14, color: SamrahColors.line);

  Widget _row(String label, {Widget? trailing, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w500))),
              ?trailing,
            ],
          ),
        ),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> set) => _row(
        label,
        trailing: Switch(
          value: value,
          activeThumbColor: SamrahColors.onAccent,
          activeTrackColor: SamrahColors.accent,
          onChanged: (v) => setState(() => set(v)),
        ),
        onTap: () => setState(() => set(!value)),
      );

  Widget _link(String label) => _row(label, trailing: const Icon(Icons.chevron_left, color: SamrahColors.icon), onTap: () => _soon(label));

  Widget _pill(String label, Color bg, Color fg) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      );

  Widget _accountButton(IconData icon, String label, Color color, {bool outlined = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _soon(label),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            decoration: outlined ? BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: SamrahColors.fieldBorder)) : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: outlined ? 30 : 22),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
