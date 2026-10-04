// Another player's page: name, number, level, club and game record, with the ways to reach them (a private
// message) or keep them away (block, report). No photos: every player has the letter avatar.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'chat_screen.dart';
import 'room_screen.dart' show variantNameAr;

void say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// The letter avatar every player has.
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({super.key, required this.name, this.radius = 20, this.online = false});
  final String name;
  final double radius;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return Stack(clipBehavior: Clip.none, children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: SamrahColors.surface3,
        child: Text(t.isEmpty ? '؟' : t.characters.first, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: radius * 0.85, fontWeight: FontWeight.w700)),
      ),
      if (online)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: radius * 0.5,
            height: radius * 0.5,
            decoration: BoxDecoration(color: SamrahColors.statusOpen, shape: BoxShape.circle, border: Border.all(color: SamrahColors.bg, width: 2)),
          ),
        ),
    ]);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userRef});

  /// The player's id or number.
  final String userRef;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _p;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = Map<String, dynamic>.from(await Api.instance.get('/users/${widget.userRef}') as Map);
      if (mounted) setState(() => _p = p);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  bool get _isMe => _p?['id'] == Account.instance.me?.id;

  Future<void> _toggleBlock() async {
    final p = _p!;
    final blocked = p['blockedByMe'] == true;
    if (!blocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SamrahColors.surface,
          title: Text('حظر ${p['name']}؟'),
          content: const Text('لن تصلك رسائله ولا هداياه، ولن ترى رسائله في الطاولة والنادي. يمكنك رفع الحظر من الإعدادات.', style: TextStyle(color: SamrahColors.textMuted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('احظر')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      blocked ? await Account.instance.unblock(p['id'] as String) : await Account.instance.block(p['id'] as String);
      if (!mounted) return;
      say(context, blocked ? 'رُفع الحظر' : 'حُظر اللاعب');
      await _load();
    } on ApiError catch (e) {
      if (mounted) say(context, errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?['name'] as String? ?? 'اللاعب', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [
          if (p != null && !_isMe)
            PopupMenuButton<String>(
              color: SamrahColors.surface2,
              onSelected: (a) => a == 'block' ? _toggleBlock() : showReportSheet(context, p['id'] as String, p['name'] as String),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'block', child: Text(p['blockedByMe'] == true ? 'ارفع الحظر' : 'احظر')),
                const PopupMenuItem(value: 'report', child: Text('أبلغ عنه')),
              ],
            ),
        ],
      ),
      body: p == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!, style: const TextStyle(color: SamrahColors.textMuted)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: LetterAvatar(name: p['name'] as String, radius: 44, online: p['online'] == true)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(p['name'] as String, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w700))),
                  if (p['vip'] == true) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium, color: Color(0xFFE8C77A))],
                ]),
                Text(
                  'رقم اللاعب ${p['no']}${p['online'] == true ? ' · متصل الآن' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SamrahColors.textMuted),
                ),
                if (p['club'] != null) Text('نادي «${(p['club'] as Map)['name']}»', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.accent)),
                const SizedBox(height: 16),
                Row(children: [
                  _stat('المستوى', '${p['level']}'),
                  _stat('الجولات', '${p['played']}'),
                  _stat('الفوز', '${p['won']}'),
                  _stat('الهدايا', '${p['giftsReceived']}'),
                ]),
                const SizedBox(height: 16),
                if (!_isMe)
                  ElevatedButton.icon(
                    onPressed: p['canMessage'] == true ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(userId: p['id'] as String))) : null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(p['canMessage'] == true ? 'أرسل رسالة' : 'لا يستقبل رسائل'),
                  ),
                const SizedBox(height: 16),
                if ((p['byVariant'] as Map).isNotEmpty) ...[
                  Text('حسب اللعبة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700)),
                  for (final e in (p['byVariant'] as Map).entries)
                    ListTile(
                      dense: true,
                      title: Text(variantNameAr(e.key as String), style: const TextStyle(color: SamrahColors.text)),
                      trailing: Text('فاز ${(e.value as Map)['won']} من ${(e.value as Map)['played']}', style: const TextStyle(color: SamrahColors.textMuted)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        ]),
      );
}

/// Report a player: a reason from the list and a few words.
Future<void> showReportSheet(BuildContext context, String userId, String name, {String? where}) async {
  final reasons = List<String>.from(Account.instance.config['reportReasons'] as List? ?? const ['إساءة أو شتم', 'غش أو تلاعب', 'اسم غير لائق', 'إزعاج أو رسائل مزعجة', 'أخرى']);
  var reason = reasons.first;
  final text = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SamrahColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الإبلاغ عن $name', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: reason,
            onChanged: (v) => set(() => reason = v!),
            child: Column(children: [
              for (final r in reasons) RadioListTile<String>(value: r, title: Text(r, style: const TextStyle(color: SamrahColors.text)), dense: true),
            ]),
          ),
          TextField(controller: text, maxLines: 3, maxLength: 600, decoration: const InputDecoration(labelText: 'ماذا حدث؟ (اختياري)')),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              try {
                await Api.instance.post('/users/$userId/report', {'reason': reason, 'text': text.text, 'where': ?where});
                if (ctx.mounted) Navigator.pop(ctx, true);
              } on ApiError catch (e) {
                if (ctx.mounted) say(ctx, errorText(e.code));
              }
            },
            child: const Text('أرسل البلاغ'),
          ),
        ]),
      ),
    ),
  );
  text.dispose();
  if (sent == true && context.mounted) say(context, 'وصل بلاغك إلى فريق سمرة، شكراً لك');
}
