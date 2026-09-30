// Trix table on the same fixed 390×793 canvas as GameScreen: score diamond
// (per seat, or per team in partners) with the current contract under it,
// the table with the three other players (crown on the kingdom owner), the
// middle of the table — played trick (king / queens / diamonds / tricks) or
// the four suit columns built out from the Jacks (trix) — the hand, and my
// panel with my score.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../services/game_audio.dart';
import '../theme/samrah_theme.dart';
import '../widgets/hand_view.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/table_stage.dart';
import '../widgets/motion.dart';
import '../widgets/trick_card.dart';
import '../widgets/turn_clock.dart';

const double _stageW = 390;
const double _stageH = 793;
const double _tableL = 53, _tableT = 132, _tableW = 286, _tableH = 392;
const double _avatarSize = 62;
const _avatarCenter = <int, Offset>{1: Offset(346, 326), 2: Offset(195, 118), 3: Offset(44, 326)};
const _trickCenter = <int, Offset>{0: Offset(195, 392), 1: Offset(243, 322), 2: Offset(195, 254), 3: Offset(147, 322)};
const double _trickW = 58;

// trix columns: card width and the step between stacked cards
const double _colW = 46;
const double _colStep = 20;

class TrixGameScreen extends StatefulWidget {
  const TrixGameScreen({super.key, required this.view, required this.conn});
  final RoomView view;
  final RoomConnection conn;

  @override
  State<TrixGameScreen> createState() => _TrixGameScreenState();
}

class _TrixGameScreenState extends State<TrixGameScreen> with TurnClock {
  final Set<String> _toDouble = {};

  @override
  void initState() {
    super.initState();
    startClock(widget.view);
    playTableAudio(null, widget.view);
  }

  @override
  void didUpdateWidget(TrixGameScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.view, widget.view)) {
      syncClock(widget.view);
      playTableAudio(old.view, widget.view);
      if (widget.view.trix?.phase != 'double') _toDouble.clear();
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
    final g = v.trix;
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

  Widget _stage(RoomView v, TrixView g) {
    final conn = widget.conn;
    final me = v.mySeat!;
    int seatAt(int slot) => (me + slot) % 4;
    int slotOf(int seat) => (seat - me + 4) % 4;
    String name(int s) => v.seats[s]?.name ?? '؟';
    final myTurn = g.turn == me;
    final acting = ['contract', 'double', 'playing'].contains(g.phase) && v.status == 'playing';
    final frac = acting ? turnFrac : 0.0;
    final ms = msLeft;
    final secs = acting && ms != null ? (ms / 1000).ceil() : null;
    final meAuto = v.seats[me]?.auto ?? false;
    final isTrix = g.contract == 'trix';
    // a finished trick's winner is `turn` (the server hands them the lead at once); `lastTrick` still holds
    // the previous trick until this one is collected
    final winnerSeat = g.phase == 'trickDone' && g.trick.length == 4 ? g.turn : null;

    // partners: vertical pair = us; solo: each cell is that seat's own score
    int cell(int slot) => g.partners ? g.teamScores[seatAt(slot) % 2] : g.seatScores[seatAt(slot)];
    final myScore = g.partners ? g.teamScores[me % 2] : g.seatScores[me];

    final last = g.lastTrick;
    String? lastAt(int slot) {
      if (last == null) return null;
      for (final p in last.plays) {
        if (slotOf(p.seat) == slot) return p.card;
      }
      return null;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: meAuto ? (_) => conn.send('back') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 8, top: 12, child: ScoreDiamond(top: cell(2), left: cell(3), right: cell(1), bottom: cell(0), center: '${g.kingdom + 1}', usVertical: g.partners)),
          if (g.contract != null) Positioned(left: 14, top: 98, child: _contractChip(g)),
          if (g.doubled.isNotEmpty) Positioned(left: 14, top: 128, child: _doubledRow(g)),
          if (!isTrix) Positioned(right: 10, top: 14, child: LastTrickDiamond(cardAt: lastAt)),

          const Positioned(left: _tableL, top: _tableT, width: _tableW, height: _tableH, child: TableFelt()),

          for (final slot in [2, 3, 1]) ..._seat(v, g, seatAt(slot), slot, name, frac, acting),

          if (isTrix) ..._layoutColumns(g),

          if (!isTrix)
            for (final p in g.trick)
              TrickCard(
                key: ValueKey(p.card),
                code: p.card,
                width: _trickW,
                from: _throwFrom(slotOf(p.seat), _avatarCenter),
                to: _trickCenter[slotOf(p.seat)]!,
                highlight: winnerSeat == p.seat,
                collectTo: winnerSeat == null ? null : _throwFrom(slotOf(winnerSeat), _avatarCenter),
              ),

          if (g.phase != 'handOver' && v.status == 'playing' && !(myTurn && (g.phase == 'contract' || g.phase == 'double')))
            Positioned(left: _tableL, width: _tableW, top: _tableT + _tableH - 46, child: Center(child: _turnBanner(g, myTurn, name, winnerSeat, secs))),

          if (myTurn && g.phase == 'contract' && v.status == 'playing') _centerPanel(title: 'اختر الطلبة', secs: secs, child: _contractPicker(g)),
          if (myTurn && g.phase == 'double' && v.status == 'playing') _centerPanel(title: 'هل تريد التدبيل؟', secs: secs, child: _doublePicker(g)),
          if (g.phase == 'handOver' && g.lastResult != null) _centerPanel(child: _handResult(g, name)),

          Positioned(
            left: 6,
            top: 541,
            child: HandView(
              cards: g.myHand,
              trump: null,
              legal: myTurn && g.phase == 'playing' && !meAuto ? g.legal : null,
              onPlay: (card) => conn.send('play', {'card': card}),
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
          if (g.kingdomOwner == me) const Positioned(left: 92, top: 680, child: CrownMark()),
          Positioned(left: 111, top: 676, child: _iconBtn(Icons.chat_bubble_outline, 'الدردشة')),
          Positioned(left: 111, top: 724, child: _iconBtn(Icons.card_giftcard, 'الهدايا')),
          Positioned(left: 168, top: 682, child: _infoRow(g.partners ? 'نتيجتنا' : 'النتيجة', '$myScore')),
          if (!isTrix && g.contract != null) Positioned(left: 168, top: 726, child: _infoRow('هذه الجولة', _signed(g.handPoints[me]))),
          if (isTrix && g.finishOrder.contains(me)) Positioned(left: 168, top: 726, child: _infoRow('ترتيبك', '${g.finishOrder.indexOf(me) + 1}')),

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

  // --- seats -----------------------------------------------------------------

  List<Widget> _seat(RoomView v, TrixView g, int s, int slot, String Function(int) name, double frac, bool acting) {
    final c = _avatarCenter[slot]!;
    final seat = v.seats[s];
    final isTurn = g.turn == s && acting;
    final fanBox = 34 * PlayingCardView.aspect * 2 + 34;
    var label = name(s);
    if (seat != null && seat.auto && !seat.bot) label = '$label (آلي)';
    if (seat != null && !seat.connected && !seat.auto && !seat.bot) label = '$label (منقطع)';
    final score = g.seatScores[s];
    final live = g.contract != null && g.contract != 'trix' ? g.handPoints[s] : 0;
    final countDx = slot == 1 ? -30.0 : (slot == 3 ? 30.0 : 28.0);
    final passed = g.contract == 'trix' && g.phase == 'playing' && g.lastPasses.contains(s);
    final place = g.contract == 'trix' ? g.finishOrder.indexOf(s) : -1;

    return [
      if (g.handCounts[s] > 0) Positioned(left: c.dx - fanBox / 2, top: c.dy - fanBox / 2, child: SeatFan(mirror: slot == 1)),
      Positioned(
        left: c.dx - _avatarSize / 2,
        top: c.dy - _avatarSize / 2,
        child: SeatAvatar(name: name(s), size: _avatarSize, turn: isTurn, frac: frac, bot: seat?.bot ?? false),
      ),
      Positioned(left: c.dx - 42, top: c.dy + 27, child: NamePill(text: label)),
      Positioned(
        left: c.dx + countDx - 55,
        width: 110,
        top: c.dy + 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (g.kingdomOwner == s && slot != 1) ...[const CrownMark(size: 14), const SizedBox(width: 3)],
            CountBox(text: '$score'),
            if (live != 0) ...[const SizedBox(width: 3), _liveTag(live)],
            if (g.kingdomOwner == s && slot == 1) ...[const SizedBox(width: 3), const CrownMark(size: 14)],
          ],
        ),
      ),
      if (passed) Positioned(left: c.dx - 20, top: c.dy - _avatarSize / 2 - 22, child: _smallPill('تمرير')),
      if (place >= 0) Positioned(left: c.dx - 20, top: c.dy - _avatarSize / 2 - 22, child: _smallPill('أنهى ${place + 1}')),
    ];
  }

  Widget _liveTag(int v) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF4A1A1A), borderRadius: BorderRadius.circular(4)),
        child: Text(_signed(v), style: const TextStyle(color: Color(0xFFF2A08E), fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
      );

  Widget _smallPill(String t) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: SamrahColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: SamrahColors.fieldBorder)),
          child: Text(t, style: const TextStyle(color: SamrahColors.text, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1)),
        ),
      );

  // --- the trix layout: one column per started suit ---------------------------

  List<Widget> _layoutColumns(TrixView g) {
    const order = ['C', 'D', 'S', 'H'];
    final started = order.where((s) => g.layout[s] != null).toList();
    if (started.isEmpty) return const [];
    const gap = 14.0;
    final total = started.length * _colW + (started.length - 1) * gap;
    final left0 = _tableL + (_tableW - total) / 2;
    const jackTop = _tableT + 30 + 3 * _colStep; // room for Q, K, A above the Jack
    final out = <Widget>[];
    for (var i = 0; i < started.length; i++) {
      final suit = started[i];
      final pile = g.layout[suit]!;
      final x = left0 + i * (_colW + gap);
      // highest first, so each lower card covers the bottom of the one above and every corner stays readable
      for (var r = pile.high; r >= pile.low; r--) {
        out.add(Positioned(key: ValueKey('L$suit$r'), left: x, top: jackTop + (11 - r) * _colStep, child: PopIn(from: 0.6, child: PlayingCardView(code: '$suit$r', width: _colW))));
      }
    }
    return out;
  }

  // --- top-left chips -----------------------------------------------------------

  Widget _contractChip(TrixView g) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(8)),
          child: Text(contractNameAr(g.contract!), style: const TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700, height: 1)),
        ),
      );

  Widget _doubledRow(TrixView g) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('مدبّل ', style: TextStyle(color: SamrahColors.textMuted, fontSize: 10)),
          for (final d in g.doubled) Padding(padding: const EdgeInsets.only(right: 2), child: PlayingCardView(code: d.card, width: 20)),
        ],
      );

  // --- banners and panels ---------------------------------------------------------

  Widget _turnBanner(TrixView g, bool myTurn, String Function(int) name, int? winnerSeat, int? secs) {
    const st = TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600);
    String? text;
    if (g.phase == 'trickDone' && winnerSeat != null) {
      text = 'أخذها ${winnerSeat == g.mySeat ? 'أنت' : name(winnerSeat)}';
    } else if (g.phase == 'contract') {
      text = '${name(g.kingdomOwner)} يختار الطلبة…';
    } else if (g.phase == 'double') {
      text = '${name(g.turn)} يقرّر التدبيل…';
    } else if (g.phase == 'playing') {
      text = myTurn ? (g.contract == 'trix' ? 'دورك · ضع ورقة' : 'دورك') : 'دور ${name(g.turn)}';
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
            Text(text, style: st),
            if (secs != null && g.phase != 'trickDone') Text(' · $secs ث', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _centerPanel({String? title, int? secs, required Widget child}) {
    return popInPositioned(Positioned(
      left: _tableL + 22,
      width: _tableW - 44,
      top: _tableT + 50,
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

  Widget _contractPicker(TrixView g) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in trixContracts)
          _panelButton(
            contractNameAr(c),
            enabled: g.contractsLeft.contains(c),
            onTap: () => widget.conn.send('contract', {'contract': c}),
          ),
      ],
    );
  }

  Widget _doublePicker(TrixView g) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          g.contract == 'king' ? 'من يأخذ شيخ الكبة المدبّل يخسر 150 وتربح أنت 75' : 'من يأخذ البنت المدبّلة يخسر 50 وتربح أنت 25',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 8,
            children: [
              for (final c in g.doubleOptions)
                GestureDetector(
                  onTap: () => setState(() => _toDouble.contains(c) ? _toDouble.remove(c) : _toDouble.add(c)),
                  child: PlayingCardView(code: c, width: 44, selected: _toDouble.contains(c)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: _toDouble.isEmpty ? null : () => widget.conn.send('double', {'cards': _toDouble.toList()}),
                child: const Text('دبّل', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => widget.conn.send('double', {'cards': <String>[]}),
                child: const Text('دون تدبيل', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panelButton(String label, {required bool enabled, required VoidCallback onTap}) {
    return Material(
      color: enabled ? SamrahColors.surface2 : SamrahColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: enabled ? SamrahColors.fieldBorder : SamrahColors.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 92,
          height: 40,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? SamrahColors.text : SamrahColors.disabledText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              decoration: enabled ? null : TextDecoration.lineThrough,
              decorationColor: SamrahColors.disabledText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _handResult(TrixView g, String Function(int) name) {
    final r = g.lastResult!;
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    final order = r.contract == 'trix' ? r.finishOrder : [0, 1, 2, 3];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('انتهت ${contractNameAr(r.contract)}', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < order.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: Text(r.contract == 'trix' ? '${i + 1}. ${name(order[i])}' : name(order[i]), style: body)),
                Text(_signed(r.seatDelta[order[i]]), style: body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (g.partners) ...[
          const SizedBox(height: 6),
          Text('لنا ${_signed(r.teamDelta[g.mySeat % 2])} · لهم ${_signed(r.teamDelta[1 - g.mySeat % 2])}', style: body.copyWith(fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 6),
        const Text('الجولة التالية بعد لحظات…', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _gameOver(TrixView g, String Function(int) name) {
    final won = g.winnerSeats.contains(g.mySeat);
    final ranking = [0, 1, 2, 3]..sort((a, b) => g.seatScores[b] - g.seatScores[a]);
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(won ? (g.partners ? 'فزنا!' : 'فزت!') : 'انتهت اللعبة', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (g.partners)
          Text('لنا ${g.teamScores[g.mySeat % 2]} · لهم ${g.teamScores[1 - g.mySeat % 2]}', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted))
        else
          for (var i = 0; i < 4; i++)
            Row(
              children: [
                Expanded(child: Text('${i + 1}. ${name(ranking[i])}', style: body)),
                Text('${g.seatScores[ranking[i]]}', style: body.copyWith(fontWeight: FontWeight.w700)),
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
              child: Text(value, style: const TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1)),
            ),
          ),
          Expanded(
            child: Container(
              color: SamrahColors.surface2,
              alignment: Alignment.center,
              child: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  static String _signed(int v) => v > 0 ? '+$v' : (v < 0 ? '−${-v}' : '0');
}

/// Where a thrown card starts (and a won trick goes): the player's seat, or my hand for me (slot 0).
Offset _throwFrom(int slot, Map<int, Offset> avatars) => slot == 0 ? const Offset(195, 640) : avatars[slot]!;
