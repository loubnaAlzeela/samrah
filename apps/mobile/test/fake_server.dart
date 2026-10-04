// A tiny stand-in for the game server's HTTP API, for widget tests: canned answers by method and path, and a log
// of the calls. Install with `FakeServer().install()`; routes not given answer 404 {error: notFound}.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/account.dart';
import 'package:mobile/services/api.dart';

typedef Handler = Object? Function(Map<String, dynamic> body, Uri uri);

Map<String, dynamic> meJson({String name = 'لبنى', int units = 9000, int stars = 400, bool vip = false, int level = 1, String? clubId}) => {
      'id': 'u1',
      'no': 100001,
      'name': name,
      'country': 'SA',
      'email': null,
      'hasPassword': false,
      'phone': null,
      'google': false,
      'units': units,
      'stars': stars,
      'vip': vip,
      'vipUntil': null,
      'owned': ['orange', 'cream'],
      'backId': 'orange',
      'tableId': 'cream',
      'giftTaken': false,
      'giftAmount': 100,
      'level': level,
      'xp': 40,
      'levelFrom': 0,
      'levelTo': 100,
      'stats': {'played': 2, 'won': 1, 'byVariant': {}, 'weekXp': 40},
      'settings': {
        'showOnline': true,
        'allowMessages': 'all',
        'allowGifts': true,
        'showInRanking': true,
        'notify': {'messages': true, 'clubs': true, 'competitions': true, 'gifts': true, 'challenges': true, 'system': true},
      },
      'blocked': [],
      'clubId': clubId,
      'compBanned': false,
      'sessions': 1,
      'createdAt': 1759500000000,
    };

class FakeServer {
  final Map<String, Handler> routes = {};
  final List<String> calls = [];

  void on(String method, String path, Handler h) => routes['$method $path'] = h;

  void install({Map<String, dynamic>? me}) {
    on('GET', '/me', (_, _) => me ?? meJson());
    on('GET', '/unread', (_, _) => {'messages': 0, 'notifications': 0});
    on('GET', '/config', (_, _) => {'clubs': {'createCost': 5000, 'unlockLevel': 1, 'maxModerators': 4}});
    Api.instance.client = MockClient((req) async {
      final path = req.url.path.replaceFirst(RegExp(r'^.*/api'), '');
      final key = '${req.method} $path';
      calls.add(key);
      final h = routes[key];
      if (h == null) return http.Response(jsonEncode({'error': 'notFound'}), 404, headers: {'content-type': 'application/json'});
      final body = req.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
      try {
        return http.Response.bytes(utf8.encode(jsonEncode(h(body, req.url))), 200, headers: {'content-type': 'application/json'});
      } on ApiError catch (e) {
        return http.Response(jsonEncode({'error': e.code}), e.status == 0 ? 400 : e.status, headers: {'content-type': 'application/json'});
      }
    });
    Account.instance.setForTest(me ?? meJson());
  }
}
