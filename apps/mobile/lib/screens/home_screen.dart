// Home screen: header (stars · profile with settings · coins, messages and
// notifications), the game's icon and name (swipe or arrows to change game),
// the radial wheel of actions above the bottom nav, and the bottom nav. Icons use Material's outline set as a pragmatic stand-in for
// the spec's custom line icons (no Jawaker art either way).
//
// The name, level, wallets and badges are the player's account on the server
// (lib/services/account.dart), kept fresh in the background; every wheel option
// and header icon leads to a real screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/samrah_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/radial_mode_wheel.dart';
import 'challenges_screen.dart';
import 'clubs_screen.dart';
import 'competitions_screen.dart';
import 'games_screen.dart';
import 'new_game_sheet.dart';
import 'chat_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import 'room_screen.dart';
import 'tables_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';
import '../services/account.dart';
import '../services/challenges.dart';
import '../services/clubs.dart';
import '../services/store.dart';
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
    ('tarneeb400', '400', '4 لاعبين · فريقين · الطرنيب كبة'),
    ('trix', 'تركس', '4 لاعبين · كل لاعب لنفسه'),
    ('trixPartners', 'تركس شراكة', '4 لاعبين · فريقين'),
    ('trixComplex', 'تركس كمبلكس', '4 لاعبين · كل لاعب لنفسه'),
    ('trixComplexPartners', 'تركس كمبلكس شراكة', '4 لاعبين · فريقين'),
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
    // the account, the badges, the challenges and clubs
    Account.instance.start();
    unawaited(Challenges.instance.load());
    unawaited(Clubs.instance.loadMine());
  }

  String get _name => Account.instance.me?.name ?? widget.playerName;

  @override
  void dispose() {
    _warmTimer?.cancel();
    super.dispose();
  }

  void _openRoomFlow({required bool auto, Map<String, Object?>? settings}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(initialName: _name, autoOpen: auto, variant: _variant, settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Account.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final trimmedName = _name.trim();
    final letter = trimmedName.isNotEmpty ? trimmedName.characters.first : '؟';
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: _body(letter),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([Challenges.instance, Clubs.instance]),
        builder: (_, _) => BottomNav(
          index: _navIndex,
          onTap: _onNav,
          challengeBadge: Challenges.instance.claimableCount,
          clubsLocked: Clubs.instance.loaded && !Clubs.instance.unlocked,
        ),
      ),
      ),
    );
  }

  void _onNav(int i) {
    if (i == 2) return; // already home
    if (i == 0) {
      _push(const StoreScreen());
      return;
    }
    if (i == 1) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GamesScreen(playerName: _name)));
      return;
    }
    if (i == 3) {
      _push(const ClubsScreen());
      return;
    }
    if (i == 4) _push(const ChallengesScreen());
  }

  Widget _header(String letter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // right edge: the wallets, one above the other (same width)
          ListenableBuilder(
            listenable: Store.instance,
            builder: (_, _) => IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _wallet(icon: const StarIcon(size: 16), value: Store.instance.stars, tab: 0),
                const SizedBox(height: 8),
                _wallet(icon: const UnitIcon(size: 16), value: Store.instance.units, tab: 0),
              ],
            ),
          ),
          ),
          const SizedBox(width: 10),
          // the player, centred and given the room
          Expanded(child: _profileCapsule(letter)),
          const SizedBox(width: 10),
          // left edge: messages and notifications
          _iconColumn([
            (Icons.chat_bubble_outline, 'الرسائل', Account.instance.unreadMessages, () => _push(const MessagesScreen())),
            (Icons.notifications_none, 'التنبيهات', Account.instance.unreadNotifications, () => _push(const NotificationsScreen())),
          ]),
        ],
      ),
    );
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) => Account.instance.refresh());

  /// Icons 36 apart, each with a 44x44 touch area (the areas reach 4px past their slot).
  Widget _iconColumn(List<(IconData, String, int, VoidCallback)> items) {
    return SizedBox(
      width: 44,
      height: 36.0 * items.length,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, (icon, tooltip, badge, onTap)) in items.indexed)
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
                icon: Badge(
                  isLabelVisible: badge > 0,
                  label: Text(badge > 99 ? '99+' : '$badge'),
                  backgroundColor: SamrahColors.suitRed,
                  child: Icon(icon, color: SamrahColors.text, size: 24),
                ),
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
                  _name,
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
                      child: Text('${Account.instance.me?.level ?? 1}', style: const TextStyle(color: SamrahColors.onAccent, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: Account.instance.me?.levelProgress ?? 0, minHeight: 6, backgroundColor: SamrahColors.scorebox, color: SamrahColors.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${((Account.instance.me?.levelProgress ?? 0) * 100).round()}%', style: const TextStyle(color: SamrahColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // settings live with the player
          _headerIcon(Icons.settings_outlined, 'الإعدادات', () => _push(const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _wallet({required Widget icon, required int value, required int tab}) {
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: () => _push(StoreScreen(initialTab: tab)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: SamrahColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: SamrahColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            CountUp(value: value, style: const TextStyle(color: SamrahColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: SamrahColors.surface2, shape: BoxShape.circle),
              child: const Icon(Icons.add, size: 12, color: SamrahColors.text),
            ),
          ],
        ),
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
        RadialOption(
          label: 'المسابقات',
          icon: Icons.military_tech_outlined,
          action: 'ادخل',
          onSelected: () => _push(CompetitionsScreen(variant: _variant)),
        ),
        RadialOption(label: 'الألعاب العامة', icon: Icons.public, action: 'تصفّح', onSelected: () => _push(TablesScreen(variant: _variant))),
        RadialOption(
          label: 'القوانين',
          icon: Icons.menu_book_outlined,
          action: 'اقرأ',
          onSelected: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RulesScreen(variant: _variant))),
        ),
        RadialOption(label: 'الترتيب', icon: Icons.emoji_events_outlined, action: 'اعرض', onSelected: () => _push(LeaderboardScreen(variant: _variant))),
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
