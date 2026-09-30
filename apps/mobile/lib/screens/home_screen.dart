// Home screen — matches design/layout-v3.md §1/§2/§8: header (stars ·
// profile · coins), game picker, the three mode cards, and the
// bottom nav. Icons use Material's outline set as a pragmatic stand-in for
// the spec's custom line icons (no Jawaker art either way).
//
// Wallets ("وحدات" / "نجوم"), levels, store, clubs and challenges are
// DISPLAY ONLY — no backend yet (see layout-v3.md §10). Real gameplay
// (bidding, trump, play) is fully wired; only "إنشاء لعبة" and "لعبة ودية"
// lead somewhere real right now.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/mode_wheel.dart';
import 'games_screen.dart';
import 'new_game_sheet.dart';
import 'placeholder_screen.dart';
import 'room_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import '../widgets/motion.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.playerName});
  final String playerName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _warmTimer;
  final int _navIndex = 2; // الرئيسية

  /// Games the picker cycles through: (wire variant, name, description).
  static const _games = [
    ('tarneeb', 'طرنيب', '4 لاعبين · فريقين'),
    ('syrian41', 'طرنيب سوري 41', '4 لاعبين · كل لاعب يطلب لنفسه'),
    ('trix', 'تركس', '4 لاعبين · كل لاعب لنفسه'),
    ('trixPartners', 'تركس شراكة', '4 لاعبين · فريقين'),
    ('b187', 'لعبة 187', '4 أو 5 لاعبين · بيع وشراء'),
    ('baloot', 'بلوت', '4 لاعبين · فريقين'),
    ('hand', 'هاند سعودي', 'من 2 إلى 5 لاعبين'),
  ];
  int _gameIndex = 0;
  String get _variant => _games[_gameIndex].$1;

  void _stepGame(int d) => setState(() => _gameIndex = (_gameIndex + d) % _games.length);

  @override
  void initState() {
    super.initState();
    // connect to the game server now, while the player picks a game, so a table opens at once
    unawaited(gameServer.warmUp());
    // keeps the connection warm while the player browses (throttled inside warmUp)
    _warmTimer = Timer.periodic(const Duration(seconds: 10), (_) => unawaited(gameServer.warmUp()));
  }

  @override
  void dispose() {
    _warmTimer?.cancel();
    super.dispose();
  }

  void _openRoomFlow({required bool auto, Map<String, Object?>? settings}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(initialName: widget.playerName, autoOpen: auto, variant: _variant, settings: settings),
      ),
    );
  }

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — قريباً'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final trimmedName = widget.playerName.trim();
    final letter = trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : '؟';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EnterFrom(child: _header(letter)),
              const SizedBox(height: 24),
              EnterFrom(delay: Motion.stagger(1, stepMs: 80), child: _gamePicker()),
              const SizedBox(height: 20),
              EnterFrom(delay: Motion.stagger(2, stepMs: 80), child: _modeCards()),
              const SizedBox(height: 20),
              EnterFrom(delay: Motion.stagger(3, stepMs: 80), child: _rulesRankInvite()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(index: _navIndex, onTap: _onNav),
    );
  }

  void _onNav(int i) {
    if (i == 2) return; // already home
    if (i == 1) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GamesScreen(playerName: widget.playerName)));
      return;
    }
    final labels = ['المتجر', '', '', 'الأندية', 'التحديات'];
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: labels[i])));
  }

  Widget _header(String letter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // right edge: the wallets, one above the other (same width)
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _wallet(icon: Icons.star, label: 'نجوم', value: 0),
                const SizedBox(height: 8),
                _wallet(icon: Icons.circle, label: 'وحدات', value: 0),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // the player, centred and given the room
          Expanded(child: _profileCapsule(letter)),
          const SizedBox(width: 10),
          // left edge: messages and notifications
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerIcon(Icons.chat_bubble_outline, 'الرسائل', () => _push(const PlaceholderScreen(title: 'الرسائل'))),
              _headerIcon(Icons.notifications_none, 'التنبيهات', () => _push(const PlaceholderScreen(title: 'التنبيهات'))),
            ],
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Widget _headerIcon(IconData icon, String tooltip, VoidCallback onTap) => SizedBox(
        width: 38,
        height: 36,
        child: IconButton(padding: EdgeInsets.zero, tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: SamrahColors.text, size: 24)),
      );

  Widget _profileCapsule(String letter) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: SamrahColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: SamrahColors.surface3,
            child: Text(letter, style: GoogleFonts.cairo(color: SamrahColors.text, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(color: SamrahColors.text, fontWeight: FontWeight.w700, fontSize: 16, height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // level badge, then progress to the next level
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: SamrahColors.accent, shape: BoxShape.circle),
                      child: const Text('1', style: TextStyle(color: SamrahColors.onAccent, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(value: 0, minHeight: 6, backgroundColor: SamrahColors.scorebox, color: SamrahColors.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('0%', style: TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // settings live with the player
          _headerIcon(Icons.settings_outlined, 'الإعدادات', () => _push(SettingsScreen(playerName: widget.playerName))),
        ],
      ),
    );
  }

  Widget _wallet({required IconData icon, required String label, required int value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SamrahColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: SamrahColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SamrahColors.onTableAccent),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 12, color: SamrahColors.text),
          ),
        ],
      ),
    );
  }

  Widget _gamePicker() {
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // small fanned card silhouette, well clear of the text below it
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (i, r) in [(-1, -18.0), (0, 0.0), (1, 18.0)])
                  Transform.rotate(
                    angle: r * 3.14159 / 180,
                    child: Transform.translate(
                      offset: Offset(i * 14.0, i == 0 ? -4 : 2),
                      child: Container(
                        width: 32,
                        height: 46,
                        decoration: BoxDecoration(
                          color: SamrahColors.cardFace,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: SamrahColors.cardEdge),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _games[_gameIndex].$2,
                  style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.w700, color: SamrahColors.text),
                ),
                const SizedBox(height: 4),
                Text(_games[_gameIndex].$3, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _games.length; i++)
                      Container(
                        width: i == _gameIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: i == _gameIndex ? SamrahColors.text : SamrahColors.line, borderRadius: BorderRadius.circular(3)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(right: 8, top: 46, child: _arrow(Icons.chevron_right, () => _stepGame(1))),
          Positioned(left: 8, top: 46, child: _arrow(Icons.chevron_left, () => _stepGame(_games.length - 1))),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: SamrahColors.icon),
      ),
    );
  }

  Widget _modeCards() {
    return ModeWheel(
      initial: 1, // «لعبة ودية» in front
      items: [
        ModeItem(icon: Icons.add_rounded, title: 'إنشاء لعبة', action: 'إنشاء', onTap: _openNewGameSheet),
        ModeItem(icon: Icons.play_arrow_rounded, title: 'لعبة ودية', action: 'العب الآن', onTap: () => _openRoomFlow(auto: true)),
        ModeItem(icon: Icons.public, title: 'الألعاب العامة', action: 'عرض الألعاب', onTap: () => _soon('الألعاب العامة')),
      ],
    );
  }

  void _openNewGameSheet() {
    showModalBottomSheet<Map<String, Object?>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NewGameSheet(variant: _variant),
    ).then((settings) {
      if (settings != null) _openRoomFlow(auto: true, settings: settings);
    });
  }

  Widget _rulesRankInvite() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _roundIconLabel(Icons.emoji_events_outlined, 'الترتيب', () => _soon('الترتيب')),
          InkWell(
            onTap: () => _soon('دعوة صديق'),
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: SamrahColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: SamrahColors.line),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt, size: 18, color: SamrahColors.text),
                  Text('ادعُ', style: TextStyle(fontSize: 9, color: SamrahColors.text)),
                ],
              ),
            ),
          ),
          _roundIconLabel(Icons.menu_book_outlined, 'القوانين', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RulesScreen(variant: _variant)))),
        ],
      ),
    );
  }

  Widget _roundIconLabel(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SamrahColors.line),
            ),
            child: Icon(icon, size: 18, color: SamrahColors.icon),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: SamrahColors.textMuted)),
        ],
      ),
    );
  }
}
