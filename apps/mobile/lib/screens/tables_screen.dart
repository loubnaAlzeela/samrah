// الألعاب العامة (`s-list`, design/layout-v3.md §7): the public tables of a game, live. A table with a free seat
// opens to a tap; a full one shows how far its game is. A private room is reached with its code.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'room_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key, required this.variant});
  final String variant;

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late String _variant = widget.variant;
  List<Map<String, dynamic>>? _tables;
  String? _error;
  Timer? _timer;

  static const _variants = ['tarneeb', 'syrian41', 'tarneeb400', 'trix', 'trixPartners', 'trixComplex', 'trixComplexPartners', 'b187', 'baloot', 'hand'];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await Api.instance.get('/tables', {'variant': _variant}) as List;
      if (!mounted) return;
      setState(() {
        _tables = [for (final t in list) Map<String, dynamic>.from(t as Map)];
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  void _join(String code) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(joinCode: code, variant: _variant)));

  Future<void> _byCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('ادخل غرفة برمزها'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: 'ABC234'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()), child: const Text('ادخل')),
        ],
      ),
    );
    ctrl.dispose();
    if (code != null && code.length == 6) _join(code);
  }

  @override
  Widget build(BuildContext context) {
    final tables = _tables;
    return Scaffold(
      appBar: AppBar(
        title: Text('الألعاب العامة', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [IconButton(tooltip: 'ادخل برمز', onPressed: _byCode, icon: const Icon(Icons.vpn_key_outlined))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SamrahColors.accent,
        foregroundColor: SamrahColors.onAccent,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(autoOpen: true, variant: _variant, settings: const {'visibility': 'public'}))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('افتح طاولة عامة', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final v in _variants)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(variantNameAr(v)),
                    selected: v == _variant,
                    selectedColor: SamrahColors.selectedBg,
                    labelStyle: TextStyle(color: v == _variant ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w600),
                    onSelected: (_) {
                      setState(() {
                        _variant = v;
                        _tables = null;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: tables == null
              ? Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')))
              : tables.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('لا توجد طاولات عامة في ${variantNameAr(_variant)} الآن.\nافتح طاولة ليجدك اللاعبون.', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, height: 1.7)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: tables.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _row(tables[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final seats = t['seats'] as List;
    final open = t['joinable'] == true;
    final free = seats.where((s) => s == null).length;
    final settings = Map<String, dynamic>.from(t['settings'] as Map? ?? const {});
    final playing = t['status'] == 'playing';
    final progress = ((t['progress'] as num?) ?? 0).toDouble() / 100;
    return Opacity(
      opacity: open ? 1 : 0.72,
      child: Material(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open ? () => _join(t['code'] as String) : null,
          child: Container(
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: SamrahColors.line)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    _setting(Icons.speed, {'slow': 'هادئة', 'fast': 'سريعة'}[settings['speed']] ?? 'عادية'),
                    if (settings['target'] != null) _setting(Icons.flag_outlined, '${settings['target']}'),
                    if (settings['chat'] == true) _setting(Icons.chat_bubble_outline, ''),
                    if ((settings['minLevel'] as num? ?? 1) > 1) _setting(Icons.military_tech_outlined, '${settings['minLevel']}+'),
                  ]),
                  const SizedBox(height: 8),
                  if (!playing)
                    Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: SamrahColors.statusOpen, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('لعبة جديدة · ${free == 1 ? 'مقعد واحد' : '$free مقاعد'}', style: const TextStyle(color: SamrahColors.statusOpen, fontWeight: FontWeight.w600, fontSize: 13)),
                    ])
                  else
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Stack(alignment: Alignment.center, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LinearProgressIndicator(value: progress, minHeight: 18, backgroundColor: SamrahColors.scorebox, color: const Color(0xFF3E5A45)),
                        ),
                        Text(open ? 'جارية · يمكنك أخذ مقعد الكمبيوتر' : 'لعبة ممتلئة', style: const TextStyle(color: SamrahColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in seats.take(5))
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: s == null
                          ? Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: SamrahColors.textMuted)),
                              child: const Icon(Icons.add, size: 16, color: SamrahColors.textMuted),
                            )
                          : CircleAvatar(
                              radius: 17,
                              backgroundColor: SamrahColors.surface3,
                              child: (s as Map)['bot'] == true
                                  ? const Icon(Icons.smart_toy_outlined, size: 16, color: SamrahColors.text)
                                  : Text((s['name'] as String).characters.first, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
                            ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _setting(IconData icon, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: SamrahColors.icon),
          if (label.isNotEmpty) ...[const SizedBox(width: 3), Text(label, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12))],
        ]),
      );
}
