// The privacy policy, the terms of use and the club rules, as the server keeps them (apps/server/src/legal.ts:
// the same text is on the web for the stores).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.doc});

  /// 'privacy' | 'terms' | 'clubs'
  final String doc;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static Map<String, dynamic>? _cache;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_cache == null) _load();
  }

  Future<void> _load() async {
    try {
      final d = Map<String, dynamic>.from(await Api.instance.get('/legal') as Map);
      if (mounted) setState(() => _cache = d);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _cache?[widget.doc] as Map?;
    return Scaffold(
      appBar: AppBar(title: Text(doc?['title'] as String? ?? '', style: GoogleFonts.cairo(fontSize: 20))),
      body: doc == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text('آخر تحديث: ${doc['updated']}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                for (final section in doc['sections'] as List) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text((section as List)[0] as String, style: GoogleFonts.cairo(color: SamrahColors.accent, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  for (final item in section[1] as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 6, color: SamrahColors.textMuted)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item as String, style: const TextStyle(color: SamrahColors.text, fontSize: 14, height: 1.6))),
                      ]),
                    ),
                ],
              ],
            ),
    );
  }
}
