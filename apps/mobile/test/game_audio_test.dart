// Every player's choice is spoken: bids and «باس», the trump, a Trix
// contract, Baloot calls. Built from two consecutive server views.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/room_view.dart';
import 'package:mobile/services/game_audio.dart';
import 'package:mobile/services/sound.dart';

RoomView tarneeb(List<Map<String, Object>> bids, {String? trump}) => RoomView.fromJson({
      'code': 'A',
      'variant': 'tarneeb',
      'target': 41,
      'status': 'playing',
      'seats': [null, null, null, null],
      'mySeat': 0,
      'isOwner': false,
      'ownerSeat': null,
      'pending': false,
      'turnDeadline': null,
      'serverNow': 0,
      'game': {
        'variant': 'tarneeb',
        'target': 41,
        'phase': trump == null ? 'bidding' : 'playing',
        'handNo': 1,
        'dealer': 3,
        'turn': 1,
        'mySeat': 0,
        'myHand': ['S14'],
        'legal': [],
        'minBid': null,
        'handCounts': [13, 13, 13, 13],
        'bidLog': bids,
        'passed': [false, false, false, false],
        'highBid': null,
        'seatBids': [null, null, null, null],
        'trump': trump,
        'revealed': null,
        'trick': [],
        'lastTrick': null,
        'tricks': [0, 0, 0, 0],
        'teamScores': [0, 0],
        'seatScores': [0, 0, 0, 0],
        'lastResult': null,
        'winner': null,
      },
    });

void main() {
  test('tarneeb: bids and passes by number word, then the trump', () {
    final a = tarneeb([]);
    final b = tarneeb([
      {'seat': 0, 'bid': 8},
      {'seat': 1, 'bid': 'pass'},
    ]);
    expect(spokenChoices(a, b).map((s) => s.text), ['ثمانية', 'باس']);
    expect(spokenChoices(a, b).map((s) => s.clips), [
      ['n8'],
      ['pass'],
    ]);
    final trump = spokenChoices(b, tarneeb([{'seat': 0, 'bid': 8}], trump: 'H')).single;
    expect(trump.text, 'الطرنيب قلب');
    expect(trump.clips, ['trump', 'suit_h']);
  });

  test('every clip a call can name exists in assets/voice', () {
    for (final c in Sound.voiceClips) {
      expect(File('assets/voice/$c.mp3').existsSync(), isTrue, reason: c);
    }
  });
}
