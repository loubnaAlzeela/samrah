// Settings — the player card (name, number, level), linked accounts (email, Google, phone; signing in with
// another account), general settings (sound and vibration are the phone's; online status, country, blocked
// players, security, notifications and privacy are the account's, on the server), help and feedback, the
// account itself (sign out, delete), and the privacy policy and terms.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/app_settings.dart';
import '../services/config.dart';
import '../services/error_text.dart';
import '../services/sound.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'auth_flows.dart';
import 'legal_screen.dart';
import 'profile_screen.dart';

export '../services/app_settings.dart' show AppSettings;

/// Countries offered in the settings (the Arab world first).
const kCountries = [
  ('SA', 'السعودية'), ('AE', 'الإمارات'), ('KW', 'الكويت'), ('QA', 'قطر'), ('BH', 'البحرين'), ('OM', 'عُمان'),
  ('JO', 'الأردن'), ('LB', 'لبنان'), ('SY', 'سوريا'), ('PS', 'فلسطين'), ('IQ', 'العراق'), ('YE', 'اليمن'),
  ('EG', 'مصر'), ('LY', 'ليبيا'), ('TN', 'تونس'), ('DZ', 'الجزائر'), ('MA', 'المغرب'), ('SD', 'السودان'),
  ('TR', 'تركيا'), ('DE', 'ألمانيا'), ('SE', 'السويد'), ('GB', 'بريطانيا'), ('US', 'أمريكا'), ('CA', 'كندا'),
];

String countryName(String? code) => kCountries.where((c) => c.$1 == code).firstOrNull?.$2 ?? 'غير محددة';

/// Runs an account change and says what happened.
Future<void> _apply(BuildContext context, Future<void> Function() f, [String? done]) async {
  try {
    await f();
    if (done != null && context.mounted) say(context, done);
  } on ApiError catch (e) {
    if (context.mounted) say(context, errorText(e.code));
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Account.instance,
      builder: (context, _) {
        final me = Account.instance.me;
        return Scaffold(
          appBar: AppBar(title: Text('الإعدادات', style: GoogleFonts.cairo(fontSize: 20))),
          body: me == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    EnterFrom(child: _profileCard(me)),
                    _sectionTitle('الحسابات'),
                    _group([
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                        child: Column(children: [
                          _accountButton(Icons.mail_outline, me.email != null ? 'البريد: ${me.email}' : 'البريد الإلكتروني', const Color(0xFF2E9E4F),
                              linked: me.email != null, onTap: () => showEmailSheet(context, link: true)),
                          _accountButton(Icons.g_mobiledata_rounded, me.google ? 'مربوط بحساب Google' : 'تسجيل الدخول باستخدام Google', SamrahColors.surface2, outlined: true, linked: me.google, onTap: () async {
                            final err = await continueWithGoogle();
                            if (context.mounted) say(context, err ?? 'رُبط حسابك بـ Google');
                          }),
                          _accountButton(Icons.phone_rounded, me.phone != null ? 'الهاتف: ${me.phone}' : 'رقم الهاتف', const Color(0xFFD9A21E), linked: me.phone != null, onTap: () async {
                            if (await showPhoneSheet(context) && context.mounted) say(context, 'رُبط رقم هاتفك بحسابك');
                          }),
                        ]),
                      ),
                      _divider(),
                      InkWell(
                        onTap: _otherAccount,
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('الدخول بحساب آخر', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.text, decoration: TextDecoration.underline, decorationColor: SamrahColors.textMuted)),
                        ),
                      ),
                    ]),
                    _sectionTitle('إعدادات عامة'),
                    _group([
                      _toggle('المؤثرات الصوتية', Sound.instance.effects, (v) => setState(() => Sound.instance.effects = v)),
                      _divider(),
                      _toggle('نطق الخيارات', Sound.instance.voice, (v) => setState(() => Sound.instance.voice = v)),
                      _divider(),
                      _toggle('الظهور أونلاين', me.setting('showOnline'), (v) => _apply(context, () => Account.instance.updateSettings({'showOnline': v}))),
                      _divider(),
                      _toggle('الاهتزازات', AppSettings.vibration, (v) => setState(() => AppSettings.vibration = v)),
                      _divider(),
                      _row('اللغة', trailing: _pill('العربية', SamrahColors.accent, SamrahColors.onAccent)),
                      _divider(),
                      _row('الدولة', trailing: _pill(countryName(me.country), SamrahColors.surface3, SamrahColors.text), onTap: _pickCountry),
                      _divider(),
                      _link('قائمة المحظورين', () => _push(const BlockedScreen())),
                      _divider(),
                      _link('الأمان', () => _push(const SecurityScreen())),
                      _divider(),
                      _link('إعدادات الإشعارات', () => _push(const NotificationSettingsScreen())),
                      _divider(),
                      _link('إعدادات الخصوصية', () => _push(const PrivacySettingsScreen())),
                    ]),
                    _sectionTitle('المساعدة'),
                    _group([
                      _link('المساعدة', () => _push(const HelpScreen())),
                      _divider(),
                      _link('شاركنا رأيك', () => _push(const FeedbackScreen())),
                    ]),
                    _sectionTitle('إعدادات متقدمة'),
                    _group([_link('إعدادات الحساب', () => _push(const AccountSettingsScreen()))]),
                    const SizedBox(height: 22),
                    Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                      OutlinedButton(
                        onPressed: () => _push(const LegalScreen(doc: 'privacy')),
                        style: OutlinedButton.styleFrom(foregroundColor: SamrahColors.textMuted, side: const BorderSide(color: SamrahColors.fieldBorder)),
                        child: const Text('سياسة الخصوصية'),
                      ),
                      OutlinedButton(
                        onPressed: () => _push(const LegalScreen(doc: 'terms')),
                        style: OutlinedButton.styleFrom(foregroundColor: SamrahColors.textMuted, side: const BorderSide(color: SamrahColors.fieldBorder)),
                        child: const Text('شروط الاستخدام'),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    const Text('الإصدار $kAppVersion', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.accent, fontSize: 13)),
                    const SizedBox(height: 24),
                    Center(child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 40, semanticLabel: 'سمرة')),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _otherAccount() async {
    final me = Account.instance.me!;
    final linked = me.email != null || me.phone != null || me.google;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('الدخول بحساب آخر؟'),
        content: Text(
          linked
              ? 'ستخرج من هذا الحساب، ويمكنك العودة إليه لاحقاً بالبريد أو الهاتف أو Google.'
              : 'حسابك الحالي غير مربوط ببريد أو هاتف أو Google: إن خرجت منه فلن تستطيع العودة إليه وستفقد رصيدك ومستواك. اربطه أولاً من الأعلى.',
          style: const TextStyle(color: SamrahColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(linked ? 'اخرج' : 'اخرج على أي حال')),
        ],
      ),
    );
    if (ok == true) await Account.instance.signOut();
  }

  Future<void> _pickCountry() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SamrahColors.surface,
      builder: (ctx) => ListView(children: [
        for (final (c, name) in kCountries) ListTile(title: Text(name, style: const TextStyle(color: SamrahColors.text)), onTap: () => Navigator.pop(ctx, c)),
      ]),
    );
    if (code != null && mounted) await _apply(context, () => Account.instance.update({'country': code}), 'حُفظت الدولة');
  }

  Future<void> _rename() async {
    final me = Account.instance.me!;
    final ctrl = TextEditingController(text: me.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('تغيير الاسم'),
        content: TextField(controller: ctrl, maxLength: 16, autofocus: true, decoration: const InputDecoration(helperText: 'مرة واحدة في اليوم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('احفظ')),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty && name != me.name && mounted) await _apply(context, () => Account.instance.update({'name': name}), 'تغيّر اسمك');
  }

  // --- player card ------------------------------------------------------------------

  Widget _profileCard(Me me) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: SamrahColors.line)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(me.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700))),
              _smallButton(Icons.edit_outlined, 'تغيير', _rename),
            ]),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${me.no}'));
                say(context, 'نُسخ رقمك');
              },
              child: Text('رقم اللاعب: ${me.no}  ⧉', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _levelBadge(me.level, SamrahColors.accent, SamrahColors.onAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: me.levelProgress, minHeight: 10, color: SamrahColors.accent, backgroundColor: SamrahColors.scorebox),
                  ),
                ),
              ),
              _levelBadge(me.level + 1, SamrahColors.scorebox, SamrahColors.textMuted),
            ]),
            const SizedBox(height: 4),
            Center(child: Text('${me.xp - me.levelFrom}/${me.levelTo - me.levelFrom}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12))),
          ]),
        ),
        const SizedBox(width: 14),
        LetterAvatar(name: me.name, radius: 38),
      ]),
    );
  }

  Widget _levelBadge(int n, Color bg, Color fg) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
        child: Text('$n', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: n > 99 ? 10 : 14)),
      );

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) => Material(
        color: SamrahColors.surface3,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: SamrahColors.text),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _accountButton(IconData icon, String label, Color color, {bool outlined = false, bool linked = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: outlined ? BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: SamrahColors.fieldBorder)) : null,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: outlined ? 30 : 22),
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              if (linked) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.white, size: 18)],
            ]),
          ),
        ),
      ),
    );
  }
}

// --- building blocks (shared by the settings pages) ------------------------------------

Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: SamrahColors.line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(title, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const Expanded(child: Divider(color: SamrahColors.line, thickness: 1)),
      ]),
    );

Widget _group(List<Widget> children) => Container(
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: SamrahColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );

Widget _divider() => const Divider(height: 1, indent: 14, endIndent: 14, color: SamrahColors.line);

Widget _row(String label, {Widget? trailing, VoidCallback? onTap, String? hint}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w500)),
              if (hint != null) Text(hint, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );

Widget _toggle(String label, bool value, ValueChanged<bool> set, {String? hint}) => _row(
      label,
      hint: hint,
      trailing: Switch(value: value, activeThumbColor: SamrahColors.onAccent, activeTrackColor: SamrahColors.accent, onChanged: set),
      onTap: () => set(!value),
    );

Widget _link(String label, VoidCallback onTap) => _row(label, trailing: const Icon(Icons.chevron_left, color: SamrahColors.icon), onTap: onTap);

Widget _pill(String label, Color bg, Color fg) => Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );

/// A settings page that follows the account.
class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.title, required this.children});
  final String title;
  final List<Widget> Function(BuildContext, Me) children;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Account.instance,
        builder: (context, _) {
          final me = Account.instance.me;
          return Scaffold(
            appBar: AppBar(title: Text(title, style: GoogleFonts.cairo(fontSize: 20))),
            body: me == null ? const SizedBox() : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: children(context, me)),
          );
        },
      );
}

// --- the pages -------------------------------------------------------------------------

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) => _AccountPage(
        title: 'قائمة المحظورين',
        children: (context, me) => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('المحظورون لا يراسلونك ولا يرسلون لك هدايا، ولا ترى رسائلهم في الطاولة والنادي. تحظر لاعباً من صفحته.', style: TextStyle(color: SamrahColors.textMuted, height: 1.6)),
          ),
          if (me.blocked.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: Text('لم تحظر أحداً', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted))),
          for (final b in me.blocked)
            ListTile(
              leading: LetterAvatar(name: b['name'] as String),
              title: Text(b['name'] as String, style: const TextStyle(color: SamrahColors.text)),
              subtitle: Text('رقم ${b['no']}', style: const TextStyle(color: SamrahColors.textMuted)),
              trailing: TextButton(onPressed: () => _apply(context, () => Account.instance.unblock(b['id'] as String), 'رُفع الحظر'), child: const Text('ارفع الحظر')),
            ),
        ],
      );
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) => _AccountPage(
        title: 'الأمان',
        children: (context, me) => [
          _sectionTitle('الدخول'),
          _group([
            _row('البريد وكلمة المرور', hint: me.email == null ? 'غير مربوط' : '${me.email}${me.hasPassword ? ' · كلمة المرور محفوظة' : ''}', trailing: const Icon(Icons.chevron_left, color: SamrahColors.icon), onTap: () => showEmailSheet(context, link: true)),
            _divider(),
            _row('رقم الهاتف', hint: me.phone ?? 'غير مربوط', trailing: const Icon(Icons.chevron_left, color: SamrahColors.icon), onTap: () => showPhoneSheet(context)),
            _divider(),
            _row('حساب Google', hint: me.google ? 'مربوط' : 'غير مربوط'),
          ]),
          _sectionTitle('الأجهزة'),
          _group([
            _row('الأجهزة المسجّل دخولها', trailing: Text('${me.sessions}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700))),
            _divider(),
            _row(
              'اخرج من كل الأجهزة الأخرى',
              hint: 'إن فقدت هاتفاً أو دخلت من جهاز غيرك',
              trailing: const Icon(Icons.logout, color: SamrahColors.icon),
              onTap: me.sessions <= 1 ? null : () => _apply(context, Account.instance.signOutOthers, 'خرجت من الأجهزة الأخرى'),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('لا يطلب منك فريق سمرة كلمة مرورك أبداً. لا تشاركها مع أحد.', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        ],
      );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const _kinds = [
    ('messages', 'الرسائل الخاصة'),
    ('clubs', 'النادي: الطلبات والدعوات والموافقة'),
    ('competitions', 'المسابقات: مبارياتك ونتائجها'),
    ('gifts', 'الهدايا'),
    ('challenges', 'إنجاز التحديات'),
    ('system', 'أخبار سمرة والمستويات'),
  ];

  @override
  Widget build(BuildContext context) => _AccountPage(
        title: 'إعدادات الإشعارات',
        children: (context, me) => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('اختر ما يصل إلى هاتفك. كل التنبيهات تبقى في قائمة التنبيهات داخل اللعبة.', style: TextStyle(color: SamrahColors.textMuted, height: 1.6)),
          ),
          _group([
            for (final (i, (k, label)) in _kinds.indexed) ...[
              if (i > 0) _divider(),
              _toggle(label, me.notifyOn(k), (v) => _apply(context, () => Account.instance.updateSettings({'notify': {k: v}}))),
            ],
          ]),
        ],
      );
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AccountPage(
        title: 'إعدادات الخصوصية',
        children: (context, me) => [
          const SizedBox(height: 8),
          _group([
            _toggle('الظهور أونلاين', me.setting('showOnline'), (v) => _apply(context, () => Account.instance.updateSettings({'showOnline': v})), hint: 'يرى الآخرون أنك متصل الآن'),
            _divider(),
            _toggle('استقبال الرسائل الخاصة', me.allowMessages == 'all', (v) => _apply(context, () => Account.instance.updateSettings({'allowMessages': v ? 'all' : 'none'}))),
            _divider(),
            _toggle('استقبال الهدايا', me.setting('allowGifts'), (v) => _apply(context, () => Account.instance.updateSettings({'allowGifts': v}))),
            _divider(),
            _toggle('الظهور في الترتيب', me.setting('showInRanking'), (v) => _apply(context, () => Account.instance.updateSettings({'showInRanking': v}))),
          ]),
          const SizedBox(height: 16),
          const Text('لا يرى أحد رصيدك أو بريدك أو هاتفك. يرى الآخرون اسمك ورقمك ومستواك وإحصاءات لعبك وناديك فقط.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12, height: 1.6)),
        ],
      );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('كيف أحفظ حسابي ورصيدي؟', 'اربط بريدك أو هاتفك أو حساب Google من الإعدادات ← الحسابات، فتستطيع الدخول إلى الحساب نفسه من أي هاتف.'),
    ('كيف أرفع مستواي؟', 'كل جولة تكملها تمنحك 20 نقطة خبرة، والفوز يمنحك 30 نقطة إضافية. يزيد المطلوب لكل مستوى 100 نقطة عن الذي قبله.'),
    ('ما الفرق بين الوحدات والنجوم؟', 'الوحدات لشراء ظهر الورق والطاولات والهدايا ورسوم المسابقات والأندية، وتأخذ منها هدية يومية. النجوم تكسبها من التحديات أو تشتريها، وبها تشترك في العضوية الذهبية.'),
    ('اشتريت ولم تصلني العملات', 'تُضاف فور تأكيد المتجر. إن تأخرت أغلق التطبيق وافتحه ليُعاد التحقق تلقائياً، وإن لم تصل فراسلنا من «شاركنا رأيك» مع وقت الشراء.'),
    ('انقطع اتصالي أثناء اللعب', 'يُحفظ مقعدك 90 ثانية، ويلعب الكمبيوتر عنك حتى تعود. ارجع إلى التطبيق وستعود إلى طاولتك.'),
    ('كيف أنضم إلى نادٍ أو أؤسس نادياً؟', 'من «الأندية» في الشريط السفلي. تأسيس النادي بـ5000 وحدة، ويُفعَّل بعد موافقة فريق سمرة.'),
    ('كيف أشترك في مسابقة؟', 'من «المسابقات» في الرئيسية. يصلك تنبيه حين تجهز مباراتك، وأمامك 3 دقائق لدخول الطاولة.'),
    ('لاعب يسيء إليّ', 'افتح صفحته من الطاولة أو النادي أو الرسائل، ثم احظره أو أبلغ عنه. يراجع فريق سمرة كل البلاغات.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('المساعدة', style: GoogleFonts.cairo(fontSize: 20))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final (q, a) in _faq)
            Card(
              color: SamrahColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(q, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [Text(a, style: const TextStyle(color: SamrahColors.textMuted, height: 1.7))],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
            icon: const Icon(Icons.support_agent),
            label: const Text('لم تجد جوابك؟ راسلنا'),
          ),
        ]),
      );
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _kind = 'idea';
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await Api.instance.post('/feedback', {'kind': _kind, 'text': _text.text});
      if (!mounted) return;
      say(context, 'وصلت رسالتك، شكراً لك!');
      Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) say(context, errorText(e.code));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('شاركنا رأيك', style: GoogleFonts.cairo(fontSize: 20))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('فكرة، أو مشكلة واجهتك، أو أي شيء تريد قوله لفريق سمرة.', style: TextStyle(color: SamrahColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final (k, label) in const [('idea', 'فكرة'), ('problem', 'مشكلة'), ('other', 'أخرى')])
              ChoiceChip(
                label: Text(label),
                selected: _kind == k,
                selectedColor: SamrahColors.selectedBg,
                labelStyle: TextStyle(color: _kind == k ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _text, minLines: 5, maxLines: 10, maxLength: 2000, decoration: const InputDecoration(labelText: 'اكتب هنا', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _busy ? null : _send, child: const Text('أرسل')),
        ]),
      );
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AccountPage(
        title: 'إعدادات الحساب',
        children: (context, me) => [
          const SizedBox(height: 8),
          _group([
            _row('رقم اللاعب', trailing: Text('${me.no}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700))),
            _divider(),
            _row('عضو منذ', trailing: Text(_date(me.raw['createdAt']), style: const TextStyle(color: SamrahColors.textMuted))),
            _divider(),
            _row('الجولات', trailing: Text('${me.played} · فاز ${me.won}', style: const TextStyle(color: SamrahColors.textMuted))),
            _divider(),
            _row('العضوية الذهبية', trailing: Text(me.vip ? 'حتى ${_date(me.raw['vipUntil'])}' : 'غير مشترك', style: const TextStyle(color: SamrahColors.textMuted))),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final linked = me.email != null || me.phone != null || me.google;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: SamrahColors.surface,
                  title: const Text('تسجيل الخروج؟'),
                  content: Text(
                    linked ? 'تعود إلى حسابك متى شئت بالبريد أو الهاتف أو Google.' : 'حسابك غير مربوط ببريد أو هاتف أو Google: لن تستطيع العودة إليه بعد الخروج.',
                    style: const TextStyle(color: SamrahColors.textMuted),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اخرج')),
                  ],
                ),
              );
              if (ok == true) await Account.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: SamrahColors.suitRed),
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف الحساب نهائياً'),
          ),
        ],
      );

  static String _date(Object? ms) {
    if (ms is! num) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return '${d.year}/${d.month}/${d.day}';
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('حذف الحساب نهائياً؟'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('يُحذف حسابك ورصيدك ومستواك ورسائلك، ولا يمكن التراجع. اكتب «احذف» للتأكيد.', style: TextStyle(color: SamrahColors.textMuted)),
          TextField(controller: confirm),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SamrahColors.suitRed),
            onPressed: () => Navigator.pop(ctx, confirm.text.trim() == 'احذف'),
            child: const Text('احذف'),
          ),
        ],
      ),
    );
    confirm.dispose();
    if (ok == true && context.mounted) await _apply(context, Account.instance.deleteAccount);
  }
}
