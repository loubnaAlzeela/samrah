// Home screen: header (stars · profile with settings · coins, messages and
// notifications), the game's icon and name (swipe or arrows to change game),
// the radial wheel of actions above the bottom nav, and the bottom nav. Icons use Material's outline set as a pragmatic stand-in for
// the spec's custom line icons (no Jawaker art either way).
//
// Wallets ("وحدات" / "نجوم"), levels, store, clubs and challenges are
// DISPLAY ONLY — no backend yet (see layout-v3.md §10). Real gameplay
// (bidding, trump, play) is fully wired; «لعبة ودية», «إنشاء لعبة» and
// «القوانين» lead somewhere real right now.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/radial_mode_wheel.dart';
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
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: _body(letter),
      ),
      bottomNavigationBar: BottomNav(index: _navIndex, onTap: _onNav),
      ),
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
          _iconColumn([
            (Icons.chat_bubble_outline, 'الرسائل', () => _push(const PlaceholderScreen(title: 'الرسائل'))),
            (Icons.notifications_none, 'التنبيهات', () => _push(const PlaceholderScreen(title: 'التنبيهات'))),
          ]),
        ],
      ),
    );
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Icons 36 apart, each with a 44x44 touch area (the areas reach 4px past their slot).
  Widget _iconColumn(List<(IconData, String, VoidCallback)> items) {
    return SizedBox(
      width: 44,
      height: 36.0 * items.length,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, (icon, tooltip, onTap)) in items.indexed)
            Positioned(
              top: 36.0 * i - 4,
              left: 0,
              width: 44,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                tooltip: tooltip,
                onPressed: onTap,
                icon: Icon(icon, color: SamrahColors.text, size: 24),
              ),
            ),
        ],
      ),
    );
  }

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

  Widget _cardFan(double k) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final (i, r) in [(-1, -18.0), (0, 0.0), (1, 18.0)])
          Transform.rotate(
            angle: r * 3.14159 / 180,
            child: Transform.translate(
              offset: Offset(i * 14.0 * k, (i == 0 ? -4 : 2) * k),
              child: Container(
                width: 32 * k,
                height: 46 * k,
                decoration: BoxDecoration(
                  color: SamrahColors.cardFace,
                  borderRadius: BorderRadius.circular(6 * k),
                  border: Border.all(color: SamrahColors.cardEdge),
                ),
              ),
            ),
          ),
      ],
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

  /// the wheel sits 50 above the bottom nav (its button and every wedge included)
  static const _wheelClearance = 50.0;

  /// Header, then the game block and the wheel sharing the rest: the wheel takes what it
  /// needs, the game block hugs its content, and what is left becomes the spacing.
  Widget _body(String letter) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnterFrom(child: _header(letter)),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              // the wheel may use everything but the game block, a little spacing and the nav clearance
              final ts = MediaQuery.textScalerOf(context);
              final gameBlock = 40 + 6 + ts.scale(26) * 1.2;
              final wheelMax = box.maxHeight - gameBlock - 2 * 12 - _wheelClearance;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // two thirds of the spare room above the game name, one third between it and the wheel
                  const SizedBox(height: 12),
                  const Spacer(flex: 2),
                  EnterFrom(delay: Motion.stagger(1, stepMs: 80), child: _gameIdentity()),
                  const SizedBox(height: 12),
                  const Spacer(),
                  EnterFrom(
                    delay: Motion.stagger(2, stepMs: 80),
                    child: ConstrainedBox(constraints: BoxConstraints(maxHeight: wheelMax), child: _wheel()),
                  ),
                  const SizedBox(height: _wheelClearance),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// The game's icon and name as one tight group; swipe or use the arrows.
  Widget _gameIdentity() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        // RTL: a swipe to the left brings the next game, as the right arrow does
        _stepGame(v < 0 ? 1 : _games.length - 1);
      },
      child: Row(
        children: [
          _arrow(Icons.chevron_right, () => _stepGame(1)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 40, child: _cardFan(40 / 56)),
                const SizedBox(height: 6),
                Text(_games[_gameIndex].$2, style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.w700, color: SamrahColors.text, height: 1.2)),
              ],
            ),
          ),
          _arrow(Icons.chevron_left, () => _stepGame(_games.length - 1)),
        ],
      ),
    );
  }

  /// Every home action on one wheel: the three ways to play, then rules and leaderboard.
  Widget _wheel() {
    return RadialModeWheel(
      options: [
        RadialOption(label: 'لعبة ودية', icon: Icons.play_arrow_rounded, action: 'العب', onSelected: () => _openRoomFlow(auto: true)),
        RadialOption(label: 'إنشاء لعبة', icon: Icons.add_rounded, action: 'أنشئ', onSelected: _openNewGameSheet),
        RadialOption(label: 'الألعاب العامة', icon: Icons.public, action: 'تصفّح', onSelected: () => _soon('الألعاب العامة')),
        RadialOption(
          label: 'القوانين',
          icon: Icons.menu_book_outlined,
          action: 'اقرأ',
          onSelected: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RulesScreen(variant: _variant))),
        ),
        RadialOption(label: 'الترتيب', icon: Icons.emoji_events_outlined, action: 'اعرض', onSelected: () => _soon('الترتيب')),
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
}
