// Saudi Hand table on the fixed 390×793 canvas. The other 1–4 players sit
// in a row at the top (cards left, score, «نزل» once they laid down), the
// melds on the table fill the middle (tap one to add the picked card to it),
// the stock and the discard pile («النار») sit under them, then my hand.
// Cards are picked with a tap (several at a time); the action bar builds a
// group («مجموعة»), lays the groups down («نزّل»), or discards («ارمِ»).
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
import '../widgets/turn_clock.dart';

const double _stageW = 390;
const double _stageH = 793;
const double _tableL = 8, _tableT = 104, _tableW = 374, _tableH = 380;
const double _meldCardW = 30;
const double _meldStep = 15;

class HandGameScreen extends StatefulWidget {
  const HandGameScreen({super.key, required this.view, required this.conn});
  final RoomView view;
  final RoomConnection conn;

  @override
  State<HandGameScreen> createState() => _HandGameScreenState();
}

class _HandGameScreenState extends State<HandGameScreen> with TurnClock {
  final Set<String> _picked = {};

  /// groups built this turn, laid down together with «نزّل» (the first lay-down must reach the minimum in one go)
  final List<List<String>> _groups = [];

  @override
  void initState() {
    super.initState();
    startClock(widget.view);
    playTableAudio(null, widget.view);
  }

  @override
  void didUpdateWidget(HandGameScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.view, widget.view)) {
      syncClock(widget.view);
      playTableAudio(old.view, widget.view);
      final g = widget.view.hand;
      final hand = g?.myHand ?? const <String>[];
      _picked.removeWhere((c) => !hand.contains(c));
      _groups.removeWhere((grp) => !grp.every(hand.contains));
      if (g == null || g.turn != g.mySeat || g.phase != 'playing') _groups.clear();
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
    final g = v.hand;
    if (g == null || v.mySeat == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(v.pending ? 'ستأخذ مقعد الحاسوب قريبًا…' : 'اللعبة جارية وليس لك مقعد فيها.', textAlign: TextAlign.center),
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

  Widget _stage(RoomView v, HandGameView g) {
    final conn = widget.conn;
    final me = v.mySeat!;
    String name(int s) => s < v.seats.length ? (v.seats[s]?.name ?? '؟') : '؟';
    final myTurn = g.turn == me && v.status == 'playing';
    final acting = (g.phase == 'draw' || g.phase == 'playing') && v.status == 'playing';
    final frac = acting ? turnFrac : 0.0;
    final ms = msLeft;
    final secs = acting && ms != null ? (ms / 1000).ceil() : null;
    final meAuto = v.seats[me]?.auto ?? false;
    final canAct = myTurn && !meAuto;
    final drawing = canAct && g.phase == 'draw';
    final playing = canAct && g.phase == 'playing';
    final staged = _groups.expand((x) => x).toSet();
    final handShown = g.myHand.where((c) => !staged.contains(c)).toList();
    final others = [for (var i = 1; i < g.players; i++) (me + i) % g.players];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: meAuto ? (_) => conn.send('back') : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // the other players, in turn order from my right
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            height: 92,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final s in others.reversed) _player(v, g, s, name, frac, acting)]),
          ),

          const Positioned(left: _tableL, top: _tableT, width: _tableW, height: _tableH, child: TableFelt()),
          Positioned(
            left: _tableL + 8,
            top: _tableT + 8,
            right: _stageW - _tableL - _tableW + 8,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  _chip('الجولة ${g.handNo} من ${g.rounds}'),
                  const SizedBox(width: 6),
                  _chip('النزول الأول ${g.openMin}+'),
                  const Spacer(),
                  if (secs != null) _chip('${myTurn ? 'دورك' : 'دور ${name(g.turn)}'} · $secs ث'),
                ],
              ),
            ),
          ),
          Positioned(left: _tableL + 8, top: _tableT + 40, width: _tableW - 16, height: _tableH - 118, child: _meldsArea(g, name, playing)),

          // stock and discard pile
          Positioned(left: _tableL + 8, right: _stageW - _tableL - _tableW + 8, top: _tableT + _tableH - 74, child: _piles(g, drawing)),

          if (_groups.isNotEmpty) Positioned(left: 8, right: 8, top: _tableT + _tableH + 4, child: _stagedRow()),

          Positioned(
            left: 6,
            top: 560,
            child: HandView(
              cards: handShown,
              trump: null,
              power: handSortPower,
              legal: null,
              onPlay: (_) {},
              picked: _picked,
              onPick: (c) => setState(() => _picked.contains(c) ? _picked.remove(c) : _picked.add(c)),
            ),
          ),

          // action bar + my panel
          Positioned(
            left: 6,
            right: 6,
            top: 690,
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
            left: 14,
            top: 700,
            child: SeatAvatar(name: name(me), size: 50, turn: myTurn && acting && !meAuto, frac: frac),
          ),
          Positioned(left: 8, top: 754, child: NamePill(text: name(me), width: 62, highlight: true)),
          Positioned(left: 76, right: 12, top: 700, height: 84, child: _actions(g, playing, drawing)),

          if (meAuto)
            Positioned(
              left: 0,
              right: 0,
              top: 520,
              child: Center(
                child: Material(
                  color: SamrahColors.panel,
                  shape: const StadiumBorder(side: BorderSide(color: SamrahColors.fieldBorder)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => conn.send('back'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Text(
                        'الحاسوب يلعب عنك · أنا هنا، أعِدني',
                        style: TextStyle(color: SamrahColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (g.phase == 'handOver' && g.lastResult != null) _centerPanel(_roundResult(g, name)),
          if (v.status == 'finished') ...[const Positioned.fill(child: ColoredBox(color: Color(0x99000000))), _centerPanel(_gameOver(g, name))],
        ],
      ),
    );
  }

  // --- players ---------------------------------------------------------------------

  Widget _player(RoomView v, HandGameView g, int s, String Function(int) name, double frac, bool acting) {
    final seat = s < v.seats.length ? v.seats[s] : null;
    var label = name(s);
    if (seat != null && seat.auto && !seat.bot) label = '$label (آلي)';
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SeatAvatar(name: name(s), size: 44, turn: g.turn == s && acting, frac: frac, bot: seat?.bot ?? false),
              Positioned(right: -10, bottom: -2, child: CountBox(text: '${g.handCounts[s]}')),
              if (g.dealer == s) const Positioned(left: -8, top: -4, child: DealerTag()),
            ],
          ),
          const SizedBox(height: 3),
          NamePill(text: label, width: 72),
          const SizedBox(height: 2),
          Text(
            '${g.scores[s]}${g.opened[s] ? ' · نزل' : ''}',
            style: const TextStyle(color: SamrahColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- melds -----------------------------------------------------------------------

  Widget _meldsArea(HandGameView g, String Function(int) name, bool playing) {
    if (g.melds.isEmpty) {
      return const Center(
        child: Text('لم ينزل أحد بعد', style: TextStyle(color: SamrahColors.textMuted, fontSize: 13)),
      );
    }
    final canLayoff = playing && g.opened[g.mySeat] && _picked.length == 1;
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final m in g.melds)
            PopIn(
              key: ValueKey('meld${m.id}'),
              from: 0.7,
              child: GestureDetector(
                onTap: canLayoff ? () => widget.conn.send('layoff', {'card': _picked.first, 'meld': m.id}) : null,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: canLayoff ? SamrahColors.turnRing : Colors.transparent),
                  ),
                  child: SizedBox(
                    width: _meldCardW + _meldStep * (m.cards.length - 1),
                    height: _meldCardW * PlayingCardView.aspect,
                    child: Stack(
                      children: [
                        for (var i = 0; i < m.cards.length; i++)
                          Positioned(
                            left: i * _meldStep,
                            child: PlayingCardView(code: m.cards[i].card, width: _meldCardW),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- piles -----------------------------------------------------------------------

  Widget _piles(HandGameView g, bool drawing) {
    const label = TextStyle(color: SamrahColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: drawing ? () => widget.conn.send('draw', {'from': 'stock'}) : null,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: drawing ? SamrahColors.turnRing : Colors.transparent, width: 2),
                ),
                child: const CardBack(width: 40),
              ),
              Text('الكومة ${g.stockCount}', style: label),
            ],
          ),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: drawing && g.fireTop != null ? () => widget.conn.send('draw', {'from': 'fire'}) : null,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: drawing && g.fireTop != null ? SamrahColors.turnRing : Colors.transparent, width: 2),
                ),
                child: g.fireTop != null
                    ? PopIn(
                        key: ValueKey(g.fireTop),
                        from: 0.5,
                        child: PlayingCardView(code: g.fireTop!, width: 40),
                      )
                    : const SizedBox(width: 40, height: 40 * PlayingCardView.aspect),
              ),
              Text('النار ${g.fireCount}', style: label),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stagedRow() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _groups.length; i++)
              GestureDetector(
                onTap: () => setState(() => _groups.removeAt(i)),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: SamrahColors.panel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SamrahColors.fieldBorder),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(children: [for (final c in _groups[i]) PlayingCardView(code: c, width: 24)]),
                  ),
                ),
              ),
            const Text('اضغط على مجموعة لإلغائها', style: TextStyle(color: SamrahColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // --- actions ---------------------------------------------------------------------

  Widget _actions(HandGameView g, bool playing, bool drawing) {
    final send = widget.conn.send;
    String hint;
    if (drawing) {
      hint = 'اسحب من الكومة أو خذ ورقة النار';
    } else if (playing && g.fireCard != null) {
      hint = 'أخذت ورقة النار: نزّلها في مجموعة';
    } else if (playing && !g.opened[g.mySeat]) {
      hint = 'نزولك الأول يجب أن يكون ${g.openMin} أو أكثر';
    } else if (playing) {
      hint = 'اختر أوراقًا، أو ورقة واحدة ثم اضغط مجموعة على الأرض لتركيبها';
    } else {
      hint = g.opened[g.mySeat] ? 'نزلت · نتيجتك ${g.scores[g.mySeat]}' : 'نتيجتك ${g.scores[g.mySeat]}';
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (playing)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _btn(
                  'مجموعة',
                  _picked.length >= 3,
                  () => setState(() {
                    _groups.add(_picked.toList());
                    _picked.clear();
                  }),
                ),
                _btn('نزّل', _groups.isNotEmpty, () {
                  send('meld', {'groups': _groups.map((x) => x.toList()).toList()});
                  setState(() => _groups.clear());
                }),
                _btn('ارمِ', _picked.length == 1 && _groups.isEmpty, () {
                  send('discard', {'card': _picked.first});
                  setState(() => _picked.clear());
                }),
                if (g.canUndoFire) _btn('أرجع ورقة النار', true, () => send('undoFire')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _btn(String label, bool enabled, VoidCallback onTap) => SizedBox(
    height: 34,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
      onPressed: enabled ? onTap : null,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    ),
  );

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: SamrahColors.panel, borderRadius: BorderRadius.circular(10)),
    child: Text(
      t,
      style: const TextStyle(color: SamrahColors.text, fontSize: 11, fontWeight: FontWeight.w600, height: 1.1),
    ),
  );

  // --- panels ----------------------------------------------------------------------

  Widget _centerPanel(Widget child) => popInPositioned(
    Positioned(
      left: 40,
      right: 40,
      top: 150,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: SamrahColors.panel,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: child,
        ),
      ),
    ),
  );

  static String _signed(int v) => v > 0 ? '+$v' : (v < 0 ? '−${-v}' : '0');

  Widget _roundResult(HandGameView g, String Function(int) name) {
    final r = g.lastResult!;
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    final title = r.winner == null ? 'انتهت الكومة' : '${r.winner == g.mySeat ? 'أنهيت' : 'أنهى ${name(r.winner!)}'}${r.hand ? ' · هاند!' : ''}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (var s = 0; s < g.players; s++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: Text('${name(s)}${s < r.opened.length && !r.opened[s] ? ' (لم ينزل)' : ''}', style: body)),
                Text(_signed(r.delta[s]), style: body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const Text('الجولة التالية بعد لحظات…', style: TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _gameOver(HandGameView g, String Function(int) name) {
    final ranking = [for (var i = 0; i < g.players; i++) i]..sort((a, b) => g.scores[a] - g.scores[b]);
    const body = TextStyle(color: SamrahColors.text, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          g.winners.contains(g.mySeat) ? 'فزت!' : 'انتهت اللعبة',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < ranking.length; i++)
          Row(
            children: [
              Expanded(child: Text('${i + 1}. ${name(ranking[i])}', style: body)),
              Text('${g.scores[ranking[i]]}', style: body.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => widget.conn.send('rematch'),
          child: const Text('مباراة جديدة بنفس الطاولة', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('للصفحة الرئيسية')),
      ],
    );
  }
}
