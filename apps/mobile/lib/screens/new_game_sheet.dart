// «لعبة جديدة» bottom sheet — design/layout-v3.md §3. Tapping «أنشئ لعبة»
// closes the sheet and returns a partial `RoomSettings` map in the server's
// wire shape (packages/rules/src/protocol.ts); HomeScreen passes it straight
// to the room's `create` options.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';
import 'room_screen.dart' show variantNameAr;

class NewGameSheet extends StatefulWidget {
  const NewGameSheet({super.key, this.variant = 'tarneeb'});

  /// Syrian 41 always plays to 41, so the target row is hidden for it.
  final String variant;

  @override
  State<NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<NewGameSheet> {
  bool _private = true;
  bool _chat = true;
  bool _voiceChat = false;
  bool _kick = false;
  bool _noLeave = false;
  int _speed = 1; // 0 هادئة · 1 عادية · 2 سريعة
  int _target = 41; // 31 · 41 · 61
  int _players = 4; // 187: 4 أو 5 · هاند: 2..5

  /// Games whose table size is picked here (packages/rules engine.ts `playerChoices`).
  List<int>? get _playerChoices => switch (widget.variant) {
        'b187' => const [4, 5],
        'hand' => const [2, 3, 4, 5],
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: SamrahColors.icon)),
                    Expanded(child: Text('لعبة جديدة · ${variantNameAr(widget.variant)}', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 20, color: SamrahColors.text))),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _segRow('نوع اللعبة', [('لعبة عامة', !_private), ('لعبة خاصة', _private)], (i) => setState(() => _private = i == 1)),
                    _switchRow('دردشة', _chat, (v) => setState(() => _chat = v)),
                    _switchRow('الدردشة الصوتية', _voiceChat, (v) => setState(() => _voiceChat = v)),
                    _switchRow('إخراج اللاعبين', _kick, (v) => setState(() => _kick = v)),
                    _switchRow('بدون مغادرة', _noLeave, (v) => setState(() => _noLeave = v)),
                    _segRow('سرعة اللعب', [('هادئة', _speed == 0), ('عادية', _speed == 1), ('سريعة', _speed == 2)], (i) => setState(() => _speed = i)),
                    if (_playerChoices != null)
                      _segRow('عدد اللاعبين', [for (final n in _playerChoices!) ('$n', _players == n)], (i) => setState(() => _players = _playerChoices![i])),
                    if (widget.variant == 'tarneeb')
                      _segRow('النتيجة النهائية', [('31', _target == 31), ('41', _target == 41), ('61', _target == 61)], (i) => setState(() => _target = [31, 41, 61][i])),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop<Map<String, Object?>>(context, {
                    'visibility': _private ? 'private' : 'public',
                    'chat': _chat,
                    'voice': _voiceChat,
                    'kick': _kick,
                    'noLeave': _noLeave,
                    'speed': const ['slow', 'normal', 'fast'][_speed],
                    'target': widget.variant == 'tarneeb' ? _target : 41,
                    if (_playerChoices != null) 'players': _players,
                  }),
                  child: const Text('أنشئ لعبة'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SamrahColors.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w600))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: SamrahColors.onSelected, activeTrackColor: SamrahColors.selectedBg, inactiveTrackColor: SamrahColors.surface3),
        ],
      ),
    );
  }

  Widget _segRow(String label, List<(String, bool)> options, ValueChanged<int> onPick) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SamrahColors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onPick(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: options[i].$2 ? SamrahColors.selectedBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          options[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: options[i].$2 ? SamrahColors.onSelected : SamrahColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
