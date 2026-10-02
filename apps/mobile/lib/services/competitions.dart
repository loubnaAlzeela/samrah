// المسابقات — the competition rules and a DEMO of their life cycle, held in memory
// like the store (lib/services/store.dart). Other organisers and players are
// simulated: they ask to join, matches are decided at random, and they press «لا
// توجد لدي أي شكاوى». The money rules are the real ones (see CompRules); when the
// server gets accounts and tournaments they move there.
//
// Life cycle: registering → running → review (10 min) → finished, or frozen when a
// complaint is still open at the end of the review (the organiser settles it), or
// cancelled when registration closes with fewer than 75% of the seats taken.
//
// Seats: in a partnership game each seat is a team of two (the winning team's two
// players get half the prize each) and matches are team against team, knockout.
// Otherwise a seat is one player, tables are of four, the first two of each table
// go through, and the last table's winner takes the whole prize.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'store.dart';

class CompGame {
  const CompGame(this.variant, this.name, {required this.partnership, this.targets = const []});
  final String variant;
  final String name;
  final bool partnership;

  /// The final scores a match may play to (one = fixed); empty when the game has none.
  final List<int> targets;

  /// Seats at one table: two teams in a partnership game, otherwise four players.
  int get tableSize => partnership ? 2 : 4;

  /// Seats that go through from each table before the final one: the winning team,
  /// or the first two players.
  int get advance => partnership ? 1 : 2;

  /// A solo game needs at least one full table.
  List<int> get seatOptions => partnership ? CompRules.seatOptions : CompRules.seatOptions.where((s) => s >= tableSize).toList();
}

/// The money and timing rules every competition follows.
class CompRules {
  CompRules._();

  static const seatOptions = [2, 4, 8, 16, 32];

  /// Charged to the organiser per seat when the competition is cancelled, and the
  /// minimum commission per seat.
  static const perSeat = 300;
  static const reviewWindow = Duration(minutes: 10);

  /// 75% of the seats must be taken to start: 2→2, 4→3, 8→6, 16→12, 32→24.
  static int minToStart(int seats) => (seats * 3 / 4).ceil();

  /// The commission taken on creation: 10% of the prize or 300 per seat, whichever is larger.
  static int commission(int prize, int seats) => math.max((prize / 10).ceil(), perSeat * seats);

  /// What the organiser pays on creation: the prize plus the commission.
  static int creationCost(int prize, int seats) => prize + commission(prize, seats);

  static int cancelPenalty(int seats) => perSeat * seats;

  /// The organiser's share of the entry fees, paid when the competition finishes.
  static int organiserShare(int fee, int entrants) => (fee * entrants * 0.9).floor();

  /// What each player of the winning seat receives.
  static int prizePerPlayer(int prize, bool partnership) => partnership ? prize ~/ 2 : prize;
}

enum CompPhase { registering, running, review, frozen, finished, cancelled }

class Complaint {
  Complaint({required this.from, required this.against, required this.type, required this.text});
  final String from;
  final String against;
  final String type;
  final String text;
}

class Competition {
  Competition({
    required this.id,
    required this.title,
    required this.game,
    required this.seats,
    required this.fee,
    required this.prize,
    required this.organiser,
    required this.deadline,
    this.target = 41,
    this.mine = false,
    this.interest = 1,
  });

  final String id;
  final String title;
  final CompGame game;
  final int seats;
  final int fee;
  final int prize;
  final String organiser;
  final int target;

  /// Organised by the player.
  final bool mine;

  /// How keen the simulated players are to join (0..1).
  final double interest;

  /// Registration closes here: the competition starts, or is cancelled if short of players.
  DateTime deadline;

  CompPhase phase = CompPhase.registering;
  final List<String> entrants = [];

  /// Waiting for the organiser (only the player's own competitions keep a queue).
  final List<String> requests = [];

  /// The player's own seat, once accepted, and a request still waiting.
  String? myEntry;
  String? myRequest;
  int _requestAge = 0;

  /// Knockout rounds; null is an empty seat (a bye).
  final List<List<String?>> rounds = [];
  String? winner;
  DateTime? reviewEndsAt;
  final List<Complaint> complaints = [];

  /// Seats that pressed «لا توجد لدي أي شكاوى».
  final Set<String> clear = {};

  /// Why it was cancelled / how it was settled.
  String? note;
  int _ticks = 0;

  int get minToStart => CompRules.minToStart(seats);
  bool get full => entrants.length >= seats;
  bool get joined => myEntry != null;
  bool get canStart => entrants.length >= minToStart;
}

class Competitions extends ChangeNotifier {
  Competitions._() {
    _seed();
  }
  static final instance = Competitions._();

  /// Games whose competition rules are in (the rest arrive one by one).
  static const games = [
    CompGame('tarneeb', 'طرنيب', partnership: true, targets: [31, 41, 61]),
    CompGame('syrian41', 'طرنيب سوري 41', partnership: true, targets: [41]),
    CompGame('tarneeb400', '400', partnership: true, targets: [41]),
    CompGame('trix', 'تركس', partnership: false),
    CompGame('trixPartners', 'تركس شراكة', partnership: true),
    CompGame('trixComplex', 'تركس كمبلكس', partnership: false),
    CompGame('trixComplexPartners', 'تركس كمبلكس شراكة', partnership: true),
    CompGame('baloot', 'بلوت', partnership: true, targets: [152]),
  ];

  static const complaintTypes = ['غش', 'تخريب متعمّد', 'تواطؤ مع الخصم', 'إساءة في الدردشة', 'أخرى'];

  static const _names = [
    'سامر',
    'خالد',
    'ريم',
    'أبو علي',
    'نور',
    'هادي',
    'لين',
    'جود',
    'مازن',
    'رامي',
    'سلمى',
    'فادي',
    'يزن',
    'تالا',
    'كرم',
    'دانة',
    'عمر',
    'غيث',
    'رهف',
    'وسيم',
    'زين',
    'بشار',
    'هلا',
    'مجد',
  ];

  final _rng = math.Random();
  Timer? _timer;
  String me = 'أنت';
  final List<Competition> all = [];
  int _nextId = 1;

  /// Banned from organising (an unjust kick); not reachable in the demo yet.
  bool banned = false;

  Store get _store => Store.instance;

  /// Starts the clock that drives the simulation (idempotent).
  void wake(String playerName) {
    if (playerName.trim().isNotEmpty) me = playerName.trim();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  String _bot(CompGame g, Competition c) {
    for (var tries = 0; tries < 40; tries++) {
      final a = _names[_rng.nextInt(_names.length)];
      final name = g.partnership ? '$a و ${_names[_rng.nextInt(_names.length)]}' : a;
      if (g.partnership && name.split(' و ').toSet().length < 2) continue;
      if (!c.entrants.contains(name) && !c.requests.contains(name)) return name;
    }
    return '${_names[_rng.nextInt(_names.length)]} ${_rng.nextInt(90) + 10}';
  }

  static CompGame _game(String variant) => games.firstWhere((g) => g.variant == variant);

  void _seed() {
    final now = DateTime.now();
    Competition make(String title, int seats, int fee, int prize, String org, int minutes, int prefill, double interest, {int target = 41, CompGame? game}) {
      final g = game ?? games.first;
      final c = Competition(
        id: 'c${_nextId++}',
        title: title,
        game: g,
        seats: seats,
        fee: fee,
        prize: prize,
        organiser: org,
        deadline: now.add(Duration(minutes: minutes)),
        interest: interest,
        target: target,
      );
      for (var i = 0; i < prefill; i++) {
        c.entrants.add(_bot(g, c));
      }
      return c;
    }

    all.addAll([
      make('مسابقة سريعة', 4, 0, 1000, 'أبو علي', 2, 2, 0.5, target: 31),
      make('بطولة الخميس', 8, 200, 3000, 'سامر', 4, 4, 0.6),
      make('تحدي المحترفين', 16, 500, 10000, 'ريم', 6, 9, 0.5, target: 61),
      make('ليلة الطرنيب الكبرى', 32, 100, 6000, 'مازن', 5, 8, 0.25),
      make('دوري الـ41', 8, 150, 2500, 'هادي', 3, 3, 0.6, game: _game('syrian41')),
      make('ممالك التركس', 16, 100, 3000, 'لين', 4, 7, 0.6, game: _game('trix')),
      make('صكّة الجمعة', 8, 200, 4000, 'فادي', 3, 4, 0.6, target: 152, game: _game('baloot')),
    ]);

    // one already over, to show how a finished competition reads
    final done = make('كأس الأسبوع الماضي', 8, 100, 2000, 'نور', 0, 8, 0);
    done.rounds.add(List<String?>.of(done.entrants));
    while (done.rounds.last.length > 1) {
      done.rounds.add(_nextRound(done.rounds.last, done.game));
    }
    done.winner = done.rounds.last.single;
    done.phase = CompPhase.finished;
    done.clear.addAll(done.entrants);
    all.add(done);
  }

  // ── the player's actions ────────────────────────────────────────────────────

  /// Asks to join, paying the entry fee now (refunded if refused or cancelled).
  /// Returns an error to show, or null.
  String? join(Competition c, {String? partner}) {
    if (c.phase != CompPhase.registering) return 'التسجيل مغلق';
    if (c.joined || c.myRequest != null) return 'أنت مسجّل بالفعل';
    if (c.full) return 'المقاعد ممتلئة';
    if (!_store.spend(c.fee)) return 'رصيد الوحدات لا يكفي لرسوم الاشتراك';
    final entry = c.game.partnership ? '$me و ${(partner ?? '').trim().isEmpty ? 'شريكي' : partner!.trim()}' : me;
    if (c.mine) {
      // the organiser seats themselves at once
      c.entrants.add(entry);
      c.myEntry = entry;
    } else {
      c.myRequest = entry;
      c._requestAge = 0;
    }
    notifyListeners();
    return null;
  }

  /// Leaves before the start; the entry fee comes back.
  void leave(Competition c) {
    if (c.phase != CompPhase.registering) return;
    if (c.myRequest != null) {
      c.myRequest = null;
    } else if (c.myEntry != null) {
      c.entrants.remove(c.myEntry);
      c.myEntry = null;
    } else {
      return;
    }
    _store.earn(c.fee);
    notifyListeners();
  }

  /// Creates a competition the player organises. Members only; the prize and the
  /// commission are taken now. Returns an error to show, or the new competition.
  (Competition?, String?) create({required String title, required CompGame game, required int seats, required int fee, required int prize, required int target}) {
    if (!_store.vip) return (null, 'إنشاء المسابقات للأعضاء الذهبيين فقط');
    if (banned) return (null, 'حسابك محظور من تنظيم المسابقات');
    final cost = CompRules.creationCost(prize, seats);
    if (!_store.spend(cost)) return (null, 'رصيد الوحدات لا يكفي: تحتاج $cost وحدة');
    final c = Competition(
      id: 'c${_nextId++}',
      title: title.trim().isEmpty ? 'مسابقة ${game.name}' : title.trim(),
      game: game,
      seats: seats,
      fee: fee,
      prize: prize,
      organiser: me,
      mine: true,
      target: target,
      deadline: DateTime.now().add(const Duration(minutes: 5)),
      interest: 0.8,
    );
    all.insert(0, c);
    notifyListeners();
    return (c, null);
  }

  void accept(Competition c, String who) {
    if (!c.mine || c.phase != CompPhase.registering || c.full) return;
    if (c.requests.remove(who)) c.entrants.add(who);
    notifyListeners();
  }

  void acceptAll(Competition c) {
    while (c.requests.isNotEmpty && !c.full) {
      c.entrants.add(c.requests.removeAt(0));
    }
    notifyListeners();
  }

  /// Refuses a request; the player gets the entry fee back.
  void reject(Competition c, String who) {
    c.requests.remove(who);
    notifyListeners();
  }

  /// The organiser starts early, once 75% of the seats are taken.
  void startNow(Competition c) {
    if (c.mine && c.phase == CompPhase.registering && c.canStart) _start(c);
  }

  /// The organiser calls it off before the start: same as running out of time short of players.
  void cancel(Competition c) {
    if (c.mine && c.phase == CompPhase.registering) _cancel(c, 'ألغاها المنظم قبل البدء');
  }

  /// A complaint during the review. The explanation must say something real.
  String? complain(Competition c, {required String against, required String type, required String text}) {
    if (c.phase != CompPhase.review) return 'فترة الشكاوى انتهت';
    final entry = c.myEntry;
    if (entry == null) return 'الشكاوى للمشاركين في المسابقة فقط';
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.length > 1).length;
    if (words < 4) return 'اشرح الشكوى بجملة واضحة (أربع كلمات على الأقل)';
    c.complaints.add(Complaint(from: entry, against: against, type: type, text: text.trim()));
    c.clear.remove(entry);
    notifyListeners();
    return null;
  }

  /// «لا توجد لدي أي شكاوى» — also withdraws the player's own complaints.
  void noComplaints(Competition c) {
    final entry = c.myEntry;
    if (c.phase != CompPhase.review || entry == null) return;
    c.complaints.removeWhere((k) => k.from == entry);
    c.clear.add(entry);
    _maybeCloseReview(c);
    notifyListeners();
  }

  /// The organiser settles a frozen competition: keep the result and pay out.
  void confirmResult(Competition c) {
    if (!c.mine || c.phase != CompPhase.frozen) return;
    c.note = 'راجع المنظم الشكاوى واعتمد النتيجة';
    _finish(c);
  }

  /// The organiser settles a frozen competition by refunding every entry fee; the
  /// prize goes back to the organiser and no one wins.
  void refundAll(Competition c) {
    if (!c.mine || c.phase != CompPhase.frozen) return;
    if (c.myEntry != null) _store.earn(c.fee);
    _store.earn(c.prize);
    c.winner = null;
    c.phase = CompPhase.finished;
    c.note = 'أعاد المنظم رسوم الاشتراك لكل اللاعبين وأُلغيت النتيجة';
    notifyListeners();
  }

  // ── the clock ───────────────────────────────────────────────────────────────

  void _tick() {
    final now = DateTime.now();
    var changed = false;
    for (final c in all) {
      c._ticks++;
      switch (c.phase) {
        case CompPhase.registering:
          changed = true; // the countdown moves
          _registering(c, now);
        case CompPhase.running:
          if (c._ticks % 3 == 0) {
            _advance(c);
            changed = true;
          }
        case CompPhase.review:
          changed = true;
          _review(c, now);
        case CompPhase.frozen:
          // another organiser settles in time; the player's own competitions wait for them
          if (!c.mine && c._ticks > 25) {
            c.note = 'راجع المنظم الشكاوى واعتمد النتيجة';
            _finish(c);
            changed = true;
          }
        case CompPhase.finished:
        case CompPhase.cancelled:
          break;
      }
    }
    if (changed) notifyListeners();
  }

  void _registering(Competition c, DateTime now) {
    // the player's request to someone else's competition is accepted after a moment
    if (c.myRequest != null && ++c._requestAge >= 2) {
      if (c.full) {
        _store.earn(c.fee);
        c.myRequest = null;
      } else {
        c.entrants.add(c.myRequest!);
        c.myEntry = c.myRequest;
        c.myRequest = null;
      }
    }
    final waiting = c.entrants.length + c.requests.length + (c.myRequest != null ? 1 : 0);
    if (waiting < c.seats && _rng.nextDouble() < c.interest * 0.35) {
      final bot = _bot(c.game, c);
      c.mine ? c.requests.add(bot) : c.entrants.add(bot);
    }
    if (!c.mine && c.full && c.myRequest == null) {
      _start(c);
    } else if (!now.isBefore(c.deadline)) {
      c.canStart ? _start(c) : _cancel(c, 'لم يكتمل الحد الأدنى من اللاعبين (${c.minToStart} من ${c.seats}) قبل موعد البدء');
    }
  }

  void _start(Competition c) {
    // unanswered requests are turned away
    c.requests.clear();
    if (c.myRequest != null) {
      _store.earn(c.fee);
      c.myRequest = null;
    }
    final slots = List<String?>.of(c.entrants)..shuffle(_rng);
    while (slots.length < c.seats) {
      slots.insert(_rng.nextInt(slots.length + 1), null);
    }
    c.rounds.add(slots);
    c.phase = CompPhase.running;
    c._ticks = 0;
  }

  /// The next round: each table sends on its winners (the final table only one).
  /// A seat that went through without an opponent is a bye; empty seats stay null.
  List<String?> _nextRound(List<String?> r, CompGame g) {
    final keep = r.length <= g.tableSize ? 1 : g.advance;
    final out = <String?>[];
    for (var i = 0; i < r.length; i += g.tableSize) {
      final present = r.sublist(i, math.min(i + g.tableSize, r.length)).whereType<String>().toList()..shuffle(_rng);
      for (var k = 0; k < keep; k++) {
        out.add(k < present.length ? present[k] : null);
      }
    }
    return out;
  }

  void _advance(Competition c) {
    final next = _nextRound(c.rounds.last, c.game);
    c.rounds.add(next);
    if (next.length == 1) {
      c.winner = next.single;
      c.phase = CompPhase.review;
      c.reviewEndsAt = DateTime.now().add(CompRules.reviewWindow);
    }
  }

  void _review(Competition c, DateTime now) {
    // the simulated players have nothing to report
    for (final e in c.entrants) {
      if (e != c.myEntry && !c.clear.contains(e) && _rng.nextDouble() < 0.15) c.clear.add(e);
    }
    if (_maybeCloseReview(c)) return;
    if (!now.isBefore(c.reviewEndsAt!)) {
      if (c.complaints.isEmpty) {
        _finish(c);
      } else {
        c.phase = CompPhase.frozen;
        c._ticks = 0;
      }
    }
  }

  /// Everyone said «لا توجد لدي أي شكاوى»: no need to wait out the ten minutes.
  bool _maybeCloseReview(Competition c) {
    if (c.complaints.isEmpty && c.entrants.every(c.clear.contains)) {
      _finish(c);
      return true;
    }
    return false;
  }

  void _finish(Competition c) {
    c.phase = CompPhase.finished;
    if (c.winner != null && c.winner == c.myEntry) _store.earn(CompRules.prizePerPlayer(c.prize, c.game.partnership));
    if (c.mine) _store.earn(CompRules.organiserShare(c.fee, c.entrants.length));
    notifyListeners();
  }

  void _cancel(Competition c, String why) {
    c.phase = CompPhase.cancelled;
    c.note = why;
    c.requests.clear();
    if (c.myEntry != null || c.myRequest != null) _store.earn(c.fee);
    c.myRequest = null;
    if (c.mine) {
      final held = CompRules.creationCost(c.prize, c.seats);
      _store.earn(held - CompRules.cancelPenalty(c.seats));
    }
  }
}
