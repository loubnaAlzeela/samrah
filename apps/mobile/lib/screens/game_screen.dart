// Live gameplay on a fixed 390×793 canvas (scaled to fit the screen): score diamond + last trick up top, the table with the
// three other players around it, the trick in the middle, the full-width
// hand, and my own panel (avatar with turn ring, chat, tricks / bid).
// Positions are physical (they never mirror with RTL): me at the bottom,
// partner on top, next player in turn order on the right.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../services/game_audio.dart';
import '../theme/samrah_theme.dart';
import '../widgets/table_social.dart';
import '../widgets/bid_panel.dart';
import '../widgets/hand_view.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/suit_icon.dart';
import '../widgets/table_stage.dart';
import '../widgets/motion.dart';
import '../widgets/game_over.dart';
import '../widgets/trick_card.dart';
import '../widgets/trump_panel.dart';
import '../widgets/turn_clock.dart';

const double _stageW = 390;
const double _stageH = 793;

// Table rectangle on the canvas.
const double _tableL = 53, _tableT = 132, _tableW = 286, _tableH = 392;

// Avatar centres by physical slot (0 bottom = me, 1 right, 2 top, 3 left).
const _avatarCenter = <int, Offset>{1: Offset(346, 326), 2: Offset(195, 118), 3: Offset(44, 326)};
const double _avatarSize = 62;

// Trick card centres by slot.
const _trickCenter = <int, Offset>{0: Offset(195, 392), 1: Offset(243, 322), 2: Offset(195, 254), 3: Offset(147, 322)};
const double _trickW = 58;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.view, required this.conn});

  final RoomView view;
  final RoomConnection conn;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TurnClock {
  @override
  void initState() {
    super.initState();
    startClock(widget.view);
    playTableAudio(null, widget.view);
  }

  @override
  void didUpdateWidget(GameScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.view, widget.view)) {
      syncClock(widget.view);
      playTableAudio(old.view, widget.view);
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
    final g = v.game;
    if (g == null || v.mySeat == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(v.pending ? 'ستأخذ مقعد الحاسوب بعد انتهاء الأكلة الحالية…' : 'اللعبة جارية وليس لك مقعد فيها.', textAlign: TextAlign.center),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) => Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF383838), SamrahColors.bg]),
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
      ),
    );
  }

  Widget _stage(RoomView v, PlayerView g) {
    final conn = widget.conn;
    final me = v.mySeat!;
    int seatAt(int slot) => (me + slot) % 4;
    int slotOf(int seat) => (seat - me + 4) % 4;
    String name(int s) => v.seats[s]?.name ?? '؟';
    final us = me % 2;
    // Syrian 41 and 400: each seat bids for itself and scores alone
    final syrian = g.variant == 'syrian41' || g.variant == 'tarneeb400';
    final myTurn = g.turn == me;
    final acting = ['bidding', 'trump', 'playing'].contains(g.phase) && v.status == 'playing';
    final msLeft = this.msLeft;
    final frac = acting ? turnFrac : 0.0;
    final secs = acting && msLeft != null ? (msLeft / 1000).ceil() : null;
    // a finished trick's winner is `turn` (the server hands them the lead at once); `lastTrick` still holds
    // the previous trick until this one is collected
    final winnerSeat = g.phase == 'trickDone' && g.trick.length == 4 ? g.turn : null;
    final meAuto = v.seats[me]?.auto ?? false;
    final panelOpen = myTurn && (g.phase == 'bidding' || g.phase == 'trump');

    // score cells: tarneeb = team totals (vertical pair us), syrian = each seat's own
    int cell(int slot) => syrian ? g.seatScores[seatAt(slot)] : (slot % 2 == 0 ? g.teamScores[us] : g.teamScores[1 - us]);

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
      // touching the screen while the autopilot plays for me = "I'm back"
      onTapDown: meAuto ? (_) => conn.send('back') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 8, top: 12, child: ScoreDiamond(top: cell(2), left: cell(3), right: cell(1), bottom: cell(0), center: '${g.target}', usVertical: !syrian)),
          Positioned(right: 10, top: 14, child: LastTrickDiamond(cardAt: lastAt)),
          // 400: the trump is always hearts — shown where Syrian shows its turned-up card
          if (g.variant == 'tarneeb400' && g.trump != null)
            Positioned(
              right: 90,
              top: 20,
              child: Column(children: [
                const Text('الطرنيب', style: TextStyle(color: SamrahColors.textMuted, fontSize: 10)),
                const SizedBox(height: 4),
                SuitIcon(suit: g.trump!, size: 26, color: const Color(0xFFE5484D)),
              ]),
            ),
          if (syrian && g.revealed != null)
            Positioned(
              right: 90,
              top: 20,
              child: Column(children: [
                const Text('المقلوبة', style: TextStyle(color: SamrahColors.textMuted, fontSize: 10)),
                const SizedBox(height: 2),
                PlayingCardView(code: g.revealed!, width: 28),
              ]),
            ),

          const Positioned(left: _tableL, top: _tableT, width: _tableW, height: _tableH, child: TableFelt()),

          // the three other players
          for (final slot in [2, 3, 1]) ..._seat(v, g, seatAt(slot), slot, name, frac, acting, syrian),

          // my empty slot while I still have to play
          if (g.phase == 'playing' && myTurn && !g.trick.any((p) => p.seat == me)) _mySlot(),

          // the trick
          for (final p in g.trick)
            TrickCard(
              key: ValueKey(p.card),
              code: p.card,
              width: _trickW,
              from: _throwFrom(slotOf(p.seat), _avatarCenter),
              to: _trickCenter[slotOf(p.seat)]!,
              highlight: winnerSeat == p.seat,
              hit: lookOf(v.seats, p.seat)?.hitStyle,
              collectTo: winnerSeat == null ? null : _throwFrom(slotOf(winnerSeat), _avatarCenter),
            ),

          if (_awayName(v) != null && v.status == 'playing')
            Positioned(left: _tableL, width: _tableW, top: _tableT + 12, child: Center(child: _pill('بانتظار ${_awayName(v)}…', soft: true))),

          if (!panelOpen && g.phase != 'handOver' && v.status == 'playing')
            Positioned(
              left: _tableL,
              width: _tableW,
              top: _tableT + _tableH - 46,
              child: Center(child: _turnBanner(g, myTurn, name, winnerSeat, secs)),
            ),

          if (myTurn && g.phase == 'bidding')
            _centerPanel(
              title: syrian ? 'كم أكلة ستأخذ وحدك؟' : 'اختر الطلبة',
              secs: secs,
              child: BidPanel(
                minBid: g.minBid,
                syrian: syrian,
                onBid: (b) => conn.send('bid', {'value': b}),
                onPass: () => conn.send('bid', {'value': 'pass'}),
              ),
            ),
          if (myTurn && g.phase == 'trump')
            _centerPanel(title: 'اختر الطرنيب', secs: secs, child: TrumpPanel(onPick: (s) => conn.send('trump', {'suit': s}))),

          if (g.phase == 'handOver' && g.lastResult != null) _centerPanel(child: _HandResult(g: g, name: name, us: us)),

          // my hand
          Positioned(
            left: 6,
            top: 541,
            child: HandView(
              cards: g.myHand,
              trump: g.trump,
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
          Positioned(
            left: 64 - _avatarSize / 2,
            top: 708 - _avatarSize / 2,
            child: SeatAvatar(name: name(me), look: lookOf(v.seats, me), size: _avatarSize, turn: myTurn && acting && !meAuto, frac: frac),
          ),
          Positioned(left: 64 - 45, top: 742, child: NamePill(text: name(me), look: lookOf(v.seats, me), width: 90, highlight: true)),
          if (g.dealer == me) const Positioned(left: 14, top: 676, child: DealerTag()), // left of my avatar, clear of the chat icon
          Positioned(left: 111, top: 676, child: _iconBtn(Icons.chat_bubble_outline, 'الدردشة', () => openTableChat(context, widget.conn, v))),
          Positioned(left: 111, top: 724, child: _iconBtn(Icons.card_giftcard, 'الهدايا', () => openGiftSheet(context, widget.conn, v))),
          // chat bubbles and gifts over everything at the table
          Positioned.fill(key: const ValueKey('table-social'), child: TableSocialLayer(conn: widget.conn, mySeat: me, anchor: (s) => slotOf(s) == 0 ? const Offset(64, 708) : _avatarCenter[slotOf(s)]!)),
          Positioned(left: 168, top: 679, child: _infoRow('أكلات', Text(syrian ? '${g.tricks[me]}' : '${g.tricks[me] + g.tricks[(me + 2) % 4]}', style: _infoValue))),
          Positioned(left: 168, top: 722, child: _infoRow('طلبة', _bidValue(g, me, syrian))),

          if (meAuto)
            Positioned(
              left: 0,
              right: 0,
              top: 500,
              child: Center(
                child: Material(
                  color: SamrahColors.panel,
                  shape: StadiumBorder(side: BorderSide(color: SamrahColors.fieldBorder)),
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
              won: g.winner == us,
              sides: GameOverSide.teams(name, g.teamScores, g.winner),
              onRematch: () => conn.send('rematch'),
              onHome: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }

  List<Widget> _seat(RoomView v, PlayerView g, int s, int slot, String Function(int) name, double frac, bool acting, bool syrian) {
    final c = _avatarCenter[slot]!;
    final seat = v.seats[s];
    final isTurn = g.turn == s && acting;
    final fanBox = 34 * PlayingCardView.aspect * 2 + 34;
    var label = name(s);
    if (seat != null && seat.auto && !seat.bot) label = '$label (آلي)';
    if (seat != null && !seat.connected && !seat.auto && !seat.bot) label = '$label (منقطع)';

    // count box: bid while bidding, otherwise tricks taken (syrian: tricks/bid)
    String count;
    final b = g.lastBidBy(s);
    if (g.phase == 'bidding' && b != null) {
      count = b == 'pass' ? 'تمرير' : '$b';
    } else if (syrian && g.seatBids[s] != null) {
      count = '${g.tricks[s]}/${g.seatBids[s]}';
    } else {
      count = '${g.tricks[s]}';
    }
    // count box sits under the pill, nudged toward the table centre
    final countDx = slot == 1 ? -30.0 : (slot == 3 ? 30.0 : 28.0);

    return [
      if (g.handCounts[s] > 0)
        Positioned(left: c.dx - fanBox / 2, top: c.dy - fanBox / 2, child: SeatFan(mirror: slot == 1)),
      Positioned(
        left: c.dx - _avatarSize / 2,
        top: c.dy - _avatarSize / 2,
        child: SeatAvatar(name: name(s), look: lookOf(v.seats, s), size: _avatarSize, turn: isTurn, frac: frac, bot: seat?.bot ?? false),
      ),
      Positioned(left: c.dx - 42, top: c.dy + 27, child: NamePill(text: label, look: lookOf(v.seats, s))),
      Positioned(
        left: c.dx + countDx - 55,
        width: 110,
        top: c.dy + 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (g.dealer == s && slot != 1) ...[const DealerTag(), const SizedBox(width: 3)],
            CountBox(text: count),
            if (g.dealer == s && slot == 1) ...[const SizedBox(width: 3), const DealerTag()],
          ],
        ),
      ),
    ];
  }

  String? _awayName(RoomView v) {
    for (final s in v.seats) {
      if (s != null && !s.connected && !s.auto && !s.bot) return s.name;
    }
    return null;
  }

  Widget _mySlot() {
    final c = _trickCenter[0]!;
    const h = _trickW * PlayingCardView.aspect;
    return Positioned(
      left: c.dx - _trickW / 2,
      top: c.dy - h / 2,
      child: Container(
        width: _trickW,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x73F5EBDD), width: 2),
        ),
      ),
    );
  }

  Widget _turnBanner(PlayerView g, bool myTurn, String Function(int) name, int? winnerSeat, int? secs) {
    Widget? text;
    const st = TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600);
    if (g.phase == 'trickDone' && winnerSeat != null) {
      text = Text('أخذها ${winnerSeat == g.mySeat ? 'أنت' : name(winnerSeat)}', style: st);
    } else if (g.phase == 'bidding') {
      text = Text(myTurn ? 'دورك · اطلب' : '${name(g.turn)} يطلب…', style: st);
    } else if (g.phase == 'trump') {
      text = Text(myTurn ? 'اختر الطرنيب' : '${name(g.turn)} يختار الطرنيب…', style: st);
    } else if (g.phase == 'playing') {
      if (myTurn) {
        final led = g.trick.isNotEmpty ? g.trick.first.card[0] : null;
        final follows = led != null && g.legal.every((c) => c[0] == led);
        text = follows
            ? Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.rtl, children: [const Text('دورك · العب ', style: st), SuitLabel(suit: led, style: st)])
            : const Text('دورك · العب أي ورقة', style: st);
      } else {
        text = Text('دور ${name(g.turn)}', style: st);
      }
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
            text,
            if (secs != null && g.phase != 'trickDone') Text(' · $secs ث', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _centerPanel({String? title, int? secs, required Widget child}) {
    return popInPositioned(Positioned(
      left: _tableL + 30,
      width: _tableW - 60,
      top: _tableT + 60,
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

  Widget _pill(String t, {bool soft = false}) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: soft ? SamrahColors.surface2 : SamrahColors.panel, borderRadius: BorderRadius.circular(16)),
          child: Text(t, style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) => SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: SamrahColors.text, size: 24),
          onPressed: onTap,
        ),
      );

  static const _infoValue = TextStyle(color: SamrahColors.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1);

  Widget _bidValue(PlayerView g, int me, bool syrian) {
    if (syrian) return Text(g.seatBids[me] != null ? '${g.seatBids[me]}' : '-', style: _infoValue);
    final hb = g.highBid;
    if (hb == null) return const Text('-', style: _infoValue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${hb.value}', style: _infoValue),
        if (g.trump != null) ...[const SizedBox(width: 5), SuitIcon(suit: g.trump!, size: 16, color: g.trump == 'H' || g.trump == 'D' ? const Color(0xFFE5484D) : SamrahColors.text)],
      ],
    );
  }

  /// One «label | value» row: value cell on the left, label on the right.
  Widget _infoRow(String label, Widget value) {
    return Container(
      width: 184,
      height: 36,
      decoration: BoxDecoration(border: Border.all(color: SamrahColors.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(child: Container(color: SamrahColors.scorebox, alignment: Alignment.center, child: value)),
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

class _HandResult extends StatelessWidget {
  const _HandResult({required this.g, required this.name, required this.us});
  final PlayerView g;
  final String Function(int) name;
  final int us;

  static String _signed(int v) => v > 0 ? '+$v' : (v < 0 ? '−${-v}' : '0');

  static String _noteText(String note) => switch (note) {
        'made' => 'حققوا الطلب',
        'kaboot' => 'كبوت!',
        'kaboot13' => 'طلبوا 13 وحققوها!',
        'fail' => 'لم يحققوا الطلب',
        'fail13' => 'طلبوا 13 ولم يحققوها',
        'allPass' => 'مرّر الجميع: إعادة توزيع',
        'lowBids' => 'مجموع الطلبات أقل من 11: إعادة توزيع',
        'syrian' => 'انتهت الجولة',
        _ => 'نتيجة الجولة',
      };

  @override
  Widget build(BuildContext context) {
    final r = g.lastResult!;
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_noteText(r.note), style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (r.kind == 'scored' && r.bidder != null) Text('${name(r.bidder!)} طلب ${r.bid} وأخذ فريقه ${r.bidderTricks}', textAlign: TextAlign.center, style: body),
        if (r.kind == 'scored' && r.note == 'syrian')
          for (var s = 0; s < 4; s++) Text('${name(s)}: طلب ${g.seatBids[s] ?? 0} أكل ${g.tricks[s]} ← ${_signed(r.seatDelta[s])}', style: body),
        if (r.kind == 'scored') Text('لنا ${_signed(r.teamDelta[us])} · لهم ${_signed(r.teamDelta[1 - us])}', style: body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('الجولة التالية بعد لحظات…', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

/// Where a thrown card starts (and a won trick goes): the player's seat, or my hand for me (slot 0).
Offset _throwFrom(int slot, Map<int, Offset> avatars) => slot == 0 ? const Offset(195, 640) : avatars[slot]!;
