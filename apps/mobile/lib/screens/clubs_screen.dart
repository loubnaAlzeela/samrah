// الأندية (`s-clubs`) — design/layout-v3.md §9: locked until level 5 (a 120
// circle with the shield, «الأندية» 24px, the unlock line and the level bar).
// Past the lock (a demo button for now): browse and join clubs, or found one;
// a club's page has its chat, members (with join requests and moderation) and
// the weekly ranking of clubs. DEMO — driven by lib/services/clubs.dart.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/clubs.dart';
import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'store_screen.dart' show UnitIcon;

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// The club's emblem on its colour.
class ClubEmblem extends StatelessWidget {
  const ClubEmblem({super.key, required this.icon, required this.color, this.size = 48});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color], center: const Alignment(-0.3, -0.4)),
          border: Border.all(color: SamrahColors.cardFace, width: size * 0.04),
        ),
        child: Icon(icon, color: SamrahColors.cardFace, size: size * 0.52),
      );
}

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key, required this.playerName});
  final String playerName;

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _clubs = Clubs.instance;

  @override
  void initState() {
    super.initState();
    _clubs.setPlayer(widget.playerName);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _clubs,
      builder: (context, _) {
        if (!_clubs.demoUnlocked) return _Locked(onDemo: _clubs.unlockDemo);
        final mine = _clubs.myClub;
        return mine != null ? _ClubHome(club: mine) : const _Browse();
      },
    );
  }
}

// ── locked ────────────────────────────────────────────────────────────────────

class _Locked extends StatelessWidget {
  const _Locked({required this.onDemo});
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    const perks = [
      (Icons.groups_rounded, 'انضم إلى نادٍ أو أسّس ناديك'),
      (Icons.forum_outlined, 'دردشة خاصة بأعضاء النادي'),
      (Icons.leaderboard_outlined, 'اجمعوا النقاط معاً وتنافسوا في الترتيب الأسبوعي'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('الأندية', style: GoogleFonts.cairo(fontSize: 20))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.shield_outlined, size: 56, color: SamrahColors.icon),
                  Positioned(
                    bottom: 18,
                    right: 22,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: SamrahColors.bg, shape: BoxShape.circle),
                      child: const Icon(Icons.lock, size: 18, color: SamrahColors.textMuted),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('الأندية', style: GoogleFonts.cairo(fontSize: 24, color: SamrahColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('تُفتح عند وصولك إلى المستوى ${Clubs.unlockLevel}', style: TextStyle(color: SamrahColors.textMuted, fontSize: 15)),
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: SamrahColors.selectedBg, shape: BoxShape.circle),
                      child: const Text('1', style: TextStyle(color: SamrahColors.onSelected, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(value: 0, minHeight: 8, backgroundColor: SamrahColors.scorebox, color: SamrahColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('${Clubs.unlockLevel}', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              for (final (icon, text) in perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 20, color: SamrahColors.icon),
                    const SizedBox(width: 10),
                    Flexible(child: Text(text, style: const TextStyle(color: SamrahColors.text, fontSize: 14))),
                  ]),
                ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onDemo,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('جرّبها الآن (نسخة تجريبية)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── browsing ──────────────────────────────────────────────────────────────────

class _Browse extends StatefulWidget {
  const _Browse();

  @override
  State<_Browse> createState() => _BrowseState();
}

class _BrowseState extends State<_Browse> {
  final _clubs = Clubs.instance;
  String _query = '';

  Future<void> _create() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _CreateClubSheet());
  }

  @override
  Widget build(BuildContext context) {
    final list = _clubs.ranking.where((c) => _query.isEmpty || c.name.contains(_query)).toList();
    final pending = _clubs.pendingId == null ? null : _clubs.all.where((c) => c.id == _clubs.pendingId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('الأندية', style: GoogleFonts.cairo(fontSize: 20))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'ابحث عن نادٍ', prefixIcon: Icon(Icons.search, color: SamrahColors.textMuted)),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          if (pending != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.fieldBorder)),
              child: Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SamrahColors.accent)),
                const SizedBox(width: 10),
                Expanded(child: Text('طلبك للانضمام إلى «${pending.name}» بانتظار موافقة المشرفين', style: const TextStyle(color: SamrahColors.text, fontSize: 13))),
                TextButton(onPressed: _clubs.cancelRequest, child: const Text('إلغاء')),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: Text('لا توجد أندية بهذا الاسم', textAlign: TextAlign.center, style: TextStyle(color: SamrahColors.textMuted))),
          for (final (i, c) in list.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnterFrom(key: ValueKey(c.id), delay: Motion.stagger(i), offset: const Offset(0, 24), child: _ClubRow(club: c, rank: _clubs.ranking.indexOf(c) + 1, onTap: () => _details(c))),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SamrahColors.accent,
        foregroundColor: SamrahColors.onAccent,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('أسّس نادياً', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _details(Club c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubDetailsSheet(club: c),
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club, required this.rank, required this.onTap});
  final Club club;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = club;
    return Material(
      color: SamrahColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: SamrahColors.line)),
          child: Row(children: [
            ClubEmblem(icon: c.emblem, color: c.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
                Text(c.motto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, children: [
                  _meta(Icons.group_outlined, '${c.members.length}/${Clubs.maxMembers}'),
                  _meta(Icons.military_tech_outlined, 'مستوى ${c.level}'),
                  _meta(c.open ? Icons.lock_open_rounded : Icons.how_to_reg_outlined, c.open ? 'مفتوح' : 'بموافقة'),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(children: [
              Text('#$rank', style: const TextStyle(color: SamrahColors.accent, fontSize: 13, fontWeight: FontWeight.w800)),
              Text('${c.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
              const Text('نقطة', style: TextStyle(color: SamrahColors.textMuted, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: SamrahColors.textMuted),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
      ]);
}

class _ClubDetailsSheet extends StatelessWidget {
  const _ClubDetailsSheet({required this.club});
  final Club club;

  @override
  Widget build(BuildContext context) {
    final clubs = Clubs.instance;
    final c = club;
    final president = c.members.firstWhere((m) => m.role == ClubRole.president);
    final top = [...c.members]..sort((a, b) => b.weekPoints.compareTo(a.weekPoints));
    final pendingHere = clubs.pendingId == c.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Center(child: ClubEmblem(icon: c.emblem, color: c.color, size: 72)),
          const SizedBox(height: 8),
          Text(c.name, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(c.motto, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            _stat('الأعضاء', '${c.members.length}/${Clubs.maxMembers}'),
            _stat('المستوى', '${c.level}'),
            _stat('نقاط الأسبوع', '${c.weekPoints}'),
            _stat('أقل مستوى', '${c.minLevel}'),
          ]),
          const SizedBox(height: 12),
          Text('الرئيس: ${president.name}', style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
          const SizedBox(height: 4),
          Text('الأكثر نقاطاً: ${top.take(3).map((m) => m.name).join('، ')}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: c.full || pendingHere || clubs.pendingId != null
                ? null
                : () {
                    final err = clubs.join(c);
                    Navigator.pop(context);
                    _say(context, err ?? (c.open ? 'انضممت إلى «${c.name}»' : 'أُرسل طلبك إلى مشرفي النادي'));
                  },
            child: Text(c.full ? 'النادي ممتلئ' : (pendingHere ? 'طلبك قيد المراجعة' : (c.open ? 'انضم' : 'اطلب الانضمام'))),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
        ]),
      );
}

// ── founding ──────────────────────────────────────────────────────────────────

class _CreateClubSheet extends StatefulWidget {
  const _CreateClubSheet();

  @override
  State<_CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends State<_CreateClubSheet> {
  final _name = TextEditingController();
  final _motto = TextEditingController();
  IconData _emblem = Clubs.emblems.first;
  Color _color = Clubs.colors.first;
  bool _open = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _motto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = Store.instance.units;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('نادٍ جديد', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Center(child: ClubEmblem(icon: _emblem, color: _color, size: 80)),
            const SizedBox(height: 16),
            TextField(controller: _name, maxLength: 24, decoration: InputDecoration(labelText: 'اسم النادي', errorText: _error)),
            TextField(controller: _motto, maxLength: 40, decoration: const InputDecoration(labelText: 'شعار النادي (جملة قصيرة)')),
            const SizedBox(height: 6),
            const Text('الرمز', style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in Clubs.emblems)
                _pick(selected: e == _emblem, onTap: () => setState(() => _emblem = e), child: Icon(e, color: SamrahColors.icon)),
            ]),
            const SizedBox(height: 14),
            const Text('اللون', style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in Clubs.colors)
                _pick(selected: c == _color, onTap: () => setState(() => _color = c), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _open,
              activeThumbColor: SamrahColors.selectedBg,
              onChanged: (v) => setState(() => _open = v),
              title: const Text('مفتوح للجميع', style: TextStyle(color: SamrahColors.text)),
              subtitle: Text(_open ? 'من يطلب ينضم مباشرة' : 'تقبل أنت ومشرفوك طلبات الانضمام', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('تكلفة التأسيس', style: TextStyle(color: SamrahColors.textMuted))),
              const UnitIcon(size: 18),
              const SizedBox(width: 4),
              const Text('${Clubs.createCost}', style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: balance < Clubs.createCost
                  ? null
                  : () {
                      final err = Clubs.instance.create(name: _name.text, motto: _motto.text, emblem: _emblem, color: _color, open: _open);
                      if (err != null) {
                        setState(() => _error = err);
                      } else {
                        Navigator.pop(context);
                        _say(context, 'أسّست النادي، وصرت رئيسه');
                      }
                    },
              child: Text(balance < Clubs.createCost ? 'رصيدك لا يكفي' : 'أسّس النادي'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pick({required bool selected, required VoidCallback onTap, required Widget child}) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SamrahColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? SamrahColors.selectedBg : SamrahColors.line, width: selected ? 2 : 1),
          ),
          child: child,
        ),
      );
}

// ── the player's club ─────────────────────────────────────────────────────────

class _ClubHome extends StatefulWidget {
  const _ClubHome({required this.club});
  final Club club;

  @override
  State<_ClubHome> createState() => _ClubHomeState();
}

class _ClubHomeState extends State<_ClubHome> with SingleTickerProviderStateMixin {
  final _clubs = Clubs.instance;
  late final _tab = TabController(length: 3, vsync: this);
  final _msg = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _tab.dispose();
    _msg.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Club get c => widget.club;

  Future<void> _leave() async {
    final president = _clubs.myMember?.role == ClubRole.president;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('مغادرة «${c.name}»؟', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          president ? 'أنت الرئيس: ستنتقل الرئاسة إلى أحد المشرفين. وإن كنت العضو الوحيد يُحذف النادي.' : 'تخرج من النادي ودردشته، ويمكنك الانضمام إلى نادٍ آخر.',
          style: const TextStyle(color: SamrahColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع', style: TextStyle(color: SamrahColors.textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('غادر')),
        ],
      ),
    );
    if (ok == true) _clubs.leave();
  }

  Future<void> _settings() async {
    final motto = TextEditingController(text: c.motto);
    var open = c.open;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: SamrahColors.surface,
          title: Text('إعدادات النادي', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: motto, maxLength: 40, decoration: const InputDecoration(labelText: 'الشعار')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: open,
              activeThumbColor: SamrahColors.selectedBg,
              onChanged: (v) => set(() => open = v),
              title: const Text('مفتوح للجميع'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () {
                _clubs.updateSettings(motto: motto.text, open: open);
                Navigator.pop(ctx);
              },
              child: const Text('احفظ'),
            ),
          ],
        ),
      ),
    );
    motto.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = _clubs.ranking.indexOf(c) + 1;
    final president = _clubs.myMember?.role == ClubRole.president;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name, style: GoogleFonts.cairo(fontSize: 19)),
        actions: [
          if (president) IconButton(tooltip: 'إعدادات النادي', onPressed: _settings, icon: const Icon(Icons.tune_rounded, color: SamrahColors.icon)),
          IconButton(tooltip: 'غادر النادي', onPressed: _leave, icon: const Icon(Icons.logout_rounded, color: SamrahColors.icon)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                ClubEmblem(icon: c.emblem, color: c.color, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.motto.isEmpty ? 'بلا شعار' : c.motto, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('مستوى ${c.level} · ${c.members.length}/${Clubs.maxMembers} عضواً · ${c.open ? 'مفتوح' : 'بموافقة'}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  ]),
                ),
                Column(children: [
                  Text('#$rank', style: GoogleFonts.cairo(color: SamrahColors.accent, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  Text('${c.weekPoints} نقطة', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                ]),
              ]),
            ),
            TabBar(
              controller: _tab,
              labelColor: SamrahColors.text,
              unselectedLabelColor: SamrahColors.textMuted,
              labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
              indicatorColor: SamrahColors.selectedBg,
              dividerColor: SamrahColors.line,
              tabs: [
                const Tab(text: 'الدردشة', height: 44),
                Tab(height: 44, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Flexible(child: Text('الأعضاء', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (_clubs.canManage && c.requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: SamrahColors.suitRed, borderRadius: BorderRadius.circular(9)),
                      child: Text('${c.requests.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ])),
                const Tab(text: 'الترتيب', height: 44),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(controller: _tab, children: [_chat(), _members(), _ranking()]),
    );
  }

  Widget _chat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: c.chat.length,
          itemBuilder: (_, i) {
            final m = c.chat[i];
            if (m.from == 'النادي') {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              );
            }
            final mine = m.from == _clubs.me;
            final t = '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}';
            return Align(
              alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: mine ? SamrahColors.selectedBg : SamrahColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!mine) Text(m.from, style: const TextStyle(color: SamrahColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(m.text, style: TextStyle(color: mine ? SamrahColors.onSelected : SamrahColors.text, fontSize: 14)),
                  Text(t, style: TextStyle(color: mine ? SamrahColors.onFeltMuted : SamrahColors.textMuted, fontSize: 10)),
                ]),
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msg,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(hintText: 'اكتب رسالة للنادي', isDense: true),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: SamrahColors.accent, foregroundColor: SamrahColors.onAccent, minimumSize: const Size(48, 48)),
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, textDirection: TextDirection.rtl),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _send() {
    _clubs.send(_msg.text);
    _msg.clear();
  }

  Widget _members() {
    final members = [...c.members]..sort((a, b) {
        final byRole = a.role.index - b.role.index;
        return byRole != 0 ? byRole : b.weekPoints.compareTo(a.weekPoints);
      });
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_clubs.canManage && c.requests.isNotEmpty) ...[
        Text('طلبات الانضمام (${c.requests.length})', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final r in c.requests)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: SamrahColors.fieldBorder)),
            child: Row(children: [
              Expanded(child: Text(r, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600))),
              IconButton(tooltip: 'ارفض', onPressed: () => _clubs.reject(r), icon: const Icon(Icons.close_rounded, color: SamrahColors.suitRed)),
              IconButton(tooltip: 'اقبل', onPressed: c.full ? null : () => _clubs.accept(r), icon: const Icon(Icons.check_rounded, color: SamrahColors.statusOpen)),
            ]),
          ),
        const SizedBox(height: 12),
      ],
      for (final m in members)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SamrahColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: m.name == _clubs.me ? SamrahColors.accent : SamrahColors.line),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: SamrahColors.surface3,
              child: Text(m.name.characters.first, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name == _clubs.me ? '${m.name} (أنت)' : m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
                Text('${clubRoleName(m.role)} · مستوى ${m.level}', style: TextStyle(color: m.role == ClubRole.member ? SamrahColors.textMuted : SamrahColors.accent, fontSize: 11)),
              ]),
            ),
            Text('${m.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
            if (_clubs.canAct(m))
              PopupMenuButton<String>(
                color: SamrahColors.surface2,
                icon: const Icon(Icons.more_vert, color: SamrahColors.textMuted),
                onSelected: (a) => a == 'mod' ? _clubs.toggleModerator(m) : _clubs.remove(m),
                itemBuilder: (_) => [
                  if (_clubs.myMember?.role == ClubRole.president) PopupMenuItem(value: 'mod', child: Text(m.role == ClubRole.moderator ? 'أعده عضواً' : 'اجعله مشرفاً')),
                  const PopupMenuItem(value: 'out', child: Text('أخرجه من النادي')),
                ],
              ),
          ]),
        ),
    ]);
  }

  Widget _ranking() {
    final list = _clubs.ranking;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('ترتيب الأندية هذا الأسبوع، بمجموع نقاط أعضائها. يتجدد كل سبت.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      const SizedBox(height: 10),
      for (final (i, k) in list.indexed)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SamrahColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: k == c ? SamrahColors.accent : SamrahColors.line),
          ),
          child: Row(children: [
            SizedBox(
              width: 30,
              child: i < 3
                  ? Icon(Icons.emoji_events_rounded, color: [const Color(0xFFE8C77A), const Color(0xFFC9CED6), const Color(0xFFC08457)][i], size: 22)
                  : Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            ClubEmblem(icon: k.emblem, color: k.color, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SamrahColors.text, fontWeight: k == c ? FontWeight.w700 : FontWeight.w500))),
            Text('${k.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}
