// المتجر (`s-store`) — design/layout-v3.md §9, grown into four sections:
// currency packs (segmented وحدات / نجوم, two-column grid), card backs, tables
// and gold membership. Backs and tables are bought with «وحدات» and used at once
// in every game; membership costs «نجوم». DEMO: balances live in memory
// (lib/services/store.dart) and real-money packs only explain that payment is
// not switched on yet.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/store.dart';
import '../theme/samrah_theme.dart';
import '../widgets/motion.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/table_stage.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.initialTab = 0});

  /// 0 العملات · 1 ظهر الورق · 2 الطاولات · 3 العضوية
  final int initialTab;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final _store = Store.instance;
  late final _tab = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialTab);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
  bool _stars = false; // العملات: which currency's packs are showing

  static const _tabs = ['العملات', 'ظهر الورق', 'الطاولات', 'العضوية'];

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

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
                  tabAlignment: TabAlignment.center,
                  labelColor: SamrahColors.text,
                  unselectedLabelColor: SamrahColors.textMuted,
                  labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
                  indicatorColor: SamrahColors.selectedBg,
                  dividerColor: SamrahColors.line,
                  tabs: [for (final t in _tabs) Tab(text: t, height: 44)],
                ),
              ],
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: _store,
          builder: (_, _) => TabBarView(controller: _tab, children: [_coins(), _backs(), _tables(), _membership()]),
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

  // ── العملات ─────────────────────────────────────────────────────────────────

  Widget _coins() {
    final packs = _stars ? Store.starPacks : Store.unitPacks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _dailyGift(),
        const SizedBox(height: 16),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 168),
          itemCount: packs.length,
          itemBuilder: (_, i) => EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: _packCard(packs[i])),
        ),
        const SizedBox(height: 14),
        const Text(
          'نسخة تجريبية: الدفع غير مفعّل بعد، والأرصدة تعود لقيمتها عند إعادة تشغيل التطبيق.',
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
              onPressed: claimed
                  ? null
                  : () {
                      final amount = _store.giftAmount;
                      _store.claimGift();
                      _say('أُضيفت $amount وحدة إلى رصيدك');
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
                const SizedBox(height: 6),
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
                    onPressed: () => _say('الدفع غير مفعّل بعد — هذه نسخة تجريبية'),
                    child: Directionality(textDirection: TextDirection.ltr, child: Text(p.price, style: const TextStyle(fontWeight: FontWeight.w700))),
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

  Widget _itemGrid({required int count, required Widget Function(int) itemBuilder}) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 210),
      itemCount: count,
      itemBuilder: (_, i) => EnterFrom(delay: Motion.stagger(i), offset: const Offset(0, 24), child: itemBuilder(i)),
    );
  }

  Widget _itemCard({
    required String id,
    required String name,
    required int price,
    required bool vipOnly,
    required bool inUse,
    required Widget preview,
    required VoidCallback onUse,
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
    } else if (owned) {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: () {
          onUse();
          _say('صار «$name» هو المستخدم في كل الألعاب');
        },
        child: const Text('استخدم', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    } else if (vipOnly) {
      action = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: _gold, side: const BorderSide(color: _gold)),
        onPressed: () => _tab.animateTo(3),
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
          ),
          const SizedBox(height: 8),
          action,
        ],
      ),
    );
  }

  Future<void> _confirmBuy({required String id, required String name, required int price, required VoidCallback onUse}) async {
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
            child: const Text('اشترِ واستخدم'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (_store.buy(id, price)) {
      onUse();
      _say('اشتريت «$name» وصار مستخدماً في كل الألعاب');
    }
  }

  // ── العضوية ─────────────────────────────────────────────────────────────────

  Widget _membership() {
    const perks = [
      (Icons.style_rounded, 'ظهر الورق «الذهبي» الحصري'),
      (Icons.table_restaurant_rounded, 'طاولة «الملكي» الحصرية'),
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
              const Text('30 يوماً', style: TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
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
              if (vip)
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold)),
                  child: const Text('أنت عضو ذهبي', style: TextStyle(color: _gold, fontSize: 17, fontWeight: FontWeight.w700)),
                )
              else
                ElevatedButton(
                  onPressed: _joinVip,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(child: Text('اشترك بـ ', maxLines: 1, overflow: TextOverflow.ellipsis)),
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

  void _joinVip() {
    if (_store.buyVip()) {
      _say('مبروك! صرت عضواً ذهبياً');
    } else {
      _say('رصيد النجوم لا يكفي — تحتاج ${Store.vipPrice - _store.stars} نجمة أخرى');
      setState(() => _stars = true);
      _tab.animateTo(0);
    }
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
