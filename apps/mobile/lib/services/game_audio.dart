// What the table sounds like, derived only from two consecutive server views
// (so every player hears the same thing, whoever acted): the deal, each card
// thrown, the trick gathered, your turn, the last seconds, the end of the
// game — and every player's choice spoken aloud (bids, «باس», the trump,
// Trix contracts and doubles, Baloot calls and raises, a Hand lay-down).
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/game_card.dart';
import '../models/room_view.dart';
import 'sound.dart';

/// Phases where somebody has to act (mirrors the server's ACTING_PHASES).
const _acting = {'bidding', 'trump', 'contract', 'double', 'give', 'draw', 'playing', 'lossChoice'};

/// The few facts every game shares, read from whichever game view the room carries.
class _Table {
  _Table(this.handNo, this.trickLen, this.phase, this.turn, this.me, this.handSize, this.won);
  final int handNo;
  final int trickLen;
  final String phase;
  final int turn;
  final int me;
  final int handSize;

  /// the game is over and I (or my team) won; null while it runs
  final bool? won;

  static _Table? of(RoomView v) {
    final me = v.mySeat;
    if (me == null) return null;
    final over = v.status == 'finished';
    if (v.game case final g?) return _Table(g.handNo, g.trick.length, g.phase, g.turn, me, g.myHand.length, over ? g.winner == me % 2 : null);
    if (v.trix case final g?) return _Table(g.handNo, g.trick.length, g.phase, g.turn, me, g.myHand.length, over ? g.winnerSeats.contains(me) : null);
    if (v.baloot case final g?) return _Table(g.handNo, g.trick.length, g.phase, g.turn, me, g.myHand.length, over ? g.winner == me % 2 : null);
    if (v.b187 case final g?) return _Table(g.handNo, g.trick.length, g.phase, g.turn, me, g.myHand.length, over ? g.winnerSeats.contains(me) : null);
    if (v.hand case final g?) return _Table(g.handNo, 0, g.phase, g.turn, me, g.myHand.length, over ? g.winners.contains(me) : null);
    return null;
  }
}

/// It is my turn to act now (drives the last-seconds tick).
bool isMyTurn(RoomView v) {
  final t = _Table.of(v);
  return t != null && t.turn == t.me && _acting.contains(t.phase) && v.status == 'playing';
}

/// Call with the previous view (null on the first one) and the new view.
void playTableAudio(RoomView? before, RoomView now) {
  final a = before == null ? null : _Table.of(before);
  final b = _Table.of(now);
  if (b == null) return;
  final s = Sound.instance;

  // a new round: the deal, one flick per card (follows the hand's deal animation)
  if (a == null || b.handNo != a.handNo) s.dealRun(b.handSize);
  if (a != null) {
    if (b.trickLen > a.trickLen) s.play(Sfx.cardThrow);
    // the trick is gathered to its winner (TrickCard.collectDelay)
    if (b.phase == 'trickDone' && a.phase != 'trickDone') s.play(Sfx.collect, delay: const Duration(milliseconds: 600));
    final myTurnNow = b.turn == b.me && _acting.contains(b.phase);
    final myTurnBefore = a.turn == a.me && _acting.contains(a.phase);
    if (myTurnNow && !myTurnBefore && now.status == 'playing') s.play(Sfx.turn, delay: const Duration(milliseconds: 250));
    if (b.won != null && a.won == null) s.play(b.won! ? Sfx.win : Sfx.lose, delay: const Duration(milliseconds: 400));
  }
  final calls = before == null ? const <Spoken>[] : spokenChoices(before, now);
  if (calls.isNotEmpty) s.speak(calls.last.clips, calls.last.text);
}

/// One call to speak: the recorded clips (assets/voice) and the same words as text,
/// for the phone's voice when a clip is missing.
class Spoken {
  const Spoken(this.text, this.clips);
  final String text;
  final List<String> clips;
  @override
  String toString() => '$text $clips';
}

String _suitClip(String suit) => 'suit_${suit.toLowerCase()}';

/// The choices made between the two views, as calls to speak.
@visibleForTesting
List<Spoken> spokenChoices(RoomView before, RoomView now) {
  final out = <Spoken>[];
  if ((before.game, now.game) case (final a?, final b?)) {
    for (final e in b.bidLog.skip(a.handNo == b.handNo ? a.bidLog.length : 0)) {
      out.add(e.bid == 'pass' ? const Spoken('باس', ['pass']) : Spoken(numberWordAr(e.bid as int), ['n${e.bid}']));
    }
    if (a.trump == null && b.trump != null && b.variant == 'tarneeb') {
      out.add(Spoken('الطرنيب ${suitNameArFromCode(b.trump!)}', ['trump', _suitClip(b.trump!)]));
    }
  }
  if ((before.trix, now.trix) case (final a?, final b?)) {
    if (b.contract != null && (a.contract != b.contract || a.handNo != b.handNo)) out.add(Spoken(contractNameAr(b.contract!), ['c_${b.contract}']));
    if (b.doubled.length > (a.handNo == b.handNo ? a.doubled.length : 0)) out.add(const Spoken('دبل', ['double']));
    // trix contract: a card laid on the suit columns
    if (b.contract == 'trix' && a.handNo == b.handNo && b.handCounts.fold(0, (x, y) => x + y) < a.handCounts.fold(0, (x, y) => x + y)) {
      Sound.instance.play(Sfx.place);
    }
  }
  if ((before.baloot, now.baloot) case (final a?, final b?)) {
    for (final e in b.bidLog.skip(a.handNo == b.handNo ? a.bidLog.length : 0)) {
      final word = balootCallAr(e.call, round: e.round);
      final clip = switch ((e.call, e.round)) {
        ('sun', _) => 'b_sun',
        ('ashkal', _) => 'b_ashkal',
        ('hokm', 2) => 'b_hokm2',
        ('hokm', _) => 'hokm',
        ('pass', 2) => 'b_pass2',
        _ => 'b_pass1',
      };
      out.add(e.call == 'hokm' && e.round == 2 && e.suit != null
          ? Spoken('$word ${suitNameArFromCode(e.suit!)}', [clip, _suitClip(e.suit!)])
          : Spoken(word, [clip]));
    }
    if (a.handNo == b.handNo) {
      if (b.level > a.level) {
        final step = const ['', '', 'double', 'triple', 'four'][b.level.clamp(0, 4)];
        out.add(Spoken(balootRaiseAr(step), [step == 'double' ? 'double' : 'b_$step']));
      }
      if (b.qahwa && !a.qahwa) out.add(const Spoken('قهوة', ['b_qahwa']));
    }
  }
  if ((before.b187, now.b187) case (final a?, final b?)) {
    for (final e in b.bidLog.skip(a.handNo == b.handNo ? a.bidLog.length : 0)) {
      out.add(e.isPass ? const Spoken('باس', ['pass']) : Spoken('${e.bid}', ['s${e.bid}']));
    }
    if (a.trump == null && b.trump != null) out.add(Spoken('الحكم ${suitNameArFromCode(b.trump!)}', ['hokm', _suitClip(b.trump!)]));
  }
  if ((before.hand, now.hand) case (final a?, final b?)) {
    if (a.handNo == b.handNo) {
      if (b.melds.length > a.melds.length) out.add(const Spoken('نزل', ['h_meld']));
      if (b.fireCount > a.fireCount) Sound.instance.play(Sfx.place);
      if (b.turn == b.mySeat && b.myHand.length == a.myHand.length + 1) Sound.instance.play(Sfx.deal);
    }
  }
  return out;
}
