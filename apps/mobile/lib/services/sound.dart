// Game audio: short effects that follow the motion (a card thrown, the deal,
// a trick gathered, your turn…) and a spoken word for every choice a player
// makes (a bid, «باس», «صن», «دبل», a Trix contract…), like a dealer calling
// the table. Effects are WAVs synthesised by tool/make_sounds.py (no recorded
// samples). Spoken calls are recorded clips in assets/voice (a Saudi voice,
// tool/make_voice.py, list in docs/voice-lines.md); a call with no clip falls
// back to the phone's own Arabic text-to-speech voice.
//
// Every call is fire-and-forget and never throws: sound is a nicety, a device
// without audio (or `flutter test`) must play the game exactly the same.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum Sfx { cardThrow, deal, collect, place, turn, tap, tick, win, lose }

class Sound {
  Sound._();
  static final Sound instance = Sound._();

  /// effects on / off (the ≡ menu at the table)
  bool effects = true;

  /// spoken choices on / off
  bool voice = true;

  static final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

  /// false while the app is in the background: nothing plays or speaks then
  /// (a table left open keeps receiving the computers' moves)
  bool _foreground = true;

  /// bumped by [stopAll]: sounds scheduled before it (a delayed effect) are dropped
  int _generation = 0;

  /// Silence the app whenever it leaves the screen, and let it speak again on return.
  /// Call once from main().
  void watchAppLifecycle() => WidgetsBinding.instance.addObserver(_Lifecycle(this));

  /// Stop everything now: the voice mid-word, effects playing, effects still scheduled.
  /// Called when the player leaves a table and when the app goes to the background.
  void stopAll() {
    _generation++;
    _line++;
    try {
      unawaited(_tts?.stop().catchError((_) => null));
      unawaited(_voicePlayer?.stop().catchError((_) {}));
      for (final p in _pool) {
        unawaited(p.stop().catchError((_) {}));
      }
    } catch (_) {}
  }

  static const _files = {
    Sfx.cardThrow: 'card_throw',
    Sfx.deal: 'deal',
    Sfx.collect: 'collect',
    Sfx.place: 'place',
    Sfx.turn: 'turn',
    Sfx.tap: 'tap',
    Sfx.tick: 'tick',
    Sfx.win: 'win',
    Sfx.lose: 'lose',
  };
  static const _volume = {Sfx.tap: 0.5, Sfx.deal: 0.7, Sfx.tick: 0.6};

  // a few players so overlapping effects (four cards in quick succession) do not cut each other off
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  FlutterTts? _tts;
  DateTime _lastDeal = DateTime.fromMillisecondsSinceEpoch(0);

  /// Play an effect now, or after [delay] (to land with an animation).
  void play(Sfx s, {Duration delay = Duration.zero}) {
    if (!effects || _underTest || !_foreground) return;
    if (delay > Duration.zero) {
      final gen = _generation;
      Timer(delay, () {
        if (gen == _generation) play(s);
      });
      return;
    }
    // many cards dealt at once would stack up: one flick per 60 ms is enough
    if (s == Sfx.deal) {
      final now = DateTime.now();
      if (now.difference(_lastDeal).inMilliseconds < 60) return;
      _lastDeal = now;
    }
    try {
      if (_pool.length < 5) {
        final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        unawaited(p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {}));
        _pool.add(p);
      }
      final p = _pool[_next++ % _pool.length];
      unawaited(p.play(AssetSource('sounds/${_files[s]}.wav'), volume: _volume[s] ?? 1.0).catchError((_) {}));
    } catch (_) {}
  }

  /// A quick run of deal flicks, one per card, following the deal animation.
  void dealRun(int cards) {
    for (var i = 0; i < cards.clamp(0, 16); i++) {
      play(Sfx.deal, delay: Duration(milliseconds: 45 * i + 20));
    }
  }

  /// Clips in assets/voice (file name without .mp3), see docs/voice-lines.md.
  static const voiceClips = {
    'n2', 'n3', 'n4', 'n5', 'n6', 'n7', 'n8', 'n9', 'n10', 'n11', 'n12', 'n13', //
    'pass', 'double', 'trump', 'hokm', 'suit_h', 'suit_d', 'suit_s', 'suit_c', //
    'c_king', 'c_queens', 'c_diamonds', 'c_tricks', 'c_trix', //
    'b_sun', 'b_hokm2', 'b_ashkal', 'b_pass1', 'b_pass2', 'b_triple', 'b_four', 'b_qahwa', //
    's87', 's90', 's95', 's100', 's105', 's110', 's115', 's120', 's125', 's130', 's135', 's140', 's145', //
    's150', 's155', 's160', 's165', 's170', 's175', 's180', 's185', 's187', 'h_meld',
  };

  AudioPlayer? _voicePlayer;

  /// bumped by every new call: a sequence still playing stops at its next clip
  int _line = 0;

  /// Speak a call: its recorded clips one after another when all exist, else [text]
  /// with the phone's voice. The latest call replaces one still being spoken.
  void speak(List<String> clips, String text) {
    if (!voice || _underTest || !_foreground) return;
    if (clips.isEmpty || !clips.every(voiceClips.contains)) {
      say(text);
      return;
    }
    unawaited(_playClips(clips, ++_line));
  }

  Future<void> _playClips(List<String> clips, int line) async {
    try {
      final p = _voicePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      for (final c in clips) {
        if (line != _line) return;
        final done = p.onPlayerComplete.first;
        await p.play(AssetSource('voice/$c.mp3'));
        await done.timeout(const Duration(seconds: 3), onTimeout: () {});
      }
    } catch (_) {}
  }

  /// Say a word or two with the phone's voice (the latest call replaces one still being spoken).
  void say(String text) {
    if (!voice || _underTest || !_foreground || text.trim().isEmpty) return;
    try {
      final tts = _tts ??= _initTts();
      unawaited(tts.stop().then((_) => tts.speak(text)).catchError((_) => null));
    } catch (_) {}
  }

  FlutterTts _initTts() {
    final t = FlutterTts();
    unawaited(t.setLanguage('ar').catchError((_) => null));
    unawaited(t.setSpeechRate(0.5).catchError((_) => null));
    unawaited(t.setPitch(1.0).catchError((_) => null));
    unawaited(t.setVolume(1.0).catchError((_) => null));
    return t;
  }
}

class _Lifecycle with WidgetsBindingObserver {
  _Lifecycle(this.sound);
  final Sound sound;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (!visible && sound._foreground) sound.stopAll();
    sound._foreground = visible;
  }
}

/// Arabic words for the small numbers the games call out (bids 2..13).
String numberWordAr(int n) => const {
      1: 'واحد',
      2: 'اثنين',
      3: 'ثلاثة',
      4: 'أربعة',
      5: 'خمسة',
      6: 'ستة',
      7: 'سبعة',
      8: 'ثمانية',
      9: 'تسعة',
      10: 'عشرة',
      11: 'أحد عشر',
      12: 'اثنا عشر',
      13: 'ثلاثة عشر',
    }[n] ??
    '$n';
