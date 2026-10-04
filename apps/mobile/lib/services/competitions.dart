// المسابقات — knockout competitions players organise and play on real tables (apps/server/src/competitions.ts,
// where every rule on the «شروط المسابقات» page is enforced). This side keeps the numbers the screens show
// (CompRules, the same as the server's) and talks to the server; the screens poll while they are open.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'account.dart';
import 'api.dart';
import 'error_text.dart';

class CompGame {
  const CompGame(this.variant, this.name, {required this.partnership, this.targets = const []});
  final String variant;
  final String name;
  final bool partnership;

  /// The final scores a match may play to (one = fixed); empty when the game has none.
  final List<int> targets;

  /// Seats at one table: two teams in a partnership game, otherwise four players.
  int get tableSize => partnership ? 2 : 4;

  /// Seats that go through from each table before the final one: the winning team, or the first two players.
  int get advance => partnership ? 1 : 2;

  /// A solo game needs at least one full table.
  List<int> get seatOptions => partnership ? CompRules.seatOptions : CompRules.seatOptions.where((s) => s >= tableSize).toList();
}

/// The money and timing rules every competition follows (the server's COMP_RULES).
class CompRules {
  CompRules._();

  static const seatOptions = [2, 4, 8, 16, 32];
  static const fees = [0, 100, 250, 500, 1000];
  static const prizes = [500, 1000, 2000, 5000, 10000];

  /// Registration windows the organiser picks from (minutes).
  static const registrationMinutes = [10, 30, 60, 180, 1440];

  /// Charged to the organiser per seat when the competition is cancelled, and the minimum commission per seat.
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

CompPhase _phase(Object? s) => CompPhase.values.firstWhere((p) => p.name == s, orElse: () => CompPhase.registering);

class CompEntry {
  CompEntry(this.id, this.name, this.userIds);
  final String id;
  final String name;
  final List<String> userIds;
  static CompEntry of(Object? j) {
    final m = j as Map;
    return CompEntry(m['id'] as String, m['name'] as String, List<String>.from(m['userIds'] as List? ?? const []));
  }
}

class Complaint {
  Complaint({required this.from, required this.against, required this.type, required this.text, this.mine = false});
  final String from;
  final String against;
  final String type;
  final String text;
  final bool mine;
}

class Competition {
  Competition(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get title => j['title'] as String;
  CompGame get game => Competitions.gameOf(j['variant'] as String);
  int get seats => (j['seats'] as num).toInt();
  int get fee => (j['fee'] as num).toInt();
  int get prize => (j['prize'] as num).toInt();
  int get target => (j['target'] as num? ?? 0).toInt();
  Map? get _org => j['organiser'] as Map?;
  String get organiser => _org?['name'] as String? ?? '—';
  String? get organiserId => _org?['id'] as String?;
  int get organiserRating => (_org?['rating'] as num? ?? 0).toInt();
  bool get mine => j['mine'] == true;
  bool get autoAccept => j['autoAccept'] != false;
  DateTime get deadline => DateTime.fromMillisecondsSinceEpoch((j['deadline'] as num).toInt());
  CompPhase get phase => _phase(j['phase']);
  List<CompEntry> get entries => [for (final e in j['entrants'] as List) CompEntry.of(e)];
  List<String> get entrants => [for (final e in entries) e.name];
  List<CompEntry> get requests => [for (final e in j['requests'] as List? ?? const []) CompEntry.of(e)];
  int get requestCount => (j['requestCount'] as num? ?? 0).toInt();
  String? get myEntry => (j['myEntry'] as Map?)?['name'] as String?;
  String? get myEntryId => (j['myEntry'] as Map?)?['id'] as String?;
  String? get myRequest => (j['myRequest'] as Map?)?['name'] as String?;
  List<List<String?>> get rounds => [for (final r in j['rounds'] as List? ?? const []) List<String?>.from(r as List)];
  String? get myMatchRoom => (j['myMatch'] as Map?)?['room'] as String?;
  String? get winner => j['winner'] as String?;
  DateTime? get reviewEndsAt => j['reviewEndsAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['reviewEndsAt'] as num).toInt());
  List<Complaint> get complaints => [
        for (final k in j['complaints'] as List? ?? const [])
          Complaint(from: (k as Map)['from'] as String? ?? '—', against: k['against'] as String? ?? 'المنظم', type: k['type'] as String, text: k['text'] as String, mine: k['mine'] == true),
      ];
  Set<String> get clear => {for (final c in j['clear'] as List? ?? const []) if (c != null) c as String};
  String? get note => j['note'] as String?;
  List<Map<String, dynamic>> get barred => [for (final b in j['barred'] as List? ?? const []) Map<String, dynamic>.from(b as Map)];

  int get minToStart => CompRules.minToStart(seats);
  bool get full => entries.length >= seats;
  bool get joined => myEntry != null;
  bool get canStart => entries.length >= minToStart;
}

class Competitions extends ChangeNotifier {
  Competitions._();
  static final instance = Competitions._();

  /// Games whose competition rules are in.
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

  static CompGame gameOf(String variant) => games.firstWhere((g) => g.variant == variant, orElse: () => games.first);

  static const complaintTypes = ['غش', 'تخريب متعمّد', 'تواطؤ مع الخصم', 'إساءة في الدردشة', 'أخرى'];

  Future<List<Competition>> list([String? variant]) async =>
      [for (final c in await Api.instance.get('/competitions', {'variant': ?variant}) as List) Competition(Map<String, dynamic>.from(c as Map))];

  Future<Competition> get(String id) async => Competition(Map<String, dynamic>.from(await Api.instance.get('/competitions/$id') as Map));

  /// Runs one action; answers the competition as it is now, or the reason it was refused.
  Future<(Competition?, String?)> _act(String id, String action, [Object? body]) async {
    try {
      final r = await Api.instance.post('/competitions/$id/$action', body) as Map;
      Account.instance.apply(r['me']);
      notifyListeners();
      return (Competition(Map<String, dynamic>.from(r['competition'] as Map)), null);
    } on ApiError catch (e) {
      return (null, errorText(e.code));
    }
  }

  Future<(Competition?, String?)> create({
    required String title,
    required CompGame game,
    required int seats,
    required int fee,
    required int prize,
    required int target,
    required int minutes,
    required bool autoAccept,
  }) async {
    try {
      final r = await Api.instance.post('/competitions', {
        'title': title.trim(),
        'variant': game.variant,
        'seats': seats,
        'fee': fee,
        'prize': prize,
        'target': target,
        'minutes': minutes,
        'autoAccept': autoAccept,
        'agree': true,
      });
      await Account.instance.refresh();
      notifyListeners();
      return (Competition(Map<String, dynamic>.from(r as Map)), null);
    } on ApiError catch (e) {
      return (null, errorText(e.code));
    }
  }

  /// [partner] is the partner's player number in a partnership game.
  Future<(Competition?, String?)> join(Competition c, {String? partner}) => _act(c.id, 'join', {'partner': ?partner});
  Future<(Competition?, String?)> leave(Competition c) => _act(c.id, 'leave');
  Future<(Competition?, String?)> answer(Competition c, String entryId, bool accept) => _act(c.id, 'requests/$entryId', {'accept': accept});
  Future<(Competition?, String?)> acceptAll(Competition c) => _act(c.id, 'accept-all');
  Future<(Competition?, String?)> kick(Competition c, String entryId) => _act(c.id, 'kick/$entryId');
  Future<(Competition?, String?)> bar(Competition c, String ref, {bool bar = true}) => _act(c.id, 'bar', {'ref': ref, 'bar': bar});
  Future<(Competition?, String?)> startNow(Competition c) => _act(c.id, 'start');
  Future<(Competition?, String?)> cancel(Competition c) => _act(c.id, 'cancel');

  /// [against] is an entry id, or 'organiser'.
  Future<(Competition?, String?)> complain(Competition c, {required String against, required String type, required String text}) =>
      _act(c.id, 'complain', {'against': against, 'type': type, 'text': text});
  Future<(Competition?, String?)> noComplaints(Competition c) => _act(c.id, 'no-complaints');

  /// The organiser settles a frozen competition: 'confirm', 'winner' (with [winner], an entry id) or 'refund'.
  Future<(Competition?, String?)> settle(Competition c, String action, {String? winner}) => _act(c.id, 'settle', {'action': action, 'winner': ?winner});
  Future<(Competition?, String?)> appeal(Competition c, String text) => _act(c.id, 'appeal', {'text': text});
}
