// الرسائل — private messages between players: the list of conversations (newest first, with unread counts), a
// conversation with one player (polled every few seconds while open), and a new message by player number.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'profile_screen.dart';

String shortTime(DateTime t) {
  final now = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) return hm;
  if (now.difference(t).inDays < 7) return '${const ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'][t.weekday - 1]} $hm';
  return '${t.year}/${t.month}/${t.day}';
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await Api.instance.get('/conversations') as List;
      if (!mounted) return;
      setState(() {
        _rows = [for (final r in list) Map<String, dynamic>.from(r as Map)];
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  Future<void> _newMessage() async {
    final ctrl = TextEditingController();
    final no = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('رسالة جديدة'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'رقم اللاعب', helperText: 'تجده في صفحة اللاعب أو في إعداداته'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('التالي')),
        ],
      ),
    );
    ctrl.dispose();
    if (no == null || no.isEmpty || !mounted) return;
    try {
      final p = await Api.instance.get('/users/$no') as Map;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(userId: p['id'] as String)));
      _load();
    } on ApiError catch (e) {
      if (mounted) say(context, errorText(e.code));
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final user = r['user'] as Map;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('حذف المحادثة مع ${user['name']}؟'),
        content: const Text('تُحذف من عندك فقط.', style: TextStyle(color: SamrahColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('احذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.delete('/conversations/${user['id']}');
      _load();
    } on ApiError catch (e) {
      if (mounted) say(context, errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text('الرسائل', style: GoogleFonts.cairo(fontSize: 20))),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SamrahColors.accent,
        foregroundColor: SamrahColors.onAccent,
        tooltip: 'رسالة جديدة',
        onPressed: _newMessage,
        child: const Icon(Icons.edit_outlined),
      ),
      body: rows == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')))
          : rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('لا توجد رسائل بعد.\nراسل لاعباً من صفحته، أو برقمه من زر الرسالة الجديدة.', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted, height: 1.7)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: SamrahColors.line),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final user = r['user'] as Map;
                      final last = r['last'] as Map;
                      final unread = (r['unread'] as num).toInt();
                      final mine = last['from'] == Account.instance.me?.id;
                      return ListTile(
                        leading: LetterAvatar(name: user['name'] as String),
                        title: Text(user['name'] as String, style: TextStyle(color: SamrahColors.text, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: Text('${mine ? 'أنت: ' : ''}${last['text']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.textMuted)),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(shortTime(DateTime.fromMillisecondsSinceEpoch((last['at'] as num).toInt())), style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                          if (unread > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: SamrahColors.accent, borderRadius: BorderRadius.circular(9)),
                              child: Text('$unread', style: const TextStyle(color: SamrahColors.onAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(userId: user['id'] as String)));
                          _load();
                        },
                        onLongPress: () => _delete(r),
                      );
                    },
                  ),
                ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.userId});
  final String userId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _sending = false;
  Timer? _timer;
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/messages/${widget.userId}') as Map;
      if (!mounted) return;
      final list = [for (final m in r['messages'] as List) Map<String, dynamic>.from(m as Map)];
      final grew = list.length != _messages.length;
      setState(() {
        _user = Map<String, dynamic>.from(r['user'] as Map);
        _messages = list;
        _error = null;
      });
      if (grew) {
        unawaited(Account.instance.refresh());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await Api.instance.post('/messages/${widget.userId}', {'text': t}) as Map;
      _text.clear();
      setState(() => _messages = [..._messages, Map<String, dynamic>.from(m)]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    } on ApiError catch (e) {
      if (mounted) say(context, errorText(e.code));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final me = Account.instance.me?.id;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: u == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userRef: widget.userId))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (u != null) LetterAvatar(name: u['name'] as String, radius: 16, online: u['online'] == true),
            const SizedBox(width: 8),
            Flexible(child: Text(u?['name'] as String? ?? '…', overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 18))),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _error != null && _messages.isEmpty
              ? Center(child: Text(_error!, style: const TextStyle(color: SamrahColors.textMuted)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final mine = m['from'] == me;
                    final at = DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt());
                    return Align(
                      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 290),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        decoration: BoxDecoration(color: mine ? SamrahColors.selectedBg : SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['text'] as String, style: TextStyle(color: mine ? SamrahColors.onSelected : SamrahColors.text, fontSize: 15)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(shortTime(at), style: TextStyle(color: mine ? SamrahColors.onFeltMuted : SamrahColors.textMuted, fontSize: 10)),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(m['read'] == true ? Icons.done_all : Icons.done, size: 12, color: SamrahColors.onFeltMuted),
                            ],
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        if (u != null && u['canMessage'] != true)
          const Padding(padding: EdgeInsets.all(12), child: Text('لا يمكنك مراسلة هذا اللاعب الآن.', style: TextStyle(color: SamrahColors.textMuted)))
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(hintText: 'اكتب رسالة', isDense: true, counterText: ''),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: SamrahColors.accent, foregroundColor: SamrahColors.onAccent, minimumSize: const Size(48, 48)),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded, textDirection: TextDirection.rtl),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
