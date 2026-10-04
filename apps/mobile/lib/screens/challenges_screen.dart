// التحديات (`s-ch`) — design/layout-v3.md §9: a segmented اليوم / الأسبوع, then
// one card per task (title, 8px progress bar, the `2/3` counter) with its prize
// in stars; a finished task shows the orange «استلم» in its place (one at a time:
// the first claimable card gets it, the others a neutral button). Progress comes
// from the player's real games, counted by the server (lib/services/challenges.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/challenges.dart';
import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'store_screen.dart' show StarIcon;

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _ch = Challenges.instance;
  bool _weekly = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // the reset countdown
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _ch.load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _left(DateTime at) {
    final d = at.difference(DateTime.now());
    if (d.inDays >= 1) return '${d.inDays} يوم و${d.inHours % 24} ساعة';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التحديات', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [
          ListenableBuilder(
            listenable: Store.instance,
            builder: (_, _) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: SamrahColors.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const StarIcon(size: 16),
                    const SizedBox(width: 4),
                    CountUp(value: Store.instance.stars, style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _ch,
        builder: (context, _) {
          if (!_ch.loaded) {
            return Center(
              child: _ch.error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_ch.error!, style: const TextStyle(color: SamrahColors.textMuted)),
                      TextButton(onPressed: _ch.load, child: const Text('أعد المحاولة')),
                    ]),
            );
          }
          final list = _weekly ? _ch.weekly : _ch.daily;
          final firstClaimable = list.indexWhere((c) => c.claimable);
          final doneCount = list.where((c) => c.done).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.line)),
                child: Row(children: [
                  Expanded(child: _segment('اليوم', !_weekly, () => setState(() => _weekly = false), _ch.daily)),
                  Expanded(child: _segment('الأسبوع', _weekly, () => setState(() => _weekly = true), _ch.weekly)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('أنجزت $doneCount من ${list.length}', style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600))),
                const Icon(Icons.schedule, size: 15, color: SamrahColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'تتجدد بعد ${_left(_weekly ? Challenges.nextWeeklyReset() : Challenges.nextDailyReset())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              for (final (i, c) in list.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EnterFrom(
                    key: ValueKey('${_weekly}_${c.id}'),
                    delay: Motion.stagger(i),
                    offset: const Offset(0, 24),
                    child: _card(c, primary: i == firstClaimable),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'يُحسب التقدّم من جولاتك الحقيقية عند انتهاء كل جولة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SamrahColors.textMuted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap, List<Challenge> of) {
    final waiting = of.where((c) => c.claimable).length;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? SamrahColors.selectedBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: selected ? SamrahColors.onSelected : SamrahColors.textMuted, fontWeight: FontWeight.w700, fontSize: 14)),
            if (waiting > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: SamrahColors.suitRed, borderRadius: BorderRadius.circular(9)),
                child: Text('$waiting', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(Challenge c, {required bool primary}) {
    final Widget trailing;
    if (c.claimed) {
      trailing = const SizedBox(
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, color: SamrahColors.statusOpen, size: 26),
          Text('استُلمت', style: TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
        ]),
      );
    } else if (c.claimable) {
      Future<void> claim() async {
        final reward = c.reward;
        final messenger = ScaffoldMessenger.of(context);
        final err = await _ch.claim(c);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err ?? 'أُضيفت $reward نجمة إلى رصيدك'), duration: const Duration(seconds: 2)));
      }

      trailing = SizedBox(
        width: 80,
        child: primary
            ? ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44), padding: EdgeInsets.zero), onPressed: claim, child: const Text('استلم'))
            : OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(80, 44), padding: EdgeInsets.zero), onPressed: claim, child: const Text('استلم', style: TextStyle(fontWeight: FontWeight.w700))),
      );
    } else {
      trailing = SizedBox(
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const StarIcon(size: 26),
          Text('${c.reward}', style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return Opacity(
      opacity: c.claimed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SamrahColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.claimable ? SamrahColors.fieldBorder : SamrahColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Icon(c.icon, color: SamrahColors.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: (c.progress / c.goal).clamp(0.0, 1.0)),
                            duration: Motion.slow,
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: SamrahColors.scorebox,
                              color: c.done ? SamrahColors.statusOpen : SamrahColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${c.progress.clamp(0, c.goal)}/${c.goal}',
                        style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
