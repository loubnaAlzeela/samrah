// Baloot table on the same fixed 390×793 canvas as the other games: team
// score diamond (we = vertical pair) with the contract under it (صن / حكم +
// raises), the three other players (crown on the buyer, their auction call
// or projects under them), the middle of the table — the face-up card
// («المشترى») during the auction, then the trick — the hand sorted by Baloot
// strength, and my panel with our score and card points.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_card.dart';
import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../services/game_audio.dart';
import '../theme/samrah_theme.dart';
import '../widgets/hand_view.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/suit_icon.dart';
import '../widgets/table_stage.dart';
import '../widgets/motion.dart';
import '../widgets/game_over.dart';
import '../widgets/trick_card.dart';
import '../widgets/turn_clock.dart';

const double _stageW = 390;
const double _stageH = 793;
const double _tableL = 53, _tableT = 132, _tableW = 286, _tableH = 392;
const double _avatarSize = 62;
const _avatarCenter = <int, Offset>{1: Offset(346, 326), 2: Offset(195, 118), 3: Offset(44, 326)};
const _trickCenter = <int, Offset>{0: Offset(195, 392), 1: Offset(243, 322), 2: Offset(195, 254), 3: Offset(147, 322)};
const double _trickW = 58;

class BalootGameScreen extends StatefulWidget {
  const BalootGameScreen({super.key, required this.view, required this.conn});
  final RoomView view;
  final RoomConnection conn;

  @override
  State<BalootGameScreen> createState() => _BalootGameScreenState();
}

class _BalootGameScreenState extends State<BalootGameScreen> with TurnClock {
  /// Round 2: the «حكم ثاني» button opens the suit choice.
  bool _pickSuit = false;

  @override
  void initState() {
    super.initState();
    startClock(widget.view);
    playTableAudio(null, widget.view);
  }

  @override
  void didUpdateWidget(BalootGameScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.view, widget.view)) {
      syncClock(widget.view);
      playTableAudio(old.view, widget.view);
      final g = widget.view.baloot;
      if (g == null || g.phase != 'bidding' || g.turn != g.mySeat) _pickSuit = false;
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
    final g = v.baloot;
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

  Widget _stage(RoomView v, BalootView g) {
    final conn = widget.conn;
    final me = v.mySeat!;
    int seatAt(int slot) => (me + slot) % 4;
    int slotOf(int seat) => (seat - me + 4) % 4;
    String name(int s) => v.seats[s]?.name ?? '؟';
    final myTurn = g.turn == me;
    final acting = ['bidding', 'double', 'playing'].contains(g.phase) && v.status == 'playing';
    final frac = acting ? turnFrac : 0.0;
    final ms = msLeft;
    final secs = acting && ms != null ? (ms / 1000).ceil() : null;
    final meAuto = v.seats[me]?.auto ?? false;
    // a finished trick's winner is `turn` (the server hands them the lead at once); `lastTrick` still holds
    // the previous trick until this one is collected
    final winnerSeat = g.phase == 'trickDone' && g.trick.length == 4 ? g.turn : null;
    final us = me % 2;

    final last = g.lastTrick;
    String? lastAt(int slot) {
      if (last == null) return null;
      for (final p in last.plays) {
        if (slotOf(p.seat) == slot) return p.card;
      }
      return null;
    }

    final bidding = myTurn && g.phase == 'bidding' && v.status == 'playing' && !meAuto;
    final raising = myTurn && g.phase == 'double' && g.myRaiseStep != null && v.status == 'playing' && !meAuto;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: meAuto ? (_) => conn.send('back') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 8,
            top: 12,
            child: ScoreDiamond(
              top: g.teamScores[seatAt(2) % 2],
              left: g.teamScores[seatAt(3) % 2],
              right: g.teamScores[seatAt(1) % 2],
              bottom: g.teamScores[us],
              center: '${g.target}',
            ),
          ),
          if (g.mode != null) Positioned(left: 14, top: 98, child: _contractChip(g, name)),
          Positioned(right: 10, top: 14, child: LastTrickDiamond(cardAt: lastAt)),

          const Positioned(left: _tableL, top: _tableT, width: _tableW, height: _tableH, child: TableFelt()),

          for (final slot in [2, 3, 1]) ..._seat(v, g, seatAt(slot), slot, name, frac, acting),

          if (g.flipped != null && !bidding)
            Positioned(
              left: _stageW / 2 - 34,
              top: 262,
              child: Column(
                children: [
                  PopIn(key: ValueKey(g.flipped), from: 0.5, duration: Motion.slow, child: PlayingCardView(code: g.flipped!, width: 68)),
                  const SizedBox(height: 6),
                  _smallPill('المشترى · جولة ${g.bidRound == 1 ? 'أولى' : 'ثانية'}'),
                ],
              ),
            ),

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

          if (g.phase != 'handOver' && v.status == 'playing' && !bidding && !raising)
            Positioned(left: _tableL, width: _tableW, top: _tableT + _tableH - 46, child: Center(child: _turnBanner(g, myTurn, name, winnerSeat, secs))),

          if (bidding) _centerPanel(title: g.confirming ? 'أكّد الحكم أو اقلبه صن' : 'الشراء · الجولة ${g.bidRound == 1 ? 'الأولى' : 'الثانية'}', secs: secs, child: _bidPanel(g, name)),
          if (raising) _centerPanel(title: 'المضاعفة', secs: secs, child: _raisePanel(g)),
          if (g.phase == 'handOver' && g.lastResult != null) _centerPanel(child: _handResult(g, name)),

          Positioned(
            left: 6,
            top: 541,
            child: HandView(
              cards: g.myHand,
              trump: g.trump,
              power: (c) => balootRankPower(c, g.trump),
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
          if (g.buyer == me) const Positioned(left: 92, top: 680, child: CrownMark()),
          if (g.dealer == me) const Positioned(left: 14, top: 676, child: DealerTag()),
          Positioned(left: 111, top: 676, child: _iconBtn(Icons.chat_bubble_outline, 'الدردشة')),
          Positioned(left: 111, top: 724, child: _iconBtn(Icons.card_giftcard, 'الهدايا')),
          Positioned(left: 168, top: 682, child: _infoRow('نتيجتنا', '${g.teamScores[us]}')),
          if (g.mode != null) Positioned(left: 168, top: 726, child: _infoRow('أبناطنا', '${g.abnat[us]}')),
          if (_myProjectsLine(g) != null) Positioned(left: 168, top: 648, child: _smallPill(_myProjectsLine(g)!)),

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

          if (v.status == 'finished')
            GameOverOverlay(
              variant: v.variant,
              won: g.winner == g.mySeat % 2,
              sides: GameOverSide.teams(name, g.teamScores, g.winner),
              note: g.qahwa ? 'انتهت بقهوة' : null,
              onRematch: () => widget.conn.send('rematch'),
              onHome: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }

  // --- seats -----------------------------------------------------------------

  List<Widget> _seat(RoomView v, BalootView g, int s, int slot, String Function(int) name, double frac, bool acting) {
    final c = _avatarCenter[slot]!;
    final seat = v.seats[s];
    final isTurn = g.turn == s && acting;
    final fanBox = 34 * PlayingCardView.aspect * 2 + 34;
    var label = name(s);
    if (seat != null && seat.auto && !seat.bot) label = '$label (آلي)';
    if (seat != null && !seat.connected && !seat.auto && !seat.bot) label = '$label (منقطع)';

    // under the seat: their last call during the auction, their projects during play
    String? note;
    if (g.phase == 'bidding') {
      final calls = g.bidLog.where((b) => b.seat == s).toList();
      if (calls.isNotEmpty) note = _callText(calls.last);
    } else if (g.phase != 'double') {
      final ps = g.projects.where((p) => p.seat == s).toList();
      if (ps.isNotEmpty) note = ps.map((p) => balootProjectAr(p.kind) + (p.counts == false ? ' ✗' : '')).join(' · ');
    }

    return [
      if (g.handCounts[s] > 0) Positioned(left: c.dx - fanBox / 2, top: c.dy - fanBox / 2, child: SeatFan(mirror: slot == 1)),
      Positioned(
        left: c.dx - _avatarSize / 2,
        top: c.dy - _avatarSize / 2,
        child: SeatAvatar(name: name(s), size: _avatarSize, turn: isTurn, frac: frac, bot: seat?.bot ?? false),
      ),
      Positioned(left: c.dx - 42, top: c.dy + 27, child: NamePill(text: label)),
      if (g.buyer == s) Positioned(left: c.dx + 16, top: c.dy - _avatarSize / 2 - 6, child: const CrownMark(size: 16)),
      if (g.dealer == s) Positioned(left: c.dx - _avatarSize / 2 - 6, top: c.dy - _avatarSize / 2 - 4, child: const DealerTag()),
      if (note != null) Positioned(left: c.dx - 55, width: 110, top: c.dy + 52, child: Center(child: _smallPill(note))),
    ];
  }

  String _callText(BalootBid b) {
    final base = balootCallAr(b.call, round: b.round);
    if (b.call == 'hokm' && b.suit != null) return '$base ${suitSymbolFromCode(b.suit!)}';
    return base;
  }

  String? _myProjectsLine(BalootView g) {
    final mine = g.projects.where((p) => p.seat == g.mySeat).toList();
    if (mine.isEmpty) return null;
    return 'مشاريعك: ${mine.map((p) => balootProjectAr(p.kind)).join(' · ')}';
  }

  Widget _smallPill(String t) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: SamrahColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: SamrahColors.fieldBorder)),
          child: Text(t, style: const TextStyle(color: SamrahColors.text, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1)),
        ),
      );

  // --- contract chip ------------------------------------------------------------

  Widget _contractChip(BalootView g, String Function(int) name) {
    const st = TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w700, height: 1);
    final parts = <Widget>[
      Text(g.mode == 'sun' ? (g.ashkal ? 'أشكل' : 'صن') : 'حكم', style: st),
      if (g.trump != null) ...[const SizedBox(width: 4), SuitChip(suit: g.trump!, size: 18)],
      if (g.qahwa)
        const Text(' · قهوة', style: st)
      else if (g.level > 1)
        Text(' · ${balootRaiseAr(const ['', '', 'double', 'triple', 'four'][g.level])}', style: st),
      if (g.closed) const Text(' · مغلق', style: st),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: SamrahColors.scorebox, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: parts),
      ),
    );
  }

  // --- banners and panels ---------------------------------------------------------

  Widget _turnBanner(BalootView g, bool myTurn, String Function(int) name, int? winnerSeat, int? secs) {
    const st = TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600);
    String? text;
    if (g.phase == 'trickDone' && winnerSeat != null) {
      text = 'أخذها ${winnerSeat == g.mySeat ? 'أنت' : name(winnerSeat)}';
    } else if (g.phase == 'bidding') {
      text = g.confirming ? '${name(g.turn)} يؤكّد الحكم…' : 'دور ${myTurn ? 'ك' : name(g.turn)} في الشراء';
    } else if (g.phase == 'double') {
      text = '${name(g.turn)} يقرّر ${balootRaiseAr(g.raiseStep ?? 'double')}…';
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
            Text(text, style: st),
            if (secs != null && g.phase != 'trickDone') Text(' · $secs ث', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _centerPanel({String? title, int? secs, required Widget child}) {
    return popInPositioned(Positioned(
      left: _tableL + 16,
      width: _tableW - 32,
      top: _tableT + 40,
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

  Widget _bidPanel(BalootView g, String Function(int) name) {
    final send = widget.conn.send;
    final flipped = g.flipped;
    final header = <Widget>[
      if (flipped != null)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('المشترى', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
            const SizedBox(width: 8),
            Directionality(textDirection: TextDirection.ltr, child: PlayingCardView(code: flipped, width: 40)),
          ],
        ),
      if (g.hokmCallSeat != null && !g.confirming)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${name(g.hokmCallSeat!)} طلب حكم، ويمكنك قلبه صن', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
        ),
      const SizedBox(height: 10),
    ];

    if (g.confirming) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...header,
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _panelButton('تأكيد الحكم', onTap: () => send('call', {'call': 'hokm'}), suit: g.hokmCallSuit),
          _panelButton('صن', onTap: () => send('call', {'call': 'sun'})),
        ]),
      ]);
    }

    if (_pickSuit) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...header,
        const Text('اختر نوع الحكم', style: TextStyle(color: SamrahColors.text, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final s in g.hokmSuits) _panelButton(suitNameArFromCode(s), suit: s, onTap: () => send('call', {'call': 'hokm', 'suit': s})),
          _panelButton('رجوع', onTap: () => setState(() => _pickSuit = false)),
        ]),
      ]);
    }

    final buttons = <Widget>[
      if (g.callOptions.contains('sun')) _panelButton('صن', onTap: () => send('call', {'call': 'sun'})),
      if (g.callOptions.contains('hokm') && g.hokmSuits.isNotEmpty)
        g.bidRound == 1
            ? _panelButton('حكم', suit: g.hokmSuits.first, onTap: () => send('call', {'call': 'hokm', 'suit': g.hokmSuits.first}))
            : _panelButton('حكم ثاني', onTap: () => setState(() => _pickSuit = true)),
      if (g.callOptions.contains('ashkal')) _panelButton('أشكل', onTap: () => send('call', {'call': 'ashkal'})),
      if (g.callOptions.contains('pass')) _panelButton(balootCallAr('pass', round: g.bidRound), onTap: () => send('call', {'call': 'pass'})),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ...header,
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: buttons),
    ]);
  }

  Widget _raisePanel(BalootView g) {
    final send = widget.conn.send;
    final step = g.myRaiseStep!;
    final label = balootRaiseAr(step);
    final hint = switch (step) {
      'double' => g.mode == 'sun' ? 'دبل: تُضاعف نقاط الجولة للفريق الفائز' : 'دبل: تُضاعف نقاط الجولة للفريق الفائز. اختر اللعب مفتوحًا أو مغلقًا',
      'triple' => 'تربل: ثلاثة أضعاف نقاط الجولة',
      'four' => 'فور: أربعة أضعاف نقاط الجولة. اختر اللعب مفتوحًا أو مغلقًا',
      _ => 'قهوة: الفريق الفائز بهذه الجولة يفوز باللعبة كلها',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          if (g.myRaiseChooseClosed) ...[
            _panelButton('$label مفتوح', onTap: () => send('raise', {'raise': true, 'closed': false})),
            _panelButton('$label مغلق', onTap: () => send('raise', {'raise': true, 'closed': true})),
          ] else
            _panelButton(label, onTap: () => send('raise', {'raise': true})),
          _panelButton('لا', onTap: () => send('raise', {'raise': false})),
        ]),
      ],
    );
  }

  Widget _panelButton(String label, {required VoidCallback onTap, String? suit}) {
    return Material(
      color: SamrahColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: SamrahColors.fieldBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 92),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
              if (suit != null) ...[const SizedBox(width: 6), SuitChip(suit: suit, size: 20)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _handResult(BalootView g, String Function(int) name) {
    final r = g.lastResult!;
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    const muted = TextStyle(color: SamrahColors.textMuted, fontSize: 12);
    if (r.kind == 'redeal') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('لا أحد اشترى', style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('تُعاد القسمة مع الموزّع التالي…', style: muted),
      ]);
    }
    final us = g.mySeat % 2;
    final them = 1 - us;
    final buyerUs = r.buyer != null && r.buyer! % 2 == us;
    String title;
    if (r.kaboot != null) {
      title = r.kaboot == us ? 'كبوت لنا!' : 'كبوت علينا';
    } else if (r.success) {
      title = buyerUs ? 'نجح شراؤنا' : 'نجح شراء الخصم';
    } else {
      title = buyerUs ? 'خسرنا الشراء' : 'خسر الخصم الشراء';
    }
    Widget row(String label, int a, int b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: muted)),
            SizedBox(width: 48, child: Text('$a', textAlign: TextAlign.center, style: body)),
            SizedBox(width: 48, child: Text('$b', textAlign: TextAlign.center, style: body)),
          ]),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('${r.mode == 'sun' ? 'صن' : 'حكم ${suitSymbolFromCode(r.trump ?? '')}'} · المشتري ${name(r.buyer ?? 0)}${r.qahwa ? ' · قهوة' : r.level > 1 ? ' · ×${r.level}' : ''}', style: muted),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: SizedBox()),
          SizedBox(width: 48, child: Text('لنا', textAlign: TextAlign.center, style: body.copyWith(fontWeight: FontWeight.w700))),
          SizedBox(width: 48, child: Text('لهم', textAlign: TextAlign.center, style: body.copyWith(fontWeight: FontWeight.w700))),
        ]),
        row('الأبناط', r.abnat[us], r.abnat[them]),
        row('المشاريع', r.projectPoints[us], r.projectPoints[them]),
        const Divider(height: 10, color: SamrahColors.line),
        row('النقاط', r.teamDelta[us], r.teamDelta[them]),
        const SizedBox(height: 6),
        const Text('الجولة التالية بعد لحظات…', style: muted),
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
}

/// Where a thrown card starts (and a won trick goes): the player's seat, or my hand for me (slot 0).
Offset _throwFrom(int slot, Map<int, Offset> avatars) => slot == 0 ? const Offset(195, 640) : avatars[slot]!;
