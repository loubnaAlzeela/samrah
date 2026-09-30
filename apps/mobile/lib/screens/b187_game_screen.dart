// 187 («بيع وشراء») table on the same fixed 390×793 canvas as the other
// games. 4 or 5 seats: with 5, two players share the top of the table.
// Top-left: every player's running score (individual game, target ±312);
// top-right: the current bid and trump. The middle shows the field during
// the auction (face down until the bid reaches 140), then the trick.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../services/game_audio.dart';
import '../theme/samrah_theme.dart';
import '../widgets/hand_view.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/suit_icon.dart';
import '../widgets/table_stage.dart';
import '../widgets/motion.dart';
import '../widgets/trick_card.dart';
import '../widgets/trump_panel.dart';
import '../widgets/turn_clock.dart';

const double _stageW = 390;
const double _stageH = 793;
const double _tableL = 53, _tableT = 132, _tableW = 286, _tableH = 392;
const double _avatarSize = 62;
const double _trickW = 58;

/// Avatar centres by physical slot (0 = me at the bottom, then counter-clockwise).
Map<int, Offset> _avatarCenters(int n) => n == 5
    ? const {1: Offset(346, 326), 2: Offset(268, 118), 3: Offset(122, 118), 4: Offset(44, 326)}
    : const {1: Offset(346, 326), 2: Offset(195, 118), 3: Offset(44, 326)};

Map<int, Offset> _trickCenters(int n) => n == 5
    ? const {0: Offset(195, 392), 1: Offset(252, 330), 2: Offset(228, 256), 3: Offset(162, 256), 4: Offset(138, 330)}
    : const {0: Offset(195, 392), 1: Offset(243, 322), 2: Offset(195, 254), 3: Offset(147, 322)};

class B187GameScreen extends StatefulWidget {
  const B187GameScreen({super.key, required this.view, required this.conn});
  final RoomView view;
  final RoomConnection conn;

  @override
  State<B187GameScreen> createState() => _B187GameScreenState();
}

class _B187GameScreenState extends State<B187GameScreen> with TurnClock {
  /// cards picked to hand back (insertion order = which opponent gets which)
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    startClock(widget.view);
    playTableAudio(null, widget.view);
  }

  @override
  void didUpdateWidget(B187GameScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.view, widget.view)) {
      syncClock(widget.view);
      playTableAudio(old.view, widget.view);
      if (widget.view.b187?.phase != 'give') _picked.clear();
    }
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final g = v.b187;
    if (g == null || v.mySeat == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(v.pending ? 'ستأخذ مقعد الحاسوب بعد انتهاء الأكلة الحالية…' : 'اللعبة جارية وليس لك مقعد فيها.', textAlign: TextAlign.center),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF2C2420), SamrahColors.bg]),
      ),
      alignment: Alignment.topCenter,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: _stageW, height: _stageH, child: _stage(v, g)),
        ),
      ),
    );
  }

  String _name(RoomView v, int s) => s < v.seats.length ? (v.seats[s]?.name ?? '؟') : '؟';

  Widget _stage(RoomView v, B187View g) {
    final conn = widget.conn;
    final n = g.players;
    final me = v.mySeat!;
    int seatAt(int slot) => (me + slot) % n;
    int slotOf(int seat) => (seat - me + n) % n;
    String name(int s) => _name(v, s);
    final myTurn = g.turn == me;
    final acting = ['bidding', 'give', 'trump', 'playing', 'lossChoice'].contains(g.phase) && v.status == 'playing';
    final frac = acting ? turnFrac : 0.0;
    final ms = msLeft;
    final secs = acting && ms != null ? (ms / 1000).ceil() : null;
    final meAuto = v.seats[me]?.auto ?? false;
    // a finished trick's winner is `turn` (the server hands them the lead at once); `lastTrick` still holds
    // the previous trick until this one is collected
    final winnerSeat = g.phase == 'trickDone' && g.trick.length == n ? g.turn : null;
    final trickC = _trickCenters(n);
    final giving = myTurn && g.phase == 'give';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: meAuto ? (_) => conn.send('back') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 8, top: 10, child: _scoreBoard(g, name, seatAt)),
          Positioned(right: 8, top: 12, child: _bidInfo(g, name)),

          const Positioned(left: _tableL, top: _tableT, width: _tableW, height: _tableH, child: TableFelt()),

          for (var slot = 1; slot < n; slot++) ..._seat(v, g, seatAt(slot), slot, name, frac, acting),

          if (g.phase == 'bidding' && g.fieldCount > 0) _fieldRow(g),

          for (final p in g.trick)
            TrickCard(
              key: ValueKey(p.card),
              code: p.card,
              width: _trickW,
              from: _throwFrom(slotOf(p.seat), _avatarCenters(n)),
              to: trickC[slotOf(p.seat)]!,
              highlight: winnerSeat == p.seat,
              collectTo: winnerSeat == null ? null : _throwFrom(slotOf(winnerSeat), _avatarCenters(n)),
            ),

          if (v.status == 'playing' && g.phase != 'handOver' && !(myTurn && ['bidding', 'give', 'trump', 'lossChoice'].contains(g.phase)))
            Positioned(left: _tableL, width: _tableW, top: _tableT + _tableH - 46, child: Center(child: _turnBanner(g, myTurn, name, winnerSeat, secs))),

          if (myTurn && g.phase == 'bidding' && v.status == 'playing') _centerPanel(title: 'السوم', secs: secs, child: _bidPanel(g, name)),
          if (giving && v.status == 'playing') _centerPanel(title: 'أعطِ ورقة لكل خصم', secs: secs, top: _tableT + 20, child: _givePanel(g, name)),
          if (myTurn && g.phase == 'trump' && v.status == 'playing') _centerPanel(title: 'اختر الحكم', secs: secs, child: TrumpPanel(onPick: (s) => conn.send('trump', {'suit': s}))),
          if (myTurn && g.phase == 'lossChoice' && v.status == 'playing') _centerPanel(title: 'لم تحقق السوم', secs: secs, child: _lossPanel(g)),
          if (g.phase == 'handOver' && g.lastResult != null) _centerPanel(child: _handResult(g, name)),

          Positioned(
            left: 6,
            top: 541,
            child: HandView(
              cards: g.myHand,
              trump: g.trump,
              legal: myTurn && g.phase == 'playing' && !meAuto ? g.legal : null,
              onPlay: (card) => conn.send('play', {'card': card}),
              picked: giving ? _picked : null,
              onPick: giving
                  ? (c) => setState(() {
                        if (!_picked.remove(c) && _picked.length < g.giveCount) _picked.add(c);
                      })
                  : null,
            ),
          ),

          // my panel
          Positioned(
            left: 6,
            right: 6,
            top: 668,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: SamrahColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: SamrahColors.line)),
              ),
            ),
          ),
          Positioned(left: 64 - _avatarSize / 2, top: 708 - _avatarSize / 2, child: SeatAvatar(name: name(me), size: _avatarSize, turn: myTurn && acting && !meAuto, frac: frac)),
          Positioned(left: 64 - 45, top: 742, child: NamePill(text: name(me), width: 90, highlight: true)),
          if (g.buyer == me) const Positioned(left: 88, top: 676, child: _Tag('المشتري')),
          if (g.dealer == me) const Positioned(left: 98, top: 700, child: DealerTag()),
          Positioned(left: 111, top: 676, child: _iconBtn(Icons.chat_bubble_outline, 'الدردشة')),
          Positioned(left: 111, top: 724, child: _iconBtn(Icons.card_giftcard, 'الهدايا')),
          Positioned(left: 168, top: 682, child: _infoRow('النتيجة', '${g.scores[me]}')),
          Positioned(left: 168, top: 726, child: _infoRow('نقاط الجولة', '${g.collected.isEmpty ? 0 : g.collected[me]}')),

          if (meAuto)
            Positioned(
              left: 0,
              right: 0,
              top: 500,
              child: Center(
                child: Material(
                  color: SamrahColors.panel,
                  shape: const StadiumBorder(side: BorderSide(color: SamrahColors.fieldBorder)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => conn.send('back'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Text('الحاسوب يلعب عنك · أنا هنا، أعِدني', style: TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ),

          if (v.status == 'finished') ...[
            const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
            _centerPanel(child: _gameOver(g, name)),
          ],
        ],
      ),
    );
  }

  // --- seats ---------------------------------------------------------------------

  List<Widget> _seat(RoomView v, B187View g, int s, int slot, String Function(int) name, double frac, bool acting) {
    final c = _avatarCenters(g.players)[slot]!;
    final seat = s < v.seats.length ? v.seats[s] : null;
    final isTurn = g.turn == s && acting;
    final fanBox = 34 * PlayingCardView.aspect * 2 + 34;
    var label = name(s);
    if (seat != null && seat.auto && !seat.bot) label = '$label (آلي)';
    if (seat != null && !seat.connected && !seat.auto && !seat.bot) label = '$label (منقطع)';
    final side = slot == 1 ? -1.0 : (slot == g.players - 1 ? 1.0 : 0.0); // nudge the count box toward the table

    String count;
    final b = g.lastBidBy(s);
    if (g.phase == 'bidding') {
      count = g.passed.length > s && g.passed[s] ? 'انسحب' : (b == null ? '-' : '$b');
    } else {
      count = '${g.collected.length > s ? g.collected[s] : 0}';
    }

    return [
      if (g.handCounts.length > s && g.handCounts[s] > 0) Positioned(left: c.dx - fanBox / 2, top: c.dy - fanBox / 2, child: SeatFan(mirror: slot == 1)),
      Positioned(left: c.dx - _avatarSize / 2, top: c.dy - _avatarSize / 2, child: SeatAvatar(name: name(s), size: _avatarSize, turn: isTurn, frac: frac, bot: seat?.bot ?? false)),
      Positioned(left: c.dx - 42, top: c.dy + 27, child: NamePill(text: label)),
      Positioned(
        left: c.dx + side * 30 - 55,
        width: 110,
        top: c.dy + 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (g.dealer == s) ...[const DealerTag(), const SizedBox(width: 3)],
            CountBox(text: count),
          ],
        ),
      ),
      if (g.buyer == s) Positioned(left: c.dx - 30, top: c.dy - _avatarSize / 2 - 20, width: 60, child: const Center(child: _Tag('المشتري'))),
    ];
  }

  // --- top chips ---------------------------------------------------------------------

  Widget _scoreBoard(B187View g, String Function(int) name, int Function(int) seatAt) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(10), border: Border.all(color: SamrahColors.line)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var slot = 0; slot < g.players; slot++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name(seatAt(slot)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: slot == 0 ? SamrahColors.text : SamrahColors.textMuted, fontSize: 11, fontWeight: slot == 0 ? FontWeight.w700 : FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${g.scores[seatAt(slot)]}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            const Divider(height: 8, color: SamrahColors.line),
            const Text('الهدف ±312', style: TextStyle(color: SamrahColors.onTableAccent, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _bidInfo(B187View g, String Function(int) name) {
    final hb = g.highBid;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _chip(Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('السوم ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            Text(hb == null ? '-' : '${hb.value}', style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            if (hb != null) Text(' · ${name(hb.seat)}', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
          ])),
          if (g.trump != null) ...[
            const SizedBox(height: 6),
            _chip(Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('الحكم ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              SuitChip(suit: g.trump!, size: 20),
            ])),
          ],
        ],
      ),
    );
  }

  Widget _chip(Widget child) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(8)),
        child: child,
      );

  /// The field in the middle during the auction: face down, or face up from 140.
  Widget _fieldRow(B187View g) {
    const w = 44.0;
    final count = g.fieldCount;
    final total = count * w + (count - 1) * 6;
    return Positioned(
      left: _tableL + (_tableW - total) / 2,
      top: _tableT + 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
                  child: g.field.length == count ? PlayingCardView(code: g.field[i], width: w) : const CardBack(width: w),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(g.field.isEmpty ? 'الميدان · يُكشف عند 140' : 'الميدان مكشوف', style: const TextStyle(color: SamrahColors.onTableMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // --- panels ---------------------------------------------------------------------

  Widget _turnBanner(B187View g, bool myTurn, String Function(int) name, int? winnerSeat, int? secs) {
    String? text;
    if (g.phase == 'trickDone' && winnerSeat != null) {
      text = 'أخذها ${winnerSeat == g.mySeat ? 'أنت' : name(winnerSeat)}';
    } else if (g.phase == 'bidding') {
      text = '${name(g.turn)} يساوم…';
    } else if (g.phase == 'give') {
      text = '${name(g.turn)} يوزّع أوراقه على الخصوم…';
    } else if (g.phase == 'trump') {
      text = '${name(g.turn)} يختار الحكم…';
    } else if (g.phase == 'lossChoice') {
      text = '${name(g.turn)} يختار طريقة تسجيل الخسارة…';
    } else if (g.phase == 'playing') {
      text = myTurn ? 'دورك' : 'دور ${name(g.turn)}';
    }
    if (text == null) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: SamrahColors.panel, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
            if (secs != null && g.phase != 'trickDone') Text(' · $secs ث', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _centerPanel({String? title, int? secs, double top = _tableT + 50, required Widget child}) {
    return popInPositioned(Positioned(
      left: _tableL + 18,
      width: _tableW - 36,
      top: top,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: SamrahColors.panel,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                if (secs != null) Text('$secs ث', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                const Padding(padding: EdgeInsets.only(top: 8, bottom: 12), child: Divider(height: 1, color: SamrahColors.line)),
              ],
              child,
            ],
          ),
        ),
      ),
    ));
  }

  Widget _bidPanel(B187View g, String Function(int) name) {
    final min = g.minBid ?? 87;
    final options = <int>{for (var b = min; b <= 187 && b < min + 30; b += 5) b, 187}.toList()..sort();
    final hb = g.highBid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(hb == null ? 'افتح السوم من 87' : 'أعلى سوم: ${hb.value} (${name(hb.seat)})', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final b in options) _panelButton('$b', width: 56, onTap: () => widget.conn.send('bid', {'value': b}))],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(backgroundColor: SamrahColors.surface2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => widget.conn.send('bid', {'value': 'pass'}),
            child: const Text('انسحاب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _givePanel(B187View g, String Function(int) name) {
    final n = g.players;
    final opponents = [for (var i = 1; i < n; i++) (g.mySeat + i) % n];
    final picked = _picked.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('اختر ${g.giveCount} أوراق من يدك بالترتيب: الأولى لأول خصم، وهكذا.', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        for (var i = 0; i < opponents.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(name(opponents[i]), style: const TextStyle(color: SamrahColors.text, fontSize: 13))),
                if (i < picked.length) PlayingCardView(code: picked[i], width: 22) else const Text('—', style: TextStyle(color: SamrahColors.textMuted)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: picked.length == g.giveCount ? () => widget.conn.send('give', {'cards': picked}) : null,
            child: Text('أعطِ الأوراق (${picked.length}/${g.giveCount})', style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _lossPanel(B187View g) {
    final r = g.lastResult!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('جمعت ${r.collected[r.buyer]} من ${r.bid}.', style: const TextStyle(color: SamrahColors.text, fontSize: 13)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => widget.conn.send('loss', {'choice': 'bid'}),
            child: Text('سجّل −${r.bid} ويأخذ الخصوم نقاطهم', style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => widget.conn.send('loss', {'choice': 'full'}),
            child: const Text('سجّل −187 والخصوم صفر', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _panelButton(String label, {required VoidCallback onTap, double width = 92}) {
    return Material(
      color: SamrahColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: SamrahColors.fieldBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: width,
          height: 40,
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _handResult(B187View g, String Function(int) name) {
    final r = g.lastResult!;
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.lost ? 'خسر المشتري' : 'نجح المشتري', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(
          '${name(r.buyer)} ساوم ${r.bid} وجمع ${r.collected[r.buyer]}${r.full ? ' · خسارة كاملة' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (var s = 0; s < g.players; s++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: Text('${name(s)} · ${r.collected[s]} نقطة', style: body)),
                Text(_signed(r.seatDelta[s]), textDirection: TextDirection.ltr, style: body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const Text('الجولة التالية بعد لحظات…', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _gameOver(B187View g, String Function(int) name) {
    final won = g.winnerSeats.contains(g.mySeat);
    final ranking = List.generate(g.players, (i) => i)..sort((a, b) => g.scores[b] - g.scores[a]);
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(won ? 'فزت!' : 'انتهت المباراة', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (var i = 0; i < ranking.length; i++)
          Row(
            children: [
              Expanded(child: Text('${i + 1}. ${name(ranking[i])}', style: body)),
              Text('${g.scores[ranking[i]]}', textDirection: TextDirection.ltr, style: body.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: () => widget.conn.send('rematch'), child: const Text('مباراة جديدة بنفس الطاولة', style: TextStyle(fontSize: 14))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('للصفحة الرئيسية')),
      ],
    );
  }

  // --- my panel ----------------------------------------------------------------------

  Widget _iconBtn(IconData icon, String tooltip) => SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: SamrahColors.text, size: 24),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tooltip — قريباً'), duration: const Duration(seconds: 2))),
        ),
      );

  Widget _infoRow(String label, String value) {
    return Container(
      width: 184,
      height: 36,
      decoration: BoxDecoration(border: Border.all(color: SamrahColors.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: SamrahColors.scorebox,
              alignment: Alignment.center,
              child: Text(value, textDirection: TextDirection.ltr, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1)),
            ),
          ),
          Expanded(
            child: Container(
              color: SamrahColors.surface2,
              alignment: Alignment.center,
              child: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  static String _signed(int v) => v > 0 ? '+$v' : (v < 0 ? '−${-v}' : '0');
}

/// Small label pill (e.g. «المشتري»).
class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: SamrahColors.onTableAccent, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: SamrahColors.onAccent, fontSize: 10, fontWeight: FontWeight.w700, height: 1.2)),
    );
  }
}

/// Where a thrown card starts (and a won trick goes): the player's seat, or my hand for me (slot 0).
Offset _throwFrom(int slot, Map<int, Offset> avatars) => slot == 0 ? const Offset(195, 640) : avatars[slot]!;
