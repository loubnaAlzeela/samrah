// الألعاب (`s-games`) — design/layout-v3.md §9: row cards, one per playable game.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';
import 'room_screen.dart';
import '../widgets/motion.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.playerName});
  final String playerName;

  @override
  Widget build(BuildContext context) {
    // (name, description, wire variant — null = not available yet)
    final games = <(String, String, String?)>[
      ('طرنيب', '4 لاعبين · فريقين', 'tarneeb'),
      ('طرنيب سوري 41', 'كل لاعب يطلب لنفسه', 'syrian41'),
      ('400', 'فريقين · كل لاعب يطلب لنفسه · الطرنيب كبة', 'tarneeb400'),
      ('تركس', '4 لاعبين · كل لاعب لنفسه', 'trix'),
      ('تركس شراكة', '4 لاعبين · فريقين', 'trixPartners'),
      ('لعبة 187', '4 أو 5 لاعبين · بيع وشراء', 'b187'),
      ('بلوت', '4 لاعبين · فريقين', 'baloot'),
      ('هاند سعودي', 'من 2 إلى 5 لاعبين · كل لاعب لنفسه', 'hand'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('الألعاب', style: GoogleFonts.cairo(fontSize: 20))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (name, desc, variant) = games[i];
          final available = variant != null;
          return EnterFrom(
            delay: Motion.stagger(i),
            offset: const Offset(0, 30),
            child: Opacity(
              opacity: available ? 1 : 0.55,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SamrahColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SamrahColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.style_outlined, color: SamrahColors.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.cairo(fontSize: 16, color: SamrahColors.text)),
                          Text(desc, style: const TextStyle(fontSize: 12, color: SamrahColors.textMuted)),
                        ],
                      ),
                    ),
                    if (available)
                      Pressable(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: SamrahColors.accent, foregroundColor: SamrahColors.onAccent, minimumSize: const Size(64, 40)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomScreen(initialName: playerName, autoOpen: true, variant: variant),
                            ),
                          ),
                          child: const Text('العب'),
                        ),
                      )
                    else
                      const Text('قريباً', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
