// Game audio: short effects that follow the motion (a card thrown, the deal,
// a trick gathered, your turn…) and a spoken word for every choice a player
// makes (a bid, «باس», «صن», «دبل», a Trix contract…), like a dealer calling
// the table. Effects are WAVs synthesised by tool/make_sounds.py (no recorded
// samples). Spoken calls are recorded clips in assets/voice (a Saudi voice,
// tool/make_voice.py, list in docs/voice-lines.md); a call with no clip falls
// back to the phone's own Arabic text-to-speech voice.
//
// How it stays reliable on Android:
//  - every sound has its OWN players, loaded once at start-up ([warmUp]) and never
//    switched to another file (reloading a low-latency player is when sounds go silent);
//  - every player mixes with the others instead of taking the audio focus, so one
//    sound never cuts another off;
//  - a call made of several clips («الطرنيب» + «هاص») chains them by their known
//    length (voice_clips.dart), never by waiting for a "completed" event.
//
// Every call is fire-and-forget and never throws: sound is a nicety, a device
// without audio (or `flutter test`) must play the game exactly the same.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_clips.dart';

enum Sfx { cardThrow, deal, collect, place, turn, tap, tick, win, lose }

/// A few players preloaded with one file; they take turns so rapid repeats overlap.
class _Channel {
  _Channel(this.players);
  final List<AudioPlayer> players;
  int _next = 0;

  Future<void> fire(double volume) async {
    final p = players[_next++ % players.length];
    await p.stop();
    await p.setVolume(volume);
    await p.resume();
  }

  Future<void> stop() async {
    for (final p in players) {
      await p.stop();
    }
  }
}

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

  /// players per effect: the deal and card throws come in quick bursts
  static const _voices = {Sfx.deal: 4, Sfx.cardThrow: 3, Sfx.tap: 2, Sfx.place: 2};

  final Map<Sfx, _Channel> _sfx = {};
  final Map<String, _Channel> _clips = {};
  Future<void>? _warming;
  FlutterTts? _tts;
  DateTime _lastDeal = DateTime.fromMillisecondsSinceEpoch(0);

  /// Clips in assets/voice (file name without .mp3), see docs/voice-lines.md.
  static Set<String> get voiceClips => voiceClipMs.keys.toSet();

  /// Silence the app whenever it leaves the screen, and let it speak again on return.
  /// Call once from main().
  void watchAppLifecycle() => WidgetsBinding.instance.addObserver(_Lifecycle(this));

  /// Load every effect and every voice clip into its own players, once (call at start-up;
  /// takes a moment, meanwhile sounds are simply skipped).
  Future<void> warmUp() => _warming ??= _load();

  Future<void> _load() async {
    if (_underTest) return;
    try {
      // mix with each other (and other apps) instead of grabbing the audio focus
      final ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      await AudioPlayer.global.setAudioContext(ctx);
      Future<_Channel> channel(String path, int n) async => _Channel([
            for (var i = 0; i < n; i++)
              await () async {
                final p = AudioPlayer();
                await p.setPlayerMode(PlayerMode.lowLatency);
                await p.setAudioContext(ctx);
                await p.setReleaseMode(ReleaseMode.stop);
                await p.setSource(AssetSource(path));
                return p;
              }(),
          ]);
      for (final s in Sfx.values) {
        _sfx[s] = await channel('sounds/${_files[s]}.wav', _voices[s] ?? 1);
      }
      for (final c in voiceClipMs.keys) {
        _clips[c] = await channel('voice/$c.mp3', 1);
      }
    } catch (_) {
      // no audio on this device: the game plays silently
    }
  }

  /// Stop everything now: the voice mid-word, effects playing, effects still scheduled.
  /// Called when the player leaves a table and when the app goes to the background.
  void stopAll() {
    _generation++;
    _line++;
    try {
      unawaited(_tts?.stop().catchError((_) => null));
      unawaited(_speaking?.stop().catchError((_) {}));
      _speaking = null;
    } catch (_) {}
  }

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
    final ch = _sfx[s];
    if (ch == null) {
      unawaited(warmUp());
      return;
    }
    unawaited(ch.fire(_volume[s] ?? 1.0).catchError((_) {}));
  }

  /// A quick run of deal flicks, one per card, following the deal animation.
  void dealRun(int cards) {
    for (var i = 0; i < cards.clamp(0, 16); i++) {
      play(Sfx.deal, delay: Duration(milliseconds: 45 * i + 20));
    }
  }

  /// bumped by every new call: a sequence still playing stops before its next clip
  int _line = 0;
  _Channel? _speaking;

  /// Speak a call: its recorded clips one after another when all exist, else [text]
  /// with the phone's voice. The latest call replaces one still being spoken.
  void speak(List<String> clips, String text) {
    if (!voice || _underTest || !_foreground) return;
    if (clips.isEmpty || !clips.every(voiceClipMs.containsKey)) {
      say(text);
      return;
    }
    if (clips.any((c) => _clips[c] == null)) {
      // clips still loading (the first seconds after start-up): the phone's voice instead
      unawaited(warmUp());
      say(text);
      return;
    }
    final line = ++_line;
    unawaited(_speaking?.stop().catchError((_) {}));
    _chain(clips, 0, line);
  }

  void _chain(List<String> clips, int i, int line) {
    if (i >= clips.length || line != _line || !_foreground) return;
    final ch = _clips[clips[i]]!;
    _speaking = ch;
    unawaited(ch.fire(1.0).catchError((_) {}));
    // the next clip starts when this one ends (plus a breath)
    Timer(Duration(milliseconds: voiceClipMs[clips[i]]! + 60), () => _chain(clips, i + 1, line));
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
