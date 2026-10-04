// التنبيهات — everything the game told the player: club requests and approvals, competition matches and results,
// gifts, finished challenges, level-ups, team notices. Opening the list reads them; tapping one opens its screen.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_nav.dart';
import '../services/account.dart';
import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'chat_screen.dart' show shortTime;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.instance.get('/notifications') as List;
      if (!mounted) return;
      // private messages have their own screen
      setState(() => _list = [for (final n in list) if ((n as Map)['kind'] != 'messages') Map<String, dynamic>.from(n)]);
      await Api.instance.post('/notifications/read');
      Account.instance.markNotificationsRead();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  Future<void> _clear() async {
    try {
      await Api.instance.delete('/notifications');
      if (mounted) setState(() => _list = []);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  static IconData _icon(String? kind) => switch (kind) {
        'clubs' => Icons.shield_outlined,
        'competitions' => Icons.military_tech_outlined,
        'gifts' => Icons.card_giftcard_rounded,
        'challenges' => Icons.flag_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(
        title: Text('التنبيهات', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [if (list != null && list.isNotEmpty) TextButton(onPressed: _clear, child: const Text('امسح الكل'))],
      ),
      body: list == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')))
          : list.isEmpty
              ? const Center(child: Text('لا توجد تنبيهات', style: TextStyle(color: SamrahColors.textMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: SamrahColors.line),
                    itemBuilder: (_, i) {
                      final n = list[i];
                      final unread = n['read'] != true;
                      final data = n['data'] == null ? null : Map<String, dynamic>.from(n['data'] as Map);
                      return ListTile(
                        tileColor: unread ? SamrahColors.surface : null,
                        leading: CircleAvatar(backgroundColor: SamrahColors.surface2, child: Icon(_icon(n['kind'] as String?), color: SamrahColors.accent)),
                        title: Text(n['title'] as String, style: TextStyle(color: SamrahColors.text, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: Text(n['body'] as String, style: const TextStyle(color: SamrahColors.textMuted, height: 1.5)),
                        trailing: Text(shortTime(DateTime.fromMillisecondsSinceEpoch((n['at'] as num).toInt())), style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                        onTap: data == null ? null : () => openTarget(data),
                      );
                    },
                  ),
                ),
    );
  }
}
