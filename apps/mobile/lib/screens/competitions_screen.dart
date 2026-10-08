// المسابقات: the list, one competition's page (registration, knockout rounds
// played on real tables, the ten-minute review with complaints, the result),
// creating one (gold members only) and the terms. The server runs every rule
// (lib/services/competitions.dart); these screens poll it while open.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/competitions.dart';
import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'room_screen.dart';
import 'store_screen.dart';

const _gold = Color(0xFFE8C77A);

String _clock(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

(String, Color) _phaseLabel(CompPhase p) => switch (p) {
  CompPhase.registering => ('التسجيل مفتوح', SamrahColors.statusOpen),
  CompPhase.running => ('جارية', SamrahColors.accent),
  CompPhase.review => ('فترة الشكاوى', _gold),
  CompPhase.frozen => ('مجمّدة', SamrahColors.suitRed),
  CompPhase.finished => ('انتهت', SamrahColors.textMuted),
  CompPhase.cancelled => ('أُلغيت', SamrahColors.textMuted),
};

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}

Widget _num(int v, {double size = 14, Color color = SamrahColors.text}) => Text(
  '$v',
  style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700),
);

Widget _units(int v, {double size = 14}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    UnitIcon(size: size + 2),
    const SizedBox(width: 4),
    _num(v, size: size),
  ],
);

// ── the list ──────────────────────────────────────────────────────────────────

/// One tab per game: each game's competitions are kept apart, and a new one is
/// created for the game whose tab is open.
class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key, this.variant});

  /// Opens on this game's tab (the game picked on the home screen).
  final String? variant;

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> with SingleTickerProviderStateMixin {
  final _comps = Competitions.instance;
  static const _games = Competitions.games;
  late final _tab = TabController(length: _games.length, vsync: this, initialIndex: _games.indexWhere((g) => g.variant == widget.variant).clamp(0, _games.length - 1));
  int _filter = 0; // 0 المفتوحة · 1 مسابقاتي · 2 المنتهية

  CompGame get _game => _games[_tab.index];

  /// Each game's competitions, as last loaded (null = loading).
  final Map<String, List<Competition>?> _lists = {};
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      setState(() {});
      if (!_tab.indexIsChanging) _load();
    });
    _load();
    // the countdowns tick every second; the list itself is reloaded every 10
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (t.tick % 10 == 0) _load();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = _game;
    try {
      final l = await _comps.list(g.variant);
      if (mounted) {
        setState(() {
        _lists[g.variant] = l;
        _error = null;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المسابقات');
    }
  }

  List<Competition> _shown(CompGame g) {
    final done = {CompPhase.finished, CompPhase.cancelled};
    final ofGame = _lists[g.variant] ?? const <Competition>[];
    return switch (_filter) {
      1 => [
        for (final c in ofGame)
          if (c.mine || c.joined || c.myRequest != null) c,
      ],
      2 => [
        for (final c in ofGame)
          if (done.contains(c.phase)) c,
      ],
      _ => [
        for (final c in ofGame)
          if (!done.contains(c.phase)) c,
      ],
    };
  }

  Future<void> _open(Competition c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompetitionScreen(compId: c.id)));
    _load();
  }

  Future<void> _create() async {
    if (!Store.instance.vip) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SamrahColors.surface,
          title: Text('للأعضاء الذهبيين', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
          content: const Text('إنشاء المسابقات ميزة للمشتركين في العضوية الذهبية فقط. أما الاشتراك في المسابقات فمتاح للجميع.', style: TextStyle(color: SamrahColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لاحقاً', style: TextStyle(color: SamrahColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('العضوية'),
            ),
          ],
        ),
      );
      if (go == true && mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen(initialTab: StoreScreen.membershipTab)));
      return;
    }
    final c = await showModalBottomSheet<Competition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCompetitionSheet(game: _game),
    );
    if (c != null && mounted) _open(c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المسابقات', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: 'شروط المسابقات',
            icon: const Icon(Icons.gavel_rounded, color: SamrahColors.icon),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitionTermsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: SamrahColors.text,
          unselectedLabelColor: SamrahColors.textMuted,
          labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
          indicatorColor: SamrahColors.selectedBg,
          dividerColor: SamrahColors.line,
          tabs: [for (final g in _games) Tab(text: g.name, height: 44)],
        ),
      ),
      body: ListenableBuilder(
        listenable: _comps,
        builder: (context, _) => TabBarView(controller: _tab, children: [for (final g in _games) _list(g)]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SamrahColors.accent,
        foregroundColor: SamrahColors.onAccent,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text('أنشئ مسابقة ${_game.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _list(CompGame g) {
    if (_lists[g.variant] == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')));
    }
    final list = _shown(g);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            for (final (i, label) in ['المفتوحة', 'مسابقاتي', 'المنتهية'].indexed) ...[
              ChoiceChip(
                label: Text(label),
                selected: _filter == i,
                showCheckmark: false,
                selectedColor: SamrahColors.selectedBg,
                labelStyle: TextStyle(color: _filter == i ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _filter = i),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              _filter == 0 ? 'لا توجد مسابقات ${g.name} مفتوحة الآن.\nالأعضاء الذهبيون ينظّمونها، وتظهر هنا ليشترك فيها الجميع.' : 'لا توجد مسابقات ${g.name} هنا بعد',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SamrahColors.textMuted, height: 1.7),
            ),
          ),
        for (final (i, c) in list.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EnterFrom(
              key: ValueKey(c.id),
              delay: Motion.stagger(i),
              offset: const Offset(0, 24),
              child: _CompCard(comp: c, onTap: () => _open(c)),
            ),
          ),
      ],
    );
  }
}

class _CompCard extends StatelessWidget {
  const _CompCard({required this.comp, required this.onTap});
  final Competition comp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = comp;
    final (label, color) = _phaseLabel(c.phase);
    final tag = c.mine ? 'منظّمها أنت' : (c.joined ? 'أنت مشترك' : (c.myRequest != null ? 'طلبك قيد المراجعة' : null));
    return Material(
      color: SamrahColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tag != null ? SamrahColors.fieldBorder : SamrahColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.emoji_events_outlined, color: _gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                        ),
                        Text(
                          '${c.game.name}${c.game.targets.isEmpty ? '' : ' · ${c.target} نقطة'} · المنظم: ${c.organiser} (${c.organiserRating} نقطة تقييم)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _Pill(label, color),
                ],
              ),
              const SizedBox(height: 12),
              _SeatsBar(comp: c),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('الجائزة ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  _units(c.prize, size: 13),
                  const SizedBox(width: 14),
                  const Text('الاشتراك ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  c.fee == 0
                      ? const Text(
                          'مجاني',
                          style: TextStyle(color: SamrahColors.statusOpen, fontSize: 13, fontWeight: FontWeight.w700),
                        )
                      : _units(c.fee, size: 13),
                  const Spacer(),
                  if (c.phase == CompPhase.registering)
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: SamrahColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          _clock(c.deadline.difference(DateTime.now())),
                          style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                ],
              ),
              if (tag != null) ...[
                const SizedBox(height: 8),
                Text(
                  tag,
                  style: const TextStyle(color: SamrahColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

/// Seats taken out of the total, with a tick at the 75% needed to start.
class _SeatsBar extends StatelessWidget {
  const _SeatsBar({required this.comp});
  final Competition comp;

  @override
  Widget build(BuildContext context) {
    final c = comp;
    final filled = c.entrants.length / c.seats;
    final mark = c.minToStart / c.seats;
    final unit = c.game.partnership ? 'فريق' : 'لاعب';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'المقاعد ${c.entrants.length} من ${c.seats}',
              style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text('تبدأ بـ ${c.minToStart} $unit على الأقل', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, box) {
              return SizedBox(
                height: 10,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(5)),
                    ),
                    AnimatedContainer(
                      duration: Motion.normal,
                      width: box.maxWidth * filled.clamp(0.0, 1.0),
                      decoration: BoxDecoration(color: c.canStart ? SamrahColors.statusOpen : SamrahColors.accent, borderRadius: BorderRadius.circular(5)),
                    ),
                    Positioned(
                      left: box.maxWidth * mark - 1,
                      top: -3,
                      bottom: -3,
                      child: Container(width: 2, color: SamrahColors.text),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── one competition ───────────────────────────────────────────────────────────

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key, required this.compId});
  final String compId;

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  Competitions get _comps => Competitions.instance;
  Competition? _c;
  String? _error;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // the clocks tick every second; the competition is reloaded every 3
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (t.tick % 3 == 0) _load();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _comps.get(widget.compId);
      if (mounted) setState(() => _c = c);
    } catch (e) {
      if (mounted && _c == null) setState(() => _error = 'تعذّر تحميل المسابقة');
    }
  }

  /// Runs one action: the page shows the competition the server answers with, or the reason it refused.
  Future<bool> _run(Future<(Competition?, String?)> action, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final (c, err) = await action;
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (c != null) _c = c;
    });
    if (err != null) _say(context, err);
    if (err == null && done != null) _say(context, done);
    return err == null;
  }

  @override
  Widget build(BuildContext context) {
    final comp = _c;
    return Scaffold(
      appBar: AppBar(title: Text(comp?.title ?? 'المسابقة', style: GoogleFonts.cairo(fontSize: 19))),
      body: Builder(
        builder: (context) {
          if (comp == null) {
            return Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')));
          }
          final c = comp;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _summary(c),
              const SizedBox(height: 14),
              ...switch (c.phase) {
                CompPhase.registering => _registering(context, c),
                CompPhase.running => [if (c.myMatchRoom != null) ...[_myMatch(context, c), const SizedBox(height: 14)], _bracket(c)],
                CompPhase.review => [..._review(context, c), const SizedBox(height: 14), _bracket(c)],
                CompPhase.frozen => [..._frozen(context, c), const SizedBox(height: 14), _bracket(c)],
                CompPhase.finished => [_result(c), const SizedBox(height: 14), _bracket(c)],
                CompPhase.cancelled => [_cancelled(c)],
              },
              const SizedBox(height: 14),
              _entrants(context, c),
            ],
          );
        },
      ),
    );
  }

  Widget _box({required Widget child, Color border = SamrahColors.line}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SamrahColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: child,
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
        const Spacer(),
        value,
      ],
    ),
  );

  Widget _text(String t) => Text(
    t,
    style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _summary(Competition c) {
    final (label, color) = _phaseLabel(c.phase);
    final each = CompRules.prizePerPlayer(c.prize, c.game.partnership);
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${c.game.name} · ${c.game.partnership ? 'فرق من لاعبين' : 'فردي'}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
              ),
              _Pill(label, color),
            ],
          ),
          const SizedBox(height: 12),
          _SeatsBar(comp: c),
          const SizedBox(height: 8),
          _row('المنظم', _text(c.mine ? '${c.organiser} (أنت)' : '${c.organiser} · تقييمه ${c.organiserRating}')),
          _row('الجائزة', _units(c.prize)),
          if (c.game.partnership) _row('لكل لاعب في الفريق الفائز', _units(each)),
          _row('رسوم الاشتراك', c.fee == 0 ? _text('مجاني') : _units(c.fee)),
          if (c.game.targets.isNotEmpty) _row('النتيجة النهائية للمباراة', _text('${c.target} نقطة')),
          _row('النظام', _text(c.game.partnership ? 'خروج المغلوب' : 'طاولات من 4، يتأهل الأول والثاني')),
          if (c.phase == CompPhase.registering) _row('يُغلق التسجيل بعد', _text(_clock(c.deadline.difference(DateTime.now())))),
          if (c.phase == CompPhase.registering) _row('قبول الطلبات', _text(c.autoAccept ? 'تلقائي' : 'بموافقة المنظم')),
        ],
      ),
    );
  }

  List<Widget> _registering(BuildContext context, Competition c) {
    final out = <Widget>[];
    if (c.mine) {
      out.add(
        _box(
          border: SamrahColors.fieldBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title('لوحة المنظم'),
              ElevatedButton(
                onPressed: c.canStart && !_busy ? () => _run(_comps.startNow(c)) : null,
                child: Text(c.canStart ? 'ابدأ المسابقة الآن' : 'تحتاج ${c.minToStart - c.entrants.length} ${c.game.partnership ? 'فريقاً' : 'لاعباً'} آخر للبدء'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => _confirmCancel(context, c), child: const Text('ألغِ المسابقة')),
              const SizedBox(height: 8),
              Text(
                'إن لم يكتمل ${c.minToStart} من ${c.seats} عند انتهاء الوقت تُلغى المسابقة ويُخصم منك ${CompRules.cancelPenalty(c.seats)} وحدة، ويُعاد الباقي.',
                style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
      out.add(const SizedBox(height: 14));
      out.add(
        _box(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _title('طلبات الانضمام (${c.requests.length})')),
                  if (c.requests.isNotEmpty && !c.full) TextButton(onPressed: () => _run(_comps.acceptAll(c)), child: const Text('اقبل الكل')),
                ],
              ),
              if (c.requests.isEmpty) const Text('لا توجد طلبات الآن', style: TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
              for (final r in c.requests)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: _text(r.name)),
                      IconButton(
                        tooltip: 'ارفض',
                        onPressed: () => _run(_comps.answer(c, r.id, false)),
                        icon: const Icon(Icons.close_rounded, color: SamrahColors.suitRed),
                      ),
                      IconButton(
                        tooltip: 'اقبل',
                        onPressed: c.full ? null : () => _run(_comps.answer(c, r.id, true)),
                        icon: const Icon(Icons.check_rounded, color: SamrahColors.statusOpen),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      if (!c.joined) {
        out.add(const SizedBox(height: 14));
        out.add(OutlinedButton(onPressed: () => _join(context, c), child: Text(c.fee == 0 ? 'اشترك بنفسك' : 'اشترك بنفسك (${c.fee} وحدة)')));
      }
      return out;
    }
    if (c.joined || c.myRequest != null) {
      out.add(
        _box(
          border: SamrahColors.fieldBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.joined ? 'أنت مشترك في هذه المسابقة' : 'طلبك بانتظار موافقة المنظم',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                c.joined ? 'مقعدك: ${c.myEntry}' : 'دُفعت رسوم الاشتراك وتُعاد إن رُفض الطلب',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => _run(_comps.leave(c), done: 'انسحبت وأُعيدت الرسوم'), child: const Text('انسحب واسترجع الرسوم')),
            ],
          ),
        ),
      );
    } else {
      out.add(ElevatedButton(onPressed: c.full ? null : () => _join(context, c), child: Text(c.full ? 'المقاعد ممتلئة' : (c.fee == 0 ? 'اطلب الانضمام' : 'اطلب الانضمام (${c.fee} وحدة)'))));
    }
    return out;
  }

  Future<void> _join(BuildContext context, Competition c) async {
    String? partner;
    if (c.game.partnership) {
      final ctrl = TextEditingController();
      partner = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SamrahColors.surface,
          title: Text('شريكك في الفريق', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'رقم الشريك', helperText: 'رقم اللاعب يظهر في صفحته وفي إعداداته'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('اشترك'),
            ),
          ],
        ),
      );
      if (partner == null) return;
    }
    await _run(_comps.join(c, partner: partner), done: c.mine || c.autoAccept ? 'سُجّلت في المسابقة' : 'أُرسل طلبك إلى المنظم');
  }

  Future<void> _confirmCancel(BuildContext context, Competition c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('إلغاء المسابقة؟', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'يُخصم منك ${CompRules.cancelPenalty(c.seats)} وحدة (300 لكل مقعد)، ويُعاد إليك باقي الجائزة والعمولة، وتُعاد رسوم الاشتراك لكل اللاعبين.',
          style: const TextStyle(color: SamrahColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(color: SamrahColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ألغِها'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(_comps.cancel(c));
  }

  static String _roundName(int size, CompGame g) {
    if (size <= g.tableSize) return g.partnership ? 'النهائي' : 'الطاولة النهائية';
    if (!g.partnership) return 'دور الـ$size (${size ~/ g.tableSize} طاولات)';
    return switch (size) {
      4 => 'نصف النهائي',
      8 => 'ربع النهائي',
      _ => 'دور الـ$size',
    };
  }

  Widget _bracket(Competition c) {
    final g = c.game;
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(c.phase == CompPhase.running ? 'المباريات جارية…' : 'المباريات'),
          for (final (ri, round) in c.rounds.indexed)
            if (round.length > 1) ...[
              Text(
                _roundName(round.length, g),
                style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < round.length; i += g.tableSize)
                _table(
                  round.sublist(i, i + g.tableSize > round.length ? round.length : i + g.tableSize),
                  ri + 1 < c.rounds.length ? c.rounds[ri + 1].whereType<String>().toSet() : null,
                  c.myEntry,
                  versus: g.partnership,
                ),
              const SizedBox(height: 8),
            ],
          if (c.phase == CompPhase.running) const LinearProgressIndicator(minHeight: 3, color: SamrahColors.accent, backgroundColor: SamrahColors.scorebox),
        ],
      ),
    );
  }

  /// One table: «أ ضد ب» for two teams, a 2×2 grid of players otherwise. Those who
  /// went through are bold, the rest struck through, once the table is decided.
  Widget _table(List<String?> seats, Set<String>? through, String? me, {required bool versus}) {
    Widget seat(String? who) {
      final won = through != null && who != null && through.contains(who);
      final lost = through != null && who != null && !won;
      return Text(
        who ?? 'مقعد فارغ',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: who == null ? SamrahColors.disabledText : (lost ? SamrahColors.textMuted : SamrahColors.text),
          fontWeight: won || who == me ? FontWeight.w700 : FontWeight.w400,
          decoration: lost ? TextDecoration.lineThrough : null,
          fontSize: 13,
        ),
      );
    }

    final mine = me != null && seats.contains(me);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SamrahColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mine ? SamrahColors.accent : Colors.transparent),
      ),
      child: versus
          ? Row(
              children: [
                Expanded(child: seat(seats.first)),
                const Text('ضد', style: TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                Expanded(child: seat(seats.length > 1 ? seats[1] : null)),
              ],
            )
          : Column(
              children: [
                for (var r = 0; r < seats.length; r += 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: seat(seats[r])),
                        Expanded(child: seat(r + 1 < seats.length ? seats[r + 1] : null)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  List<Widget> _review(BuildContext context, Competition c) {
    final left = c.reviewEndsAt!.difference(DateTime.now());
    final cleared = c.entrants.where(c.clear.contains).length;
    final iAmIn = c.myEntry != null;
    final iCleared = iAmIn && c.clear.contains(c.myEntry);
    return [
      _box(
        border: _gold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _title('فترة الشكاوى')),
                Text(
                  _clock(left),
                  style: GoogleFonts.cairo(color: _gold, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Text(
              'الفائز: ${c.winner}',
              style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'راجِع تسجيلات مبارياتك. إن وجدت غشاً أو تخريباً فقدّم شكوى قبل انتهاء الوقت، فالسكوت يعني أنه لا شكوى لديك. تُوزَّع الجائزة بعد انتهاء هذه الفترة.',
              style: TextStyle(color: SamrahColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text('ضغط «لا توجد لدي أي شكاوى»: $cleared من ${c.entrants.length}', style: const TextStyle(color: SamrahColors.text, fontSize: 12)),
            if (iAmIn) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: iCleared ? null : () => _run(_comps.noComplaints(c)), child: Text(iCleared ? 'أكّدت أنه لا شكوى لديك' : 'لا توجد لدي أي شكاوى')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _complain(context, c), icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('قدّم شكوى')),
            ],
          ],
        ),
      ),
      if (c.complaints.isNotEmpty) ...[const SizedBox(height: 14), _complaints(c)],
    ];
  }

  Widget _complaints(Competition c) => _box(
    border: SamrahColors.suitRed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('الشكاوى (${c.complaints.length})'),
        for (final k in c.complaints)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${k.from} ← ${k.against}',
                  style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  k.type,
                  style: const TextStyle(color: SamrahColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(k.text, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _complain(BuildContext context, Competition c) async {
    final done = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintSheet(comp: c),
    );
    if (done != null && context.mounted) {
      _say(context, done);
      _load();
    }
  }

  List<Widget> _frozen(BuildContext context, Competition c) => [
    _box(
      border: SamrahColors.suitRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('المسابقة مجمّدة'),
          Text(
            c.mine
                ? 'انتهت فترة الشكاوى وفيها شكاوى مفتوحة. راجعها ثم احسم المسابقة. لن تُوزَّع الجائزة ولا حصتك من الرسوم قبل ذلك.'
                : 'انتهت فترة الشكاوى وفيها شكاوى مفتوحة. الجائزة موقوفة حتى يحسمها المنظم أو مراقب من فريق سمرة.',
            style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
          ),
          if (c.mine) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _run(_comps.settle(c, 'confirm')), child: const Text('اعتمد النتيجة ووزّع الجائزة')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _pickWinner(context, c), child: const Text('عيّن فائزاً آخر')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _run(_comps.settle(c, 'refund')), child: const Text('ألغِ النتيجة وأعِد رسوم الاشتراك')),
          ] else if (c.joined) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => _appeal(context, c), icon: const Icon(Icons.support_agent, size: 18), label: const Text('اعترض لدى فريق سمرة')),
          ],
        ],
      ),
    ),
    const SizedBox(height: 14),
    _complaints(c),
  ];

  Widget _result(Competition c) {
    final iWon = c.winner != null && c.winner == c.myEntry;
    return _box(
      border: iWon ? _gold : SamrahColors.line,
      child: Column(
        children: [
          Icon(Icons.emoji_events_rounded, size: 48, color: c.winner == null ? SamrahColors.textMuted : _gold),
          const SizedBox(height: 6),
          Text(
            c.winner == null ? 'لا فائز' : 'الفائز: ${c.winner}',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (iWon) ...[
            const SizedBox(height: 4),
            Text(
              'مبروك! أُضيفت ${CompRules.prizePerPlayer(c.prize, c.game.partnership)} وحدة إلى رصيدك',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w700),
            ),
          ],
          if (c.mine) ...[
            const SizedBox(height: 4),
            Text('حصتك كمنظم (90% من الرسوم): ${CompRules.organiserShare(c.fee, c.entrants.length)} وحدة', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
          if (c.note != null) ...[
            const SizedBox(height: 6),
            Text(
              c.note!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
            ),
          ],
          if (c.joined && !c.mine) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: () => _appeal(context, c), icon: const Icon(Icons.support_agent, size: 18), label: const Text('اعترض على قرار المنظم')),
          ],
        ],
      ),
    );
  }

  /// The match the player has to play now: its table opens with one tap.
  Widget _myMatch(BuildContext context, Competition c) => _box(
        border: SamrahColors.accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('مباراتك جاهزة'),
          const Text('ادخل الطاولة الآن. إن تأخرت أكثر من 3 دقائق يلعب الكمبيوتر مكانك وتخرج من المسابقة.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(joinCode: c.myMatchRoom!, variant: c.game.variant))),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ادخل المباراة'),
          ),
        ]),
      );

  Future<void> _pickWinner(BuildContext context, Competition c) async {
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('من الفائز؟'),
        children: [for (final e in c.entries) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.id), child: Text(e.name))],
      ),
    );
    if (id != null) await _run(_comps.settle(c, 'winner', winner: id));
  }

  Future<void> _appeal(BuildContext context, Competition c) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('اعتراض على قرار المنظم'),
        content: TextField(controller: ctrl, maxLines: 4, maxLength: 600, decoration: const InputDecoration(labelText: 'اشرح سبب اعتراضك')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('أرسل')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;
    await _run(_comps.appeal(c, text), done: 'وصل اعتراضك إلى فريق سمرة، وسيعيّن مراقباً ينظر فيه');
  }

  Future<void> _kick(BuildContext context, Competition c, CompEntry e) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: SamrahColors.surface,
        title: Text(e.name),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'kick'), child: const Text('أخرجه من المسابقة')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'bar'), child: const Text('أخرجه وامنعه من مسابقاتي')),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text('تبقى رسومه في المسابقة. وإن رأى فريق سمرة أن الإخراج بلا مبرر تُخصم الرسوم منك وتُعاد إليه، وتُمنع من المسابقات.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final ok = await _run(_comps.kick(c, e.id));
    if (ok && choice == 'bar' && _c != null) {
      for (final uid in e.userIds) {
        await _run(_comps.bar(_c!, uid));
      }
    }
  }

  Widget _cancelled(Competition c) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('أُلغيت المسابقة'),
        Text(c.note ?? '', style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          c.mine ? 'خُصم منك ${CompRules.cancelPenalty(c.seats)} وحدة وأُعيد إليك الباقي، وأُعيدت رسوم الاشتراك للاعبين.' : 'أُعيدت رسوم الاشتراك لكل المشاركين.',
          style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _entrants(BuildContext context, Competition c) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('المشاركون (${c.entrants.length})'),
        if (c.entrants.isEmpty) const Text('لا أحد بعد', style: TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in c.entries)
              InputChip(
                label: Text(e.name),
                side: BorderSide(color: e.name == c.myEntry ? SamrahColors.accent : SamrahColors.line),
                avatar: c.phase == CompPhase.review && c.clear.contains(e.name) ? const Icon(Icons.check_rounded, size: 16, color: SamrahColors.statusOpen) : null,
                // the organiser may remove an entry before the start
                onDeleted: c.mine && c.phase == CompPhase.registering && e.name != c.myEntry ? () => _kick(context, c, e) : null,
                deleteIcon: const Icon(Icons.more_horiz, size: 18),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ComplaintSheet extends StatefulWidget {
  const _ComplaintSheet({required this.comp});
  final Competition comp;

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  /// (id, name): the organiser, then every other entry.
  late final _others = [('organiser', widget.comp.organiser), for (final e in widget.comp.entries) if (e.id != widget.comp.myEntryId) (e.id, e.name)];
  late String _against = _others.first.$1;
  bool _busy = false;
  String _type = Competitions.complaintTypes.first;
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: SamrahColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'قدّم شكوى',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'تظهر الشكوى على صفحة المسابقة باسمك واسم المشتكى عليه ونوعها. الشكاوى الكيدية أو غير المفهومة قد تؤدي إلى حظر حسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SamrahColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _against,
                decoration: const InputDecoration(labelText: 'المشتكى عليه'),
                dropdownColor: SamrahColors.surface2,
                items: [for (final (id, name) in _others) DropdownMenuItem(value: id, child: Text(id == 'organiser' ? '$name (المنظم)' : name))],
                onChanged: (v) => setState(() => _against = v!),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in Competitions.complaintTypes)
                    ChoiceChip(
                      label: Text(t),
                      selected: _type == t,
                      showCheckmark: false,
                      selectedColor: SamrahColors.selectedBg,
                      labelStyle: TextStyle(color: _type == t ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(labelText: 'اشرح ما حدث بالتفصيل', errorText: _error, alignLabelWithHint: true),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final (_, err) = await Competitions.instance.complain(widget.comp, against: _against, type: _type, text: _text.text);
                        if (!context.mounted) return;
                        if (err != null) {
                          setState(() {
                            _busy = false;
                            _error = err;
                          });
                        } else {
                          Navigator.pop(context, 'قُدّمت الشكوى، ويمكنك سحبها قبل انتهاء الوقت بالضغط على «لا توجد لدي أي شكاوى»');
                        }
                      },
                child: const Text('أرسل الشكوى'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── creating one ──────────────────────────────────────────────────────────────

class CreateCompetitionSheet extends StatefulWidget {
  const CreateCompetitionSheet({super.key, required this.game});

  /// The game whose tab it was opened from.
  final CompGame game;

  @override
  State<CreateCompetitionSheet> createState() => _CreateCompetitionSheetState();
}

class _CreateCompetitionSheetState extends State<CreateCompetitionSheet> {
  final _title = TextEditingController();
  late final CompGame _game = widget.game;
  late int _seats = widget.game.seatOptions.contains(8) ? 8 : widget.game.seatOptions.first;
  int _fee = 100;
  int _prize = 2000;
  int _minutes = 30;
  bool _autoAccept = true;
  bool _agree = false;
  bool _busy = false;
  late int _target = widget.game.targets.contains(41) || widget.game.targets.isEmpty ? 41 : widget.game.targets.first;

  static const _fees = CompRules.fees;
  static const _prizes = CompRules.prizes;
  static const _times = CompRules.registrationMinutes;

  static String _timeLabel(int m) => switch (m) {
        10 => '10 د',
        30 => '30 د',
        60 => 'ساعة',
        180 => '3 ساعات',
        _ => 'يوم',
      };

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commission = CompRules.commission(_prize, _seats);
    final cost = CompRules.creationCost(_prize, _seats);
    final balance = Store.instance.units;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: SamrahColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'مسابقة ${_game.name} جديدة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'اسم المسابقة'),
            ),
            _label(_game.partnership ? 'عدد المقاعد (كل مقعد فريق من لاعبين)' : 'عدد المقاعد'),
            _seg([for (final s in _game.seatOptions) '$s'], _game.seatOptions.indexOf(_seats), (i) => setState(() => _seats = _game.seatOptions[i])),
            _label('رسوم الاشتراك'),
            _seg([for (final f in _fees) f == 0 ? 'مجاني' : '$f'], _fees.indexOf(_fee), (i) => setState(() => _fee = _fees[i])),
            _label('الجائزة'),
            _seg([for (final p in _prizes) '$p'], _prizes.indexOf(_prize), (i) => setState(() => _prize = _prizes[i])),
            if (_game.targets.length > 1) ...[
              _label('النتيجة النهائية للمباراة'),
              _seg([for (final t in _game.targets) '$t'], _game.targets.indexOf(_target), (i) => setState(() => _target = _game.targets[i])),
            ] else if (_game.targets.length == 1)
              _label('النتيجة النهائية: ${_game.targets.single} دائماً'),
            _label('مدة التسجيل'),
            _seg([for (final t in _times) _timeLabel(t)], _times.indexOf(_minutes), (i) => setState(() => _minutes = _times[i])),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoAccept,
              activeThumbColor: SamrahColors.selectedBg,
              onChanged: (v) => setState(() => _autoAccept = v),
              title: const Text('قبول الطلبات تلقائياً', style: TextStyle(color: SamrahColors.text)),
              subtitle: Text(_autoAccept ? 'من يشترك يأخذ مقعداً مباشرة' : 'تقبل كل طلب بنفسك', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  _line('الجائزة', _units(_prize)),
                  _line('العمولة (10% أو 300 لكل مقعد، أيهما أكبر)', _units(commission)),
                  const Divider(),
                  _line('يُخصم منك الآن', _units(cost)),
                  _line('رصيدك', _units(balance)),
                  const SizedBox(height: 6),
                  _note('تبدأ عند اكتمال ${CompRules.minToStart(_seats)} من $_seats مقعداً (75%). وإن لم تكتمل تُلغى ويُخصم منك ${CompRules.cancelPenalty(_seats)} وحدة ويُعاد الباقي.'),
                  _note('تحصل على 90% من رسوم الاشتراك عند انتهاء المسابقة: حتى ${CompRules.organiserShare(_fee, _seats)} وحدة إن امتلأت المقاعد.'),
                  if (_game.partnership) _note('يحصل كل لاعب في الفريق الفائز على نصف الجائزة: ${_prize ~/ 2} وحدة.'),
                  if (!_game.partnership) _note('اللعب على طاولات من 4، يتأهل الأول والثاني من كل طاولة، ويأخذ الفائز في الطاولة النهائية الجائزة كاملة.'),
                  _note('يبقى التسجيل مفتوحاً ${_timeLabel(_minutes)}، وتبدأ قبل ذلك إن امتلأت المقاعد أو بدأتها أنت بعد اكتمال 75%.'),
                ],
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              title: Wrap(children: [
                const Text('أوافق على ', style: TextStyle(color: SamrahColors.text, fontSize: 13)),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitionTermsScreen())),
                  child: const Text('شروط المسابقات', style: TextStyle(color: SamrahColors.accent, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: balance < cost || !_agree || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final (c, err) = await Competitions.instance.create(
                        title: _title.text,
                        game: _game,
                        seats: _seats,
                        fee: _fee,
                        prize: _prize,
                        target: _game.targets.isEmpty ? 0 : _target,
                        minutes: _minutes,
                        autoAccept: _autoAccept,
                      );
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (err != null) {
                        _say(context, err);
                      } else {
                        Navigator.pop(context, c);
                      }
                    },
              child: Text(balance < cost ? 'رصيدك لا يكفي' : 'أنشئ وادفع $cost وحدة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      t,
      style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  Widget _seg(List<String> labels, int selected, ValueChanged<int> onTap) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: SamrahColors.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SamrahColors.line),
    ),
    child: Row(
      children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: i == selected ? SamrahColors.selectedBg : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: i == selected ? SamrahColors.onSelected : SamrahColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _line(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        ),
        value,
      ],
    ),
  );

  Widget _note(String t) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 5, color: SamrahColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(t, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        ),
      ],
    ),
  );
}

// ── the terms ─────────────────────────────────────────────────────────────────

class CompetitionTermsScreen extends StatelessWidget {
  const CompetitionTermsScreen({super.key});

  static const _sections = [
    (
      'من ينظّم',
      [
        'إنشاء المسابقات متاح للمشتركين في العضوية الذهبية فقط، والاشتراك فيها متاح للجميع.',
        'لا يفتح المنظم أكثر من 3 مسابقات في الوقت نفسه، ويختار مدة التسجيل: من 10 دقائق إلى يوم كامل.',
        'المنظم مسؤول عن سير المسابقة بنزاهة ومن غير غش.',
        'يقبل المنظم طلبات الانضمام أو يرفضها، ويراجع الشكاوى ويتخذ ما يلزم، ويحدد قيمة الجائزة.',
        'لا يرى المنظم ولا المراقب أي بيانات خاصة عن اللاعبين، كرصيدهم أو بريدهم الإلكتروني.',
      ],
    ),
    (
      'البدء والإلغاء',
      [
        'تبدأ المسابقة إذا امتلأ 75% من مقاعدها على الأقل: مقعدان من 2، و3 من 4، و6 من 8، و12 من 16، و24 من 32.',
        'إن لم يكتمل هذا العدد تُلغى المسابقة ويُخصم من المنظم 300 وحدة عن كل مقعد (600 لمسابقة المقعدين وحتى 9600 لمسابقة الـ32)، ويُعاد كل ما سوى ذلك إلى المنظم واللاعبين.',
      ],
    ),
    (
      'المباريات',
      [
        'في ألعاب الشراكة يسجّل اللاعب فريقه برقم شريكه، ويجلس الشريكان متقابلين، وتكون المباريات فريقاً ضد فريق ويتأهل الفائز.',
        'في غيرها تكون الطاولات من 4 لاعبين، ويتأهل الأول والثاني من كل طاولة، والفائز في الطاولة النهائية يأخذ الجائزة.',
        'حين تجهز مباراتك يصلك تنبيه، وأمامك 3 دقائق لدخول الطاولة. من لا يحضر يلعب الكمبيوتر مكانه ويخرج من المسابقة.',
        'من ينقطع أثناء المباراة يلعب الكمبيوتر عنه حتى يعود.',
      ],
    ),
    (
      'الرسوم والجائزة',
      [
        'عند الإنشاء يُخصم من المنظم قيمة الجائزة، ومعها عمولة قدرها 10% من الجائزة أو 300 وحدة عن كل مقعد، أيهما أكبر.',
        'عند انتهاء المسابقة يحصل المنظم على 90% من رسوم الاشتراك التي دفعها اللاعبون.',
        'في ألعاب الشراكة يحصل كل لاعب في الفريق الفائز على نصف الجائزة، وفي غيرها يأخذ الفائز الجائزة كاملة.',
      ],
    ),
    (
      'فترة الشكاوى',
      [
        'بعد آخر مباراة تبدأ فترة انتظار مدتها 10 دقائق، يراجع فيها اللاعبون تسجيلات مبارياتهم ويقدّمون شكاواهم إن وجدوا غشاً أو تخريباً من المنظم أو من لاعبين آخرين.',
        'تظهر كل شكوى على صفحة المسابقة باسم المشتكي والمشتكى عليه ونوع الشكوى.',
        'على المشتكي أن يشرح شكواه بوضوح، والشكوى المكتوبة بكلام عشوائي أو غير مفهوم تُرفض وقد يُحظر صاحبها.',
        'من لم يشتكِ خلال الدقائق العشر يُعدّ أنه لا شكوى لديه، ويستطيع اللاعب سحب شكواه خلالها بالضغط على «لا توجد لدي أي شكاوى».',
        'إذا انتهت الفترة من غير شكاوى، أو ضغط كل اللاعبين «لا توجد لدي أي شكاوى»، تنتهي المسابقة وتُوزَّع الجائزة.',
        'وإن بقيت شكاوى مفتوحة تُجمَّد المسابقة، ولا تُوزَّع الجائزة ولا حصة المنظم حتى يحسمها المنظم أو فريق سمرة.',
      ],
    ),
    (
      'صلاحيات المنظم وحدودها',
      [
        'للمنظم أن يعيد تعيين الفائزين، أو يعيد رسوم الاشتراك، أو يحظر لاعباً من دخول المسابقات أو إنشائها.',
        'إن طرد المنظم لاعباً من غير مبرر، تُخصم رسوم اشتراك اللاعب من المنظم وتُعاد إليه، ويُحظر المنظم من دخول المسابقات وتنظيمها.',
        'للمنظم والمراقب حظر من يقدّم بلاغات كاذبة أو كيدية.',
      ],
    ),
    (
      'الاعتراض والتقييم',
      [
        'يستطيع اللاعب الاعتراض على قرار المنظم إن رأى فيه خطأ، فيعيّن فريق سمرة مراقباً ينظر فيه.',
        'يحصل المنظم على نقاط تقييم بعد كل مسابقة، بحسب سرعة بدئها، ورسومها وجائزتها، ووجود فائزين في نهايتها، وصحة إجراءاته. وللمراقب أن يخصم من نقاطه إن أخطأ.',
        'الشكوى على مراقب تكون عبر نظام المساعدة.',
      ],
    ),
    ('أحكام عامة', ['إن حُظر لاعب من نظام المسابقات فلا يتحمّل فريق سمرة إعادة رسومه في المسابقات الأخرى التي اشترك فيها.', 'إن وقع خلل فني في التطبيق يعوّض فريق سمرة اللاعبين المتضررين.']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('شروط المسابقات', style: GoogleFonts.cairo(fontSize: 20))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final (title, items) in _sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                title,
                style: GoogleFonts.cairo(color: SamrahColors.accent, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.circle, size: 6, color: SamrahColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t, style: const TextStyle(color: SamrahColors.text, fontSize: 14, height: 1.6)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
