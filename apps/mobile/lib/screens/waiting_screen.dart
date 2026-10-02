// Room screen before the game starts: the table itself, with the players
// seated around it (me at the bottom, the others in playing order) and the
// room code on the felt, ready to copy or share. Empty seats pulse gently and
// are filled with computer players when the host starts (server behaviour —
// see LammaRoom.handleStart).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import '../widgets/table_stage.dart';
import 'room_screen.dart' show variantNameAr;

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key, required this.view, required this.onStart, this.onInvite});

  final RoomView view;
  /// host only: asks the server to start (empty seats get computer players)
  final VoidCallback onStart;

  /// opens the room's invite sheet (share the code / link)
  final VoidCallback? onInvite;

  int get _seated => view.seats.where((s) => s != null).length;

  @override
  Widget build(BuildContext context) {
    final n = view.seats.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnterFrom(
            child: Column(
              children: [
                Text(variantNameAr(view.variant), style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 4),
                _counter(n),
              ],
            ),
          ),
          Expanded(child: LayoutBuilder(builder: (context, box) => _table(context, box.biggest, n))),
          _bottom(n),
        ],
      ),
    );
  }

  Widget _counter(int n) {
    final full = _seated == n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: SamrahColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, size: 16, color: full ? SamrahColors.statusOpen : SamrahColors.textMuted),
          const SizedBox(width: 6),
          Text('$_seated من $n لاعبين', style: TextStyle(color: full ? SamrahColors.statusOpen : SamrahColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- the table ----------------------------------------------------------------------

  Widget _table(BuildContext context, Size size, int n) {
    final c = size.center(Offset.zero);
    final tableW = math.min(size.width * 0.5, 210.0);
    final tableH = math.min(size.height * 0.44, 260.0);
    // seats sit on an ellipse just outside the felt
    final rx = tableW / 2 + (n > 4 ? 56 : 44);
    final ry = tableH / 2 + (n > 4 ? 86 : 66);
    final me = view.mySeat ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: c.dx - tableW / 2,
          top: c.dy - tableH / 2,
          width: tableW,
          height: tableH,
          child: PopIn(
            from: 0.9,
            duration: Motion.slow,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const TableFelt(),
                Center(child: _codeOnFelt(context)),
              ],
            ),
          ),
        ),
        for (var i = 0; i < n; i++)
          () {
            // slot 0 = me at the bottom, then round the table: right, top, left
            final slot = (i - me) % n;
            final a = math.pi / 2 - slot * 2 * math.pi / n;
            final p = Offset(c.dx + rx * math.cos(a), c.dy + ry * math.sin(a));
            return Positioned(
              left: p.dx - 50,
              top: p.dy - 40,
              width: 100,
              child: EnterFrom(delay: Motion.stagger(slot + 1), offset: Offset.zero, child: _seat(i, view.seats[i], isMe: i == view.mySeat)),
            );
          }(),
      ],
    );
  }

  Widget _codeOnFelt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('رمز الغرفة', style: TextStyle(color: SamrahColors.onFeltMuted, fontSize: 13)),
        const SizedBox(height: 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            view.code,
            style: GoogleFonts.cairo(color: SamrahColors.onFeltAccent, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, height: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _feltButton(Icons.copy_rounded, 'نسخ', () {
              Clipboard.setData(ClipboardData(text: view.code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ رمز الغرفة'), duration: Duration(seconds: 2)));
            }),
            if (onInvite != null) ...[
              const SizedBox(width: 8),
              _feltButton(Icons.person_add_alt_1_rounded, 'دعوة', onInvite!),
            ],
          ],
        ),
      ],
    );
  }

  Widget _feltButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: SamrahColors.onFelt),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: SamrahColors.onFelt, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- one seat -------------------------------------------------------------------

  Widget _seat(int i, SeatInfo? s, {required bool isMe}) {
    final owner = view.ownerSeat == i;
    final Widget avatar;
    if (s == null) {
      avatar = Breathe(
        amount: 0.06,
        period: const Duration(milliseconds: 1600),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SamrahColors.surface,
            border: Border.all(color: SamrahColors.fieldBorder, width: 1.5),
          ),
          child: const Icon(Icons.add_rounded, color: SamrahColors.textMuted, size: 28),
        ),
      );
    } else {
      final letter = s.name.trim().isEmpty ? '؟' : s.name.trim().substring(0, 1);
      avatar = Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SamrahColors.avatarBg,
          border: Border.all(color: isMe ? SamrahColors.accent : SamrahColors.avatarRing, width: isMe ? 2.5 : 1.5),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: s.bot
            ? const Icon(Icons.smart_toy_outlined, color: SamrahColors.text, size: 28)
            : Text(letter, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 24, fontWeight: FontWeight.w700, height: 1.2)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            avatar,
            if (owner && s != null) const Positioned(top: -14, child: Icon(Icons.workspace_premium_rounded, color: SamrahColors.accent, size: 20)),
            // online dot
            if (s != null && !s.bot)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.connected ? SamrahColors.online : SamrahColors.disabledText,
                    border: Border.all(color: SamrahColors.bg, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // a player taking the seat swaps in with a short fade + grow
        AnimatedSwitcher(
          duration: Motion.normal,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child)),
          child: Container(
            key: ValueKey(s?.name),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: s == null ? Colors.transparent : SamrahColors.pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: s == null ? SamrahColors.line : (isMe ? SamrahColors.accent : SamrahColors.pillBorder)),
            ),
            child: Text(
              s == null ? 'بانتظار لاعب' : (isMe ? '${s.name} (أنت)' : s.name),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: s == null ? SamrahColors.textMuted : SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // --- start / wait --------------------------------------------------------------------

  Widget _bottom(int n) {
    final empty = n - _seated;
    final note = empty == 0 ? 'الطاولة مكتملة' : 'سيُكمل الحاسوب ${empty == 1 ? 'المقعد الفارغ' : 'المقاعد الفارغة ($empty)'}';
    if (!view.isOwner) {
      return const Breathe(
        amount: 0.03,
        period: Duration(milliseconds: 1600),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('بانتظار أن يبدأ المضيف اللعبة', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted, fontSize: 15)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(note, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Pressable(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text('ابدأ اللعبة', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ),
      ],
    );
  }
}
