// المتجر (`s-store`) — design/layout-v3.md §9, grown into a front tab and one
// tab per kind of item: العروض (the gold membership, the welcome offer, the
// daily gift and a tile per section), currency packs (segmented وحدات / نجوم),
// card backs, tables, seat rings, name colours, badges, card-play effects
// («ضربات»), emotes, experience boosters, and the membership itself. Items are
// bought with «وحدات» (boosters and the membership with «نجوم») and worn at once
// in every game. Balances and ownership are the server's
// (lib/services/store.dart); currency packs and the welcome offer are paid
// through Google Play / the App Store (lib/services/purchases.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/account.dart';
import '../services/purchases.dart';
import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/emote_face.dart';
import '../widgets/motion.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/table_stage.dart';
import '../widgets/trick_card.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.initialTab = offersTab, this.stars = false});

  /// One of the tab numbers below.
  final int initialTab;

  /// The currency tab opens on «نجوم».
  final bool stars;

  static const offersTab = 0;
  static const coinsTab = 1;
  static const backsTab = 2;
  static const tablesTab = 3;
  static const seatsTab = 4;
  static const namesTab = 5;
  static const badgesTab = 6;
  static const hitsTab = 7;
  static const emotesTab = 8;
  static const boostersTab = 9;
  static const membershipTab = 10;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final _store = Store.instance;
  final _pay = Purchases.instance;
  late final _tab = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialTab);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pay.addListener(_onPay);
    _pay.start();
  }

  void _onPay() {
    final m = _pay.message;
    if (m != null && mounted) {
      _pay.message = null;
      _say(m);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pay.removeListener(_onPay);
    _tab.dispose();
    super.dispose();
  }

  /// Runs one server action with the buttons held; shows the error if it was refused.
  Future<bool> _run(Future<String?> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return false;
    setState(() => _busy = false);
    if (err != null) _say(err);
    return err == null;
  }
  late bool _stars = widget.stars; // العملات: which currency's packs are showing

  /// The tabs in [StoreScreen]'s order, with the icon of each section's tile.
  static const _tabs = [
    ('العروض', Icons.local_offer_rounded),
    ('العملات', Icons.toll_rounded),
    ('ظهر الورق', Icons.style_rounded),
    ('الطاولات', Icons.table_restaurant_rounded),
    ('ألوان المقعد', Icons.account_circle_rounded),
    ('لون الاسم', Icons.format_color_text_rounded),
    ('الشارات', Icons.military_tech_rounded),
    ('الضربات', Icons.auto_awesome_rounded),
    ('الإيموجي', Icons.emoji_emotions_rounded),
    ('المسرّعات', Icons.rocket_launch_rounded),
    ('العضوية', Icons.workspace_premium_rounded),
  ];

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  String get _myName => Account.instance.me?.name ?? 'لاعب';
  String get _myLetter => _myName.trim().isEmpty ? '؟' : _myName.trim().substring(0, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('المتجر', style: GoogleFonts.cairo(fontSize: 20)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(104),
            child: Column(
              children: [
                ListenableBuilder(listenable: _store, builder: (_, _) => _balances()),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: SamrahColors.text,
                  unselectedLabelColor: SamrahColors.textMuted,
                  labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
                  indicatorColor: SamrahColors.selectedBg,
                  dividerColor: SamrahColors.line,
                  tabs: [for (final t in _tabs) Tab(text: t.$1, height: 44)],
                ),
              ],
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: _store,
          builder: (_, _) => TabBarView(
            controller: _tab,
            children: [_offers(), _coins(), _backs(), _tables(), _seats(), _names(), _badges(), _hits(), _emotes(), _boosters(), _membership()],
          ),
        ),
    );
  }

  // ── the wallets ────────────────────────────────────────────────────────────

  Widget _balances() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _balance(const UnitIcon(size: 18), _store.units),
        const SizedBox(width: 10),
        _balance(const StarIcon(size: 18), _store.stars),
        if (_store.vip) ...[
          const SizedBox(width: 10),
          _vipBadge(),
        ],
      ],
    );
  }

  Widget _balance(Widget icon, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: SamrahColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          CountUp(value: value, style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _vipBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(19), border: Border.all(color: _gold)),
        child: const Text('عضو ذهبي', style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  static const _gold = Color(0xFFE8C77A);

  // ── العروض ──────────────────────────────────────────────────────────────────

  Widget _offers() {
    final offer = _store.offer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _membershipBanner(),
        if (offer != null) ...[
          const SizedBox(height: 14),
          _welcomeOffer(offer),
        ],
        const SizedBox(height: 14),
        _dailyGift(),
        const SizedBox(height: 22),
        Text('الأقسام', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 100),
          itemCount: _tabs.length - 1,
          itemBuilder: (_, i) => EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: _sectionTile(i + 1)),
        ),
      ],
    );
  }

  Widget _sectionTile(int tab) {
    final (label, icon) = _tabs[tab];
    final gold = tab == StoreScreen.membershipTab;
    return Material(
      color: SamrahColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold ? _gold : SamrahColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _tab.animateTo(tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
              child: Icon(icon, color: gold ? _gold : SamrahColors.accent, size: 26),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membershipBanner() {
    final vip = _store.vip;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF2E2614), Color(0xFF151515)], begin: Alignment.centerRight, end: Alignment.centerLeft),
        border: Border.all(color: _gold, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 46, color: _gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('العضوية الذهبية', style: GoogleFonts.cairo(color: _gold, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                Text(
                  vip && _store.vipUntil != null ? 'أنت عضو حتى ${_store.vipUntil!.year}/${_store.vipUntil!.month}/${_store.vipUntil!.day}' : 'عناصر ذهبية حصرية وهدية يومية مضاعفة',
                  style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14), foregroundColor: _gold, side: const BorderSide(color: _gold)),
                  onPressed: () => _tab.animateTo(StoreScreen.membershipTab),
                  child: Text(vip ? 'جدّد العضوية' : 'اكتشف المزيد', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The welcome offer: what it brings, the time left, and its price beside the full one.
  Widget _welcomeOffer(Offer o) {
    final emote = Store.emotes.firstWhere((e) => e.id == o.item, orElse: () => Store.emotes.first);
    final pack = Store.offerPack;
    final off = ((1 - Store.offerShare) * 100).round();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF4A2A10), SamrahColors.surface], begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: SamrahColors.accent, width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: SamrahColors.accent,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(17), bottomRight: Radius.circular(12)),
              ),
              child: Text('خصم $off%', style: const TextStyle(color: SamrahColors.onAccent, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(child: Text(pack.name!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 17, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    _Countdown(until: o.until),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _offerPart(const UnitIcon(size: 38), '${o.units}', 'وحدة')),
                    Expanded(child: _offerPart(const Icon(Icons.rocket_launch_rounded, size: 38, color: SamrahColors.accent), 'خبرة ×2', '${o.boostHours} ساعة')),
                    Expanded(child: _offerPart(EmoteFace(id: emote.id, size: 36), emote.label, 'إيموجي')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                        onPressed: _pay.busy != null ? null : () => _pay.buy(pack),
                        child: _pay.busy == pack.id
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SamrahColors.onAccent))
                            : Directionality(textDirection: TextDirection.ltr, child: Text(_pay.priceOf(pack), style: const TextStyle(fontWeight: FontWeight.w800))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _pay.fullPriceOf(pack, Store.offerShare, Store.offerWas),
                        style: const TextStyle(color: SamrahColors.textMuted, fontSize: 14, decoration: TextDecoration.lineThrough, decorationColor: SamrahColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerPart(Widget icon, String title, String sub) {
    return Column(
      children: [
        SizedBox(height: 42, child: Center(child: icon)),
        const SizedBox(height: 4),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
        Text(sub, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
      ],
    );
  }

  // ── العملات ─────────────────────────────────────────────────────────────────

  Widget _coins() {
    final packs = _stars ? Store.starPacks : Store.unitPacks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.line)),
          child: Row(
            children: [
              Expanded(child: _segment('وحدات', !_stars, () => setState(() => _stars = false))),
              Expanded(child: _segment('نجوم', _stars, () => setState(() => _stars = true))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          key: ValueKey(_stars),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 190),
          itemCount: packs.length,
          itemBuilder: (_, i) => EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: _packCard(packs[i])),
        ),
        const SizedBox(height: 14),
        const Text(
          'الدفع عبر Google Play أو App Store، وتُضاف العملات إلى محفظتك فور تأكيد الشراء. العملات للعب داخل سمرة فقط ولا تُستبدل بمال.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SamrahColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? SamrahColors.selectedBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? SamrahColors.onSelected : SamrahColors.textMuted, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _dailyGift() {
    final claimed = _store.giftClaimed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF4A2A10), Color(0xFF2C2C2C)], begin: Alignment.centerRight, end: Alignment.centerLeft),
        border: Border.all(color: SamrahColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle, border: Border.all(color: SamrahColors.line)),
            child: const Icon(Icons.card_giftcard_rounded, color: SamrahColors.accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الهدية اليومية', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  claimed ? 'عُد غداً لهدية جديدة' : '${_store.giftAmount} وحدة مجاناً${_store.vip ? ' (مضاعفة للأعضاء)' : ''}',
                  style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(92, 44), padding: EdgeInsets.zero),
              onPressed: claimed || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final (amount, err) = await _store.claimGift();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      _say(err ?? 'أُضيفت $amount وحدة إلى رصيدك');
                    },
              child: Text(claimed ? 'استُلمت' : 'استلم'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _packCard(CoinPack p) {
    return Container(
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.tag != null ? SamrahColors.fieldBorder : SamrahColors.line)),
      child: Stack(
        children: [
          if (p.tag != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: SamrahColors.selectedBg,
                  borderRadius: BorderRadius.only(topRight: Radius.circular(15), bottomLeft: Radius.circular(10)),
                ),
                child: Text(p.tag!, style: const TextStyle(color: SamrahColors.onSelected, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
            child: Column(
              children: [
                _stars ? const StarIcon(size: 40) : const UnitIcon(size: 40),
                const SizedBox(height: 4),
                if (p.name != null) Text(p.name!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12, height: 1.3)),
                Text('${p.amount}', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 18, fontWeight: FontWeight.w700, height: 1.2)),
                SizedBox(
                  height: 16,
                  child: p.bonus > 0 ? Text('+${p.bonus} هدية', style: const TextStyle(color: SamrahColors.statusOpen, fontSize: 11, fontWeight: FontWeight.w600)) : null,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: EdgeInsets.zero),
                    onPressed: _pay.busy != null ? null : () => _pay.buy(p),
                    child: _pay.busy == p.id
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Directionality(textDirection: TextDirection.ltr, child: Text(_pay.priceOf(p), style: const TextStyle(fontWeight: FontWeight.w700))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ظهر الورق والطاولات ─────────────────────────────────────────────────────

  Widget _backs() {
    final items = Store.cardBacks;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final b = items[i];
        return _itemCard(
          id: b.id,
          name: b.name,
          price: b.price,
          vipOnly: b.vipOnly,
          inUse: _store.cardBack.id == b.id,
          preview: _backFan(b),
          onUse: () => _store.useBack(b.id),
        );
      },
    );
  }

  Widget _backFan(CardBackStyle b) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final (dx, r) in [(-16.0, -0.22), (16.0, 0.22), (0.0, 0.0)])
          Transform.translate(offset: Offset(dx, r == 0 ? -4 : 2), child: Transform.rotate(angle: r, child: CardBack(width: 44, style: b))),
      ],
    );
  }

  Widget _tables() {
    final items = Store.tables;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final t = items[i];
        return _itemCard(
          id: t.id,
          name: t.name,
          price: t.price,
          vipOnly: t.vipOnly,
          inUse: _store.table.id == t.id,
          preview: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TableFelt(style: t, radius: 18),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(angle: -0.15, child: const PlayingCardView(code: 'S14', width: 26)),
                        const SizedBox(width: 4),
                        Transform.rotate(angle: 0.12, child: const PlayingCardView(code: 'H13', width: 26)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          onUse: () => _store.useTable(t.id),
        );
      },
    );
  }

  Widget _itemGrid({required int count, required Widget Function(int) itemBuilder, String? header}) {
    return CustomScrollView(
      slivers: [
        if (header != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: Text(header, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12))),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 210),
            itemCount: count,
            itemBuilder: (_, i) => EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: itemBuilder(i)),
          ),
        ),
      ],
    );
  }

  /// An item that is owned but not worn (an emote): nothing to press.
  Widget _ownedTag() => Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: SamrahColors.line)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 18, color: SamrahColors.statusOpen),
            SizedBox(width: 4),
            Text('لديك', style: TextStyle(color: SamrahColors.statusOpen, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _itemCard({
    required String id,
    required String name,
    required int price,
    required bool vipOnly,
    required bool inUse,
    required Widget preview,
    Future<String?> Function()? onUse,
    /// false for a sticker: no caption under the picture, just the price (like a sticker pack). [name] still
    /// names it in the buy dialog and the toast.
    bool showName = true,
  }) {
    final owned = _store.owns(id);
    final Widget action;
    if (inUse) {
      action = Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SamrahColors.selectedBg, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 18, color: SamrahColors.onSelected),
            SizedBox(width: 4),
            Text('مستخدم', style: TextStyle(color: SamrahColors.onSelected, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (owned && onUse == null) {
      action = _ownedTag();
    } else if (owned) {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: () async {
          if (await _run(onUse!)) _say('صار «$name» هو المستخدم في كل الألعاب');
        },
        child: const Text('استخدم', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    } else if (vipOnly) {
      action = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: _gold, side: const BorderSide(color: _gold)),
        onPressed: () => _tab.animateTo(StoreScreen.membershipTab),
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: const Text('للأعضاء', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    } else {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: EdgeInsets.zero),
        onPressed: () => _confirmBuy(id: id, name: name, price: price, onUse: onUse),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const UnitIcon(size: 16),
            const SizedBox(width: 6),
            Text('$price', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inUse ? SamrahColors.selectedBg : SamrahColors.line, width: inUse ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Center(child: preview),
            ),
          ),
          const SizedBox(height: 8),
          if (showName)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2)),
                ),
                if (vipOnly) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.workspace_premium, size: 16, color: _gold),
                ],
              ],
            )
          else if (vipOnly)
            const Icon(Icons.workspace_premium, size: 16, color: _gold),
          if (showName || vipOnly) const SizedBox(height: 8),
          action,
        ],
      ),
    );
  }

  Future<void> _confirmBuy({required String id, required String name, required int price, Future<String?> Function()? onUse}) async {
    if (_store.units < price) {
      _say('رصيد الوحدات لا يكفي — تحتاج ${price - _store.units} وحدة أخرى');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('شراء «$name»', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('سيُخصم $price وحدة من رصيدك (${_store.units}).', style: const TextStyle(color: SamrahColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(onUse == null ? 'اشترِ' : 'اشترِ واستخدم'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await _run(() => _store.buy(id))) return;
    if (onUse == null) {
      _say('اشتريت «$name»');
    } else if (await _run(onUse)) {
      _say('اشتريت «$name» وصار مستخدماً في كل الألعاب');
    }
  }

  // ── ألوان المقعد، لون الاسم، الشارات، الضربات، الإيموجي ───────────────────────

  Widget _seats() {
    final items = Store.seats;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final s = items[i];
        return _itemCard(
          id: s.id,
          name: s.name,
          price: s.price,
          vipOnly: s.vipOnly,
          inUse: _store.look.seat == s.id,
          preview: SeatRing(style: s, size: 76, child: _letter(28)),
          onUse: () => _store.use(s.id),
        );
      },
    );
  }

  Widget _letter(double size) => Text(_myLetter, style: TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700, fontSize: size));

  Widget _names() {
    final items = Store.names;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final n = items[i];
        return _itemCard(
          id: n.id,
          name: n.name,
          price: n.price,
          vipOnly: n.vipOnly,
          inUse: _store.look.name == n.id,
          preview: Container(
            constraints: const BoxConstraints(maxWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: SamrahColors.pillBg, borderRadius: BorderRadius.circular(999), border: Border.all(color: SamrahColors.pillBorder, width: 1.2)),
            child: Text(_myName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: n.color, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          onUse: () => _store.use(n.id),
        );
      },
    );
  }

  Widget _badges() {
    final items = Store.badges;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final b = items[i];
        return _itemCard(
          id: b.id,
          name: b.name,
          price: b.price,
          vipOnly: b.vipOnly,
          inUse: _store.look.badge == b.id,
          preview: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SeatRing(style: _store.look.seatStyle, size: 72, child: _letter(26)),
                if (!b.none) Positioned(right: 0, bottom: 0, child: SeatBadge(style: b, size: 32)),
              ],
            ),
          ),
          onUse: () => _store.use(b.id),
        );
      },
    );
  }

  Widget _hits() {
    final items = Store.hits;
    return _itemGrid(
      count: items.length,
      itemBuilder: (i) {
        final h = items[i];
        return _itemCard(
          id: h.id,
          name: h.name,
          price: h.price,
          vipOnly: h.vipOnly,
          inUse: _store.look.hit == h.id,
          preview: SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const PlayingCardView(code: 'H14', width: 40),
                if (!h.none) IgnorePointer(child: HitBurst(style: h, size: 104, delay: Motion.stagger(i, stepMs: 150), loop: true)),
              ],
            ),
          ),
          onUse: () => _store.use(h.id),
        );
      },
    );
  }

  /// Just the sticker and its price — no caption, the way a sticker pack reads.
  Widget _emotes() {
    final items = Store.emotes;
    return _itemGrid(
      count: items.length,
      header: 'تُرسَل من زر الدردشة على الطاولة، ويراها كل اللاعبين.',
      itemBuilder: (i) {
        final e = items[i];
        return _itemCard(
          id: e.id,
          name: e.label,
          showName: false,
          price: e.price,
          vipOnly: e.vipOnly,
          inUse: false,
          preview: Semantics(label: e.label, child: EmoteFace(id: e.id, size: 84)),
        );
      },
    );
  }

  // ── المسرّعات ───────────────────────────────────────────────────────────────

  Widget _boosters() {
    final until = _store.boostUntil;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SamrahColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: until != null ? SamrahColors.accent : SamrahColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.rocket_launch_rounded, size: 34, color: until != null ? SamrahColors.accent : SamrahColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(until != null ? 'المسرّع يعمل' : 'ضاعف خبرتك', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
                    const Text('كل لعبة تنهيها تمنحك ضعف نقاط الخبرة، فتصعد المستويات أسرع.', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (until != null) ...[const SizedBox(width: 8), _Countdown(until: until)],
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, b) in Store.boosters.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: _boosterCard(b)),
          ),
        const Text(
          'شراء مسرّع وأنت تملك واحداً يعمل يضيف وقته إلى الوقت الباقي.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SamrahColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  static String _hours(int h) => h == 24 ? 'يوم كامل' : (h <= 10 ? '$h ساعات' : '$h ساعة');

  Widget _boosterCard(Booster b) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SamrahColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: SamrahColors.line)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.rocket_launch_rounded, color: SamrahColors.accent, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسرّع الخبرة ×2', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                Text(_hours(b.hours), style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(92, 42), padding: EdgeInsets.zero),
              onPressed: _busy ? null : () => _buyBooster(b),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StarIcon(size: 16),
                  const SizedBox(width: 6),
                  Text('${b.price}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyBooster(Booster b) async {
    if (_store.stars < b.price) {
      _say('رصيد النجوم لا يكفي — تحتاج ${b.price - _store.stars} نجمة أخرى');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: Text('مسرّع الخبرة · ${_hours(b.hours)}', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('سيُخصم ${b.price} نجمة من رصيدك (${_store.stars}) ويبدأ المسرّع فوراً.', style: const TextStyle(color: SamrahColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('شغّل المسرّع'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await _run(() => _store.buy(b.id))) _say('بدأ المسرّع: خبرتك مضاعفة ${_hours(b.hours)}');
  }

  // ── العضوية ─────────────────────────────────────────────────────────────────

  Widget _membership() {
    const perks = [
      (Icons.style_rounded, 'ظهر الورق «الذهبي» الحصري'),
      (Icons.table_restaurant_rounded, 'طاولة «الملكي» الحصرية'),
      (Icons.auto_awesome_rounded, 'مقعد واسم وضربة ذهبية، وشارة التاج وإيموجي «الملك»'),
      (Icons.card_giftcard_rounded, 'الهدية اليومية مضاعفة'),
      (Icons.workspace_premium_rounded, 'شارة العضو الذهبي بجانب اسمك'),
    ];
    final vip = _store.vip;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF2E2614), Color(0xFF151515)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: Border.all(color: _gold, width: 1.2),
          ),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 56, color: _gold),
              const SizedBox(height: 6),
              Text('العضوية الذهبية', style: GoogleFonts.cairo(color: _gold, fontSize: 24, fontWeight: FontWeight.w700)),
              Text(
                vip && _store.vipUntil != null ? 'حتى ${_store.vipUntil!.year}/${_store.vipUntil!.month}/${_store.vipUntil!.day} · التجديد يضيف 30 يوماً' : '30 يوماً',
                style: const TextStyle(color: SamrahColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (final (icon, text) in perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(icon, color: _gold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text, style: const TextStyle(color: SamrahColors.text, fontSize: 14))),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_backFan(Store.cardBacks.last), const SizedBox(width: 24), SizedBox(width: 120, height: 80, child: TableFelt(style: Store.tables.last, radius: 18))],
              ),
              const SizedBox(height: 20),
              if (vip) ...[
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold)),
                  child: const Text('أنت عضو ذهبي', style: TextStyle(color: _gold, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
              ],
                ElevatedButton(
                  onPressed: _busy ? null : _joinVip,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(vip ? 'جدّد بـ ' : 'اشترك بـ ', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const StarIcon(size: 18, color: SamrahColors.onAccent),
                      const SizedBox(width: 4),
                      Text('${Store.vipPrice}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _joinVip() async {
    if (_store.stars < Store.vipPrice) {
      _say('رصيد النجوم لا يكفي — تحتاج ${Store.vipPrice - _store.stars} نجمة أخرى');
      setState(() => _stars = true);
      _tab.animateTo(StoreScreen.coinsTab);
      return;
    }
    final wasVip = _store.vip;
    if (await _run(_store.buyVip)) _say(wasVip ? 'جُدّدت عضويتك 30 يوماً' : 'مبروك! صرت عضواً ذهبياً');
  }
}

/// «وحدات»: an orange coin with the letter «س».
class UnitIcon extends StatelessWidget {
  const UnitIcon({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFFFFB066), SamrahColors.accent, Color(0xFFB85600)], stops: [0, 0.6, 1], center: Alignment(-0.3, -0.4)),
        border: Border.all(color: const Color(0xFFFFD2A0), width: size * 0.05),
      ),
      child: Text('س', style: GoogleFonts.cairo(color: SamrahColors.onAccent, fontSize: size * 0.55, fontWeight: FontWeight.w800, height: 1)),
    );
  }
}

/// «نجوم».
class StarIcon extends StatelessWidget {
  const StarIcon({super.key, required this.size, this.color = const Color(0xFFE8C77A)});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(Icons.star_rounded, size: size * 1.15, color: color);
}

/// Time left until [until], ticking every second (days first when there are any).
class _Countdown extends StatefulWidget {
  const _Countdown({required this.until});
  final DateTime until;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.until.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final days = left.inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: SamrahColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: SamrahColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: SamrahColors.textMuted),
          const SizedBox(width: 4),
          if (days > 0) Text('$days ${days == 1 ? 'يوم' : (days == 2 ? 'يومان' : 'أيام')} ', style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
          Directionality(textDirection: TextDirection.ltr, child: Text(clock, style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
        ],
      ),
    );
  }
}
