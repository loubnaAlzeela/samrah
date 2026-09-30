// Room screen before the game starts: seat list + (host only) start button.
// Empty seats are filled with computer players when the host starts (server
// behaviour — see LammaRoom.handleStart), so no explicit "invite" flow is
// needed for this slice.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key, required this.view, required this.conn});

  final RoomView view;
  final RoomConnection conn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'رمز الغرفة: ${view.code}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 22, color: SamrahColors.onTableAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'اللاعبون',
            style: TextStyle(color: SamrahColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: view.seats.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = view.seats[i];
                return EnterFrom(
                  delay: Motion.stagger(i),
                  offset: const Offset(24, 0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: SamrahColors.surface2,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // a player taking the seat swaps in with a short fade + grow
                    title: AnimatedSwitcher(
                      duration: Motion.normal,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), alignment: Alignment.centerRight, child: child),
                      ),
                      layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                      child: Text(
                        s == null ? 'مقعد فارغ' : s.name,
                        key: ValueKey(s?.name),
                        style: const TextStyle(color: SamrahColors.text),
                      ),
                    ),
                    trailing: s == null
                        ? null
                        : Text(
                            s.bot ? 'حاسوب' : (s.connected ? 'متصل' : 'غير متصل'),
                            style: TextStyle(color: s.connected || s.bot ? SamrahColors.statusOpen : SamrahColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                  ),
                );
              },
            ),
          ),
          if (view.isOwner)
            ElevatedButton(onPressed: () => conn.send('start'), child: const Text('ابدأ اللعبة'))
          else
            const Breathe(
              amount: 0.03,
              period: Duration(milliseconds: 1600),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'بانتظار أن يبدأ المضيف اللعبة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SamrahColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
