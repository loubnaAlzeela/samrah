// الترتيب — the players by experience earned this week (from Saturday) or ever, the best in each game by wins,
// and the clubs by their members' points this week. The player's own place is pinned at the bottom.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/api.dart';
import '../services/clubs.dart';
import '../services/error_text.dart';
import '../theme/samrah_theme.dart';
import 'clubs_screen.dart' show ClubEmblem;
import 'profile_screen.dart';
import 'room_screen.dart' show variantNameAr;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.variant});

  /// When set, the «حسب اللعبة» tab starts on this game.
  final String? variant;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 4, vsync: this);
  late String _variant = widget.variant ?? 'tarneeb';

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الترتيب', style: GoogleFonts.cairo(fontSize: 20)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: SamrahColors.text,
          unselectedLabelColor: SamrahColors.textMuted,
          indicatorColor: SamrahColors.selectedBg,
          dividerColor: SamrahColors.line,
          labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'هذا الأسبوع'), Tab(text: 'الكل'), Tab(text: 'حسب اللعبة'), Tab(text: 'الأندية')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        const _Players(scope: 'week', unit: 'نقطة خبرة'),
        const _Players(scope: 'all', unit: 'نقطة خبرة'),
        Column(children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final v in const ['tarneeb', 'syrian41', 'tarneeb400', 'trix', 'trixPartners', 'trixComplex', 'trixComplexPartners', 'b187', 'baloot', 'hand'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(variantNameAr(v)),
                      selected: v == _variant,
                      selectedColor: SamrahColors.selectedBg,
                      labelStyle: TextStyle(color: v == _variant ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _variant = v),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _Players(key: ValueKey(_variant), scope: 'all', variant: _variant, unit: 'فوز')),
        ]),
        const _ClubsRanking(),
      ]),
    );
  }
}

class _Players extends StatefulWidget {
  const _Players({super.key, required this.scope, required this.unit, this.variant});
  final String scope;
  final String? variant;
  final String unit;

  @override
  State<_Players> createState() => _PlayersState();
}

class _PlayersState extends State<_Players> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.instance.get('/leaderboard', {'scope': widget.scope, 'variant': ?widget.variant});
      if (mounted) setState(() => _data = Map<String, dynamic>.from(d as Map));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = _data;
    if (d == null) return Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')));
    final top = [for (final r in d['top'] as List) Map<String, dynamic>.from(r as Map)];
    final me = Map<String, dynamic>.from(d['me'] as Map);
    final myId = Account.instance.me?.id;
    return Column(children: [
      Expanded(
        child: top.isEmpty
            ? const Center(child: Text('لا أحد في الترتيب بعد — العب لتكون الأول!', style: TextStyle(color: SamrahColors.textMuted)))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: top.length,
                  itemBuilder: (_, i) => _row(top[i], highlight: top[i]['id'] == myId),
                ),
              ),
      ),
      Container(
        decoration: const BoxDecoration(color: SamrahColors.surface, border: Border(top: BorderSide(color: SamrahColors.line))),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(top: false, child: _row(me, highlight: true, mine: true)),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> r, {bool highlight = false, bool mine = false}) {
    final rank = r['rank'] as int?;
    return Container(
      margin: EdgeInsets.only(bottom: mine ? 0 : 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? SamrahColors.accent : SamrahColors.line),
      ),
      child: InkWell(
        onTap: mine ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userRef: r['id'] as String))),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: rank != null && rank <= 3
                ? Icon(Icons.emoji_events_rounded, color: [const Color(0xFFE8C77A), const Color(0xFFC9CED6), const Color(0xFFC08457)][rank - 1], size: 24)
                : Text(rank == null ? '—' : '$rank', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          LetterAvatar(name: r['name'] as String, radius: 17, online: r['online'] == true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mine ? '${r['name']} (أنت)' : r['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600)),
              Text('مستوى ${r['level']}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
            ]),
          ),
          Text('${r['score']}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(widget.unit, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _ClubsRanking extends StatefulWidget {
  const _ClubsRanking();

  @override
  State<_ClubsRanking> createState() => _ClubsRankingState();
}

class _ClubsRankingState extends State<_ClubsRanking> with AutomaticKeepAliveClientMixin {
  List<ClubCard>? _list;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Clubs.instance.ranking();
      if (mounted) setState(() => _list = l);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = _list;
    if (list == null) return Center(child: _error == null ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: Text('$_error — أعد المحاولة')));
    if (list.isEmpty) return const Center(child: Text('لا توجد أندية بعد', style: TextStyle(color: SamrahColors.textMuted)));
    final mine = Account.instance.me?.clubId;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('بمجموع نقاط الأعضاء هذا الأسبوع، ويبدأ من جديد كل سبت.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        for (final (i, k) in list.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: k.id == mine ? SamrahColors.accent : SamrahColors.line)),
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
              Expanded(child: Text(k.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w600))),
              Text('${k.weekPoints}', style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}
