// الأندية (`s-clubs`) — design/layout-v3.md §9. Clubs are open to every player for now (the server lowers or
// raises the level they need, see apps/server/src/clubs.ts); below it the locked page shows the level bar.
// Browse and join clubs (open: at once; closed: a request; private: by invitation), or found one for 5000
// «وحدات» — it opens once the Samrah team approves it. A club's page has its chat, members (with requests,
// invitations and moderation) and the weekly ranking of clubs. Everything is the server's (lib/services/clubs.dart).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/clubs.dart';
import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import 'legal_screen.dart';
import 'profile_screen.dart';
import 'store_screen.dart' show UnitIcon;

void _say(BuildContext context, String text) => say(context, text);

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
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _clubs = Clubs.instance;

  @override
  void initState() {
    super.initState();
    _clubs.loadMine();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _clubs,
      builder: (context, _) {
        if (!_clubs.loaded) {
          return Scaffold(
            appBar: AppBar(title: Text('الأندية', style: GoogleFonts.cairo(fontSize: 20))),
            body: Center(
              child: _clubs.error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _clubs.loadMine, child: Text('${_clubs.error} — أعد المحاولة')),
            ),
          );
        }
        final mine = _clubs.mine;
        if (mine != null) return mine.pending ? _PendingClub(club: mine) : _ClubHome(club: mine);
        if (!_clubs.unlocked) return const _Locked();
        return const _Browse();
      },
    );
  }
}

// ── locked ────────────────────────────────────────────────────────────────────

class _Locked extends StatelessWidget {
  const _Locked();

  @override
  Widget build(BuildContext context) {
    final clubs = Clubs.instance;
    final me = Account.instance.me;
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            Text('تُفتح عند وصولك إلى المستوى ${clubs.unlockLevel}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 15)),
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
                    child: Text('${clubs.level}', style: const TextStyle(color: SamrahColors.onSelected, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: me?.levelProgress ?? 0, minHeight: 8, backgroundColor: SamrahColors.scorebox, color: SamrahColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${clubs.unlockLevel}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
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
          ]),
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
  List<ClubCard>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await _clubs.list(_query);
      if (mounted) setState(() => _list = l);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الأندية');
    }
  }

  Future<void> _create() async {
    await showDialog<void>(context: context, builder: (_) => const _CreateClubDialog());
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final requested = _clubs.requestedId;
    return Scaffold(
      appBar: AppBar(
        title: Text('الأندية', style: GoogleFonts.cairo(fontSize: 20)),
        actions: [IconButton(tooltip: 'قوانين النوادي', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'clubs'))), icon: const Icon(Icons.gavel_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _clubs.loadMine();
          await _load();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'ابحث عن نادٍ', prefixIcon: Icon(Icons.search, color: SamrahColors.textMuted)),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _query = v.trim();
                _load();
              },
            ),
            for (final inv in _clubs.invites) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.accent)),
                child: Row(children: [
                  ClubEmblem(icon: inv.emblem, color: inv.color, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text('دعوة إلى نادي «${inv.name}»', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600))),
                  TextButton(
                    onPressed: () async {
                      final err = await _clubs.decline(inv.id);
                      if (err != null && context.mounted) _say(context, err);
                    },
                    child: const Text('تجاهل', style: TextStyle(color: SamrahColors.textMuted)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(70, 40)),
                    onPressed: () async {
                      final (_, err) = await _clubs.join(inv.id);
                      if (context.mounted) _say(context, err ?? 'انضممت إلى «${inv.name}»');
                    },
                    child: const Text('انضم'),
                  ),
                ]),
              ),
            ],
            if (requested != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.fieldBorder)),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SamrahColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'طلبك للانضمام إلى «${list?.where((c) => c.id == requested).firstOrNull?.name ?? 'النادي'}» بانتظار موافقة المشرفين',
                      style: const TextStyle(color: SamrahColors.text, fontSize: 13),
                    ),
                  ),
                  TextButton(onPressed: () => _clubs.cancelRequest(requested), child: const Text('إلغاء')),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            if (list == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة'))),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  _query.isEmpty ? 'لا توجد أندية بعد — كن أول من يؤسس نادياً!' : 'لا توجد أندية بهذا الاسم',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SamrahColors.textMuted),
                ),
              )
            else
              for (final (i, c) in list.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EnterFrom(key: ValueKey(c.id), delay: Motion.stagger(i), offset: const Offset(0, 24), child: _ClubRow(club: c, rank: i + 1, onTap: () => _details(c))),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SamrahColors.accent,
        foregroundColor: SamrahColors.onAccent,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('نادٍ جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _details(ClubCard c) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _ClubDetailsSheet(club: c));
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club, required this.rank, required this.onTap});
  final ClubCard club;
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
                if (c.motto.isNotEmpty) Text(c.motto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, children: [
                  _meta(Icons.group_outlined, '${c.memberCount}/${c.maxMembers}'),
                  _meta(c.type == 'open' ? Icons.lock_open_rounded : Icons.how_to_reg_outlined, clubTypeName(c.type)),
                  if (c.minLevel > 1) _meta(Icons.military_tech_outlined, 'مستوى ${c.minLevel}+'),
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

class _ClubDetailsSheet extends StatefulWidget {
  const _ClubDetailsSheet({required this.club});
  final ClubCard club;

  @override
  State<_ClubDetailsSheet> createState() => _ClubDetailsSheetState();
}

class _ClubDetailsSheetState extends State<_ClubDetailsSheet> {
  ClubDetail? _d;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Clubs.instance.detail(widget.club.id).then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final clubs = Clubs.instance;
    final c = _d ?? widget.club;
    final d = _d;
    final top = d == null ? <ClubPerson>[] : ([...d.members]..sort((a, b) => b.weekPoints.compareTo(a.weekPoints)));
    final requested = clubs.requestedId == c.id || (d?.requested ?? false);
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
          if (c.motto.isNotEmpty) Text(c.motto, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            _stat('الأعضاء', '${c.memberCount}/${c.maxMembers}'),
            _stat('النوع', clubTypeName(c.type)),
            _stat('نقاط الأسبوع', '${c.weekPoints}'),
            _stat('أقل مستوى', '${c.minLevel}'),
          ]),
          const SizedBox(height: 12),
          Text('الرئيس: ${c.president}', style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('الأكثر نقاطاً: ${top.take(3).map((m) => m.name).join('، ')}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: c.full || requested || _busy || clubs.requestedId != null
                ? null
                : () async {
                    setState(() => _busy = true);
                    final (result, err) = await clubs.join(c.id);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _say(context, err ?? (result == 'joined' ? 'انضممت إلى «${c.name}»' : 'أُرسل طلبك إلى مشرفي النادي'));
                  },
            child: Text(c.full ? 'النادي ممتلئ' : (requested ? 'طلبك قيد المراجعة' : (c.type == 'open' ? 'انضم' : 'اطلب الانضمام'))),
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

// ── founding: «نادي جديد» ───────────────────────────────────────────────────────

class _CreateClubDialog extends StatefulWidget {
  const _CreateClubDialog();

  @override
  State<_CreateClubDialog> createState() => _CreateClubDialogState();
}

class _CreateClubDialogState extends State<_CreateClubDialog> {
  final _name = TextEditingController();
  final _motto = TextEditingController();
  int _emblem = 0;
  int _color = 0;
  String _type = 'closed';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _motto.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) return setState(() => _error = 'اسم النادي قصير جداً');
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Clubs.instance.create(name: _name.text, motto: _motto.text, emblem: _emblem, color: _color, type: _type);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context);
    _say(context, 'أُرسل ناديك للمراجعة، وسيُفعَّل بعد موافقة فريق سمرة');
  }

  @override
  Widget build(BuildContext context) {
    final cost = Clubs.createCost;
    final balance = Store.instance.units;
    return Dialog(
      backgroundColor: SamrahColors.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // title bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: const BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              Expanded(child: Text('نادي جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'إغلاق', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: SamrahColors.textMuted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClubEmblem(icon: Clubs.emblems[_emblem], color: Clubs.colors[_color], size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 24,
                    decoration: InputDecoration(labelText: 'إسم النادي', errorText: _error),
                  ),
                ),
              ]),
              TextField(controller: _motto, maxLength: 60, decoration: const InputDecoration(labelText: 'شعار النادي (اختياري)')),
              const SizedBox(height: 8),
              const Text('نوع النادي:', style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
              RadioGroup<String>(
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
                child: Column(children: [
                  for (final (value, title, hint) in const [
                    ('open', 'نادي مفتوح', 'يدخله أي لاعب مباشرة'),
                    ('closed', 'نادي مغلق', 'يظهر للجميع، والانضمام بطلب يقبله المشرفون'),
                    ('private', 'نادي خاص', 'لا يظهر في القائمة، والانضمام بدعوة فقط'),
                  ])
                    RadioListTile<String>(
                      value: value,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(title, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
                      subtitle: Text(hint, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              const Text('الرمز واللون', style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < Clubs.emblems.length; i++) _pick(selected: i == _emblem, onTap: () => setState(() => _emblem = i), child: Icon(Clubs.emblems[i], color: SamrahColors.icon, size: 20)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < Clubs.colors.length; i++)
                  _pick(selected: i == _color, onTap: () => setState(() => _color = i), child: Container(width: 22, height: 22, decoration: BoxDecoration(color: Clubs.colors[i], shape: BoxShape.circle))),
              ]),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'تكلفة إنشاء أي نادٍ في سمرة هي '),
                  TextSpan(text: '$cost وحدة', style: const TextStyle(fontWeight: FontWeight.w800, color: SamrahColors.accent)),
                  const TextSpan(text: '، وسيتم تفعيل النادي بعد أن تتم الموافقة عليه. وإن لم تتم الموافقة تُعاد إليك الوحدات كاملة.'),
                ]),
                style: const TextStyle(color: SamrahColors.text, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Text('رصيدك: ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
                const UnitIcon(size: 16),
                const SizedBox(width: 4),
                Text('$balance', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const Divider(color: SamrahColors.line, height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: Wrap(children: [
                  const Text('عند إنشاء هذا النادي، أنت توافق على ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'clubs'))),
                    child: const Text('قوانين نوادي سمرة', style: TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)), onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(72, 44), backgroundColor: const Color(0xFF4E9A2E), foregroundColor: Colors.white),
                onPressed: _busy || balance < cost ? null : _submit,
                child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(balance < cost ? 'الرصيد لا يكفي' : 'أنشئ'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pick({required bool selected, required VoidCallback onTap, required Widget child}) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SamrahColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? SamrahColors.selectedBg : SamrahColors.line, width: selected ? 2 : 1),
          ),
          child: child,
        ),
      );
}

// ── a club waiting for approval ──────────────────────────────────────────────

class _PendingClub extends StatelessWidget {
  const _PendingClub({required this.club});
  final ClubDetail club;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(club.name, style: GoogleFonts.cairo(fontSize: 19))),
      body: RefreshIndicator(
        onRefresh: Clubs.instance.loadMine,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Center(child: ClubEmblem(icon: club.emblem, color: club.color, size: 96)),
          const SizedBox(height: 16),
          Text('ناديك بانتظار الموافقة', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'يراجع فريق سمرة النادي الجديد قبل تفعيله. ستصلك رسالة في التنبيهات حين يُفعَّل، وإن لم تتم الموافقة تُعاد إليك الوحدات كاملة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SamrahColors.textMuted, height: 1.7),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: SamrahColors.surface,
                  title: const Text('سحب طلب النادي؟'),
                  content: Text('يُلغى النادي وتعود إليك ${Clubs.createCost} وحدة.', style: const TextStyle(color: SamrahColors.textMuted)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اسحب')),
                  ],
                ),
              );
              if (ok != true) return;
              final err = await Clubs.instance.leave();
              if (context.mounted) _say(context, err ?? 'سُحب الطلب وأُعيدت الوحدات');
            },
            child: const Text('اسحب الطلب'),
          ),
        ]),
      ),
    );
  }
}

// ── the player's club ─────────────────────────────────────────────────────────

class _ClubHome extends StatefulWidget {
  const _ClubHome({required this.club});
  final ClubDetail club;

  @override
  State<_ClubHome> createState() => _ClubHomeState();
}

class _ClubHomeState extends State<_ClubHome> with SingleTickerProviderStateMixin {
  final _clubs = Clubs.instance;
  late final _tab = TabController(length: 3, vsync: this);
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  List<ClubCard> _ranking = [];

  @override
  void initState() {
    super.initState();
    _clubs.openChat();
    _clubs.addListener(_scrollDown);
    _clubs.ranking().then((r) {
      if (mounted) setState(() => _ranking = r);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _clubs.removeListener(_scrollDown);
    _clubs.closeChat();
    _tab.dispose();
    _msg.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  ClubDetail get c => widget.club;
  bool get _president => c.myRole == ClubRole.president;

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('مغادرة «${c.name}»؟', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          _president ? 'أنت الرئيس: ستنتقل الرئاسة إلى أحد المشرفين أو أقدم عضو. وإن كنت العضو الوحيد يُغلق النادي.' : 'تخرج من النادي ودردشته، ويمكنك الانضمام إلى نادٍ آخر.',
          style: const TextStyle(color: SamrahColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع', style: TextStyle(color: SamrahColors.textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('غادر')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _clubs.leave();
    if (err != null && mounted) _say(context, err);
  }

  Future<void> _invite() async {
    final ctrl = TextEditingController();
    final ref = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('دعوة لاعب'),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم اللاعب')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('ادعُ')),
        ],
      ),
    );
    ctrl.dispose();
    if (ref == null || ref.isEmpty) return;
    final err = await _clubs.invite(ref);
    if (mounted) _say(context, err ?? 'أُرسلت الدعوة');
  }

  Future<void> _settings() async {
    final motto = TextEditingController(text: c.motto);
    var type = c.type;
    var minLevel = c.minLevel;
    var emblem = c.emblemIndex;
    var color = c.colorIndex;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: SamrahColors.surface,
          title: Text('إعدادات النادي', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: motto, maxLength: 60, decoration: const InputDecoration(labelText: 'الشعار')),
              RadioGroup<String>(
                groupValue: type,
                onChanged: (v) => set(() => type = v!),
                child: Column(children: [
                  for (final t in const ['open', 'closed', 'private'])
                    RadioListTile<String>(value: t, dense: true, contentPadding: EdgeInsets.zero, title: Text('نادي ${clubTypeName(t)}')),
                ]),
              ),
              Row(children: [
                const Expanded(child: Text('أقل مستوى للانضمام')),
                IconButton(onPressed: minLevel > 1 ? () => set(() => minLevel--) : null, icon: const Icon(Icons.remove)),
                Text('$minLevel', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(onPressed: minLevel < 100 ? () => set(() => minLevel++) : null, icon: const Icon(Icons.add)),
              ]),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (var i = 0; i < Clubs.emblems.length; i++)
                  IconButton(
                    onPressed: () => set(() => emblem = i),
                    icon: Icon(Clubs.emblems[i], color: i == emblem ? SamrahColors.accent : SamrahColors.icon),
                  ),
              ]),
              Wrap(spacing: 6, children: [
                for (var i = 0; i < Clubs.colors.length; i++)
                  GestureDetector(
                    onTap: () => set(() => color = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: Clubs.colors[i], shape: BoxShape.circle, border: Border.all(color: i == color ? SamrahColors.text : Colors.transparent, width: 2)),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted))),
            ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('احفظ')),
          ],
        ),
      ),
    );
    if (save == true) {
      final err = await _clubs.update({'motto': motto.text, 'type': type, 'minLevel': minLevel, 'emblem': emblem, 'color': color});
      if (mounted) _say(context, err ?? 'حُفظت الإعدادات');
    }
    motto.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = _ranking.indexWhere((k) => k.id == c.id) + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name, style: GoogleFonts.cairo(fontSize: 19)),
        actions: [
          if (c.canManage) IconButton(tooltip: 'دعوة لاعب', onPressed: _invite, icon: const Icon(Icons.person_add_alt_1_outlined, color: SamrahColors.icon)),
          if (_president) IconButton(tooltip: 'إعدادات النادي', onPressed: _settings, icon: const Icon(Icons.tune_rounded, color: SamrahColors.icon)),
          PopupMenuButton<String>(
            color: SamrahColors.surface2,
            onSelected: (a) {
              if (a == 'rules') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'clubs')));
              if (a == 'leave') _leave();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rules', child: Text('قوانين النوادي')),
              PopupMenuItem(value: 'leave', child: Text('غادر النادي')),
            ],
          ),
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
                    Text('${c.memberCount}/${c.maxMembers} عضواً · ${clubTypeName(c.type)}${c.minLevel > 1 ? ' · مستوى ${c.minLevel}+' : ''}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  ]),
                ),
                Column(children: [
                  Text(rank > 0 ? '#$rank' : '—', style: GoogleFonts.cairo(color: SamrahColors.accent, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
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
                Tab(
                  height: 44,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Flexible(child: Text('الأعضاء', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (c.canManage && c.requests.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: SamrahColors.suitRed, borderRadius: BorderRadius.circular(9)),
                        child: Text('${c.requests.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ),
                const Tab(text: 'الترتيب', height: 44),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(controller: _tab, children: [_chat(), _members(), _rankingTab()]),
    );
  }

  Widget _chat() {
    final me = Account.instance.me?.id;
    return Column(children: [
      Expanded(
        child: ListenableBuilder(
          listenable: _clubs,
          builder: (_, _) => ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _clubs.chat.length,
            itemBuilder: (_, i) {
              final m = _clubs.chat[i];
              if (m.notice) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                );
              }
              final mine = m.from == me;
              final t = '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}';
              return Align(
                alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                child: GestureDetector(
                  onTap: mine ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userRef: m.from!))),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    decoration: BoxDecoration(color: mine ? SamrahColors.selectedBg : SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!mine) Text(m.name, style: const TextStyle(color: SamrahColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(m.text, style: TextStyle(color: mine ? SamrahColors.onSelected : SamrahColors.text, fontSize: 14)),
                      Text(t, style: TextStyle(color: mine ? SamrahColors.onFeltMuted : SamrahColors.textMuted, fontSize: 10)),
                    ]),
                  ),
                ),
              );
            },
          ),
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
                maxLength: 300,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(hintText: 'اكتب رسالة للنادي', isDense: true, counterText: ''),
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

  Future<void> _send() async {
    final t = _msg.text;
    _msg.clear();
    final err = await _clubs.send(t);
    if (err != null && mounted) _say(context, err);
  }

  Future<void> _do(Future<String?> f, String done) async {
    final err = await f;
    if (mounted) _say(context, err ?? done);
  }

  bool _canAct(ClubPerson m) {
    final mine = c.myRole;
    if (m.id == Account.instance.me?.id || m.role == ClubRole.president) return false;
    if (mine == ClubRole.president) return true;
    return mine == ClubRole.moderator && m.role == ClubRole.member;
  }

  Widget _members() {
    final me = Account.instance.me?.id;
    final members = [...c.members]..sort((a, b) {
        final byRole = a.role.index - b.role.index;
        return byRole != 0 ? byRole : b.weekPoints.compareTo(a.weekPoints);
      });
    return RefreshIndicator(
      onRefresh: _clubs.loadMine,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (c.canManage && c.requests.isNotEmpty) ...[
          Text('طلبات الانضمام (${c.requests.length})', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final r in c.requests)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: SamrahColors.fieldBorder)),
              child: Row(children: [
                Expanded(child: Text('${r.name} · مستوى ${r.level}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600))),
                IconButton(tooltip: 'ارفض', onPressed: () => _do(_clubs.answer(r.id, false), 'رُفض الطلب'), icon: const Icon(Icons.close_rounded, color: SamrahColors.suitRed)),
                IconButton(tooltip: 'اقبل', onPressed: c.full ? null : () => _do(_clubs.answer(r.id, true), 'انضم ${r.name}'), icon: const Icon(Icons.check_rounded, color: SamrahColors.statusOpen)),
              ]),
            ),
          const SizedBox(height: 12),
        ],
        if (c.canManage && c.invites.isNotEmpty) ...[
          Text('دعوات مرسلة (${c.invites.length})', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
          for (final r in c.invites)
            ListTile(
              dense: true,
              title: Text(r.name, style: const TextStyle(color: SamrahColors.text)),
              trailing: TextButton(onPressed: () => _do(_clubs.cancelInvite(r.id), 'أُلغيت الدعوة'), child: const Text('ألغِ')),
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
              border: Border.all(color: m.id == me ? SamrahColors.accent : SamrahColors.line),
            ),
            child: InkWell(
              onTap: m.id == me ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userRef: m.id))),
              child: Row(children: [
                LetterAvatar(name: m.name, radius: 18, online: m.online),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.id == me ? '${m.name} (أنت)' : m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
                    Text('${clubRoleName(m.role)} · مستوى ${m.level}', style: TextStyle(color: m.role == ClubRole.member ? SamrahColors.textMuted : SamrahColors.accent, fontSize: 11)),
                  ]),
                ),
                Text('${m.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
                if (_canAct(m))
                  PopupMenuButton<String>(
                    color: SamrahColors.surface2,
                    icon: const Icon(Icons.more_vert, color: SamrahColors.textMuted),
                    onSelected: (a) => switch (a) {
                      'mod' => _do(_clubs.setRole(m.id, m.role == ClubRole.moderator ? 'member' : 'moderator'), 'تم'),
                      'pres' => _do(_clubs.setRole(m.id, 'president'), 'سلّمت الرئاسة إلى ${m.name}'),
                      _ => _do(_clubs.remove(m.id), 'أُخرج ${m.name}'),
                    },
                    itemBuilder: (_) => [
                      if (_president) PopupMenuItem(value: 'mod', child: Text(m.role == ClubRole.moderator ? 'أعده عضواً' : 'اجعله مشرفاً')),
                      if (_president) const PopupMenuItem(value: 'pres', child: Text('سلّمه الرئاسة')),
                      const PopupMenuItem(value: 'out', child: Text('أخرجه من النادي')),
                    ],
                  ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _rankingTab() {
    final list = _ranking;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('ترتيب الأندية هذا الأسبوع، بمجموع نقاط أعضائها. يتجدد كل سبت.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      const SizedBox(height: 10),
      for (final (i, k) in list.indexed)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: k.id == c.id ? SamrahColors.accent : SamrahColors.line)),
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
            Expanded(child: Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SamrahColors.text, fontWeight: k.id == c.id ? FontWeight.w700 : FontWeight.w500))),
            Text('${k.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}
