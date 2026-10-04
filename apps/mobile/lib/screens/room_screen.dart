// Entry screen: name field + "open room" button. Once connected, it hands
// off to WaitingScreen (before the game starts) or GameScreen (bidding,
// trump, play, results) — driven entirely by the server's `state` broadcast.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/colyseus_client.dart';
import '../services/account.dart';
import '../services/config.dart';
import '../services/error_text.dart';
import '../services/sound.dart';
import '../theme/samrah_theme.dart';
import 'b187_game_screen.dart';
import 'baloot_game_screen.dart';
import 'game_screen.dart';
import 'hand_game_screen.dart';
import 'profile_screen.dart';
import 'rules_screen.dart';
import 'trix_game_screen.dart';
import 'waiting_screen.dart';
import '../widgets/motion.dart';

String variantNameAr(String v) => switch (v) {
  'syrian41' => 'طرنيب سوري 41',
  'tarneeb400' => '400',
  'trix' => 'تركس',
  'trixPartners' => 'تركس شراكة',
  'trixComplex' => 'تركس كمبلكس',
  'trixComplexPartners' => 'تركس كمبلكس شراكة',
  'b187' => 'لعبة 187',
  'baloot' => 'بلوت',
  'hand' => 'هاند سعودي',
  _ => 'طرنيب',
};

/// One client for the whole app (created on first use): its connection pool
/// outlives any single table, so the home screen can warm it up and every
/// table after the first opens without new handshakes.
final GameServerClient gameServer = GameServerClient(kGameServer);

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, this.initialName, this.autoOpen = false, this.variant = 'tarneeb', this.settings, this.joinCode});

  /// Joins this table instead of opening a new one (a public table, a friend's code, a competition match).
  final String? joinCode;

  /// wire variant, e.g. 'tarneeb' | 'syrian41' | 'tarneeb400'.
  final String variant;

  /// Partial room settings from «لعبة جديدة»; null = server defaults.
  final Map<String, Object?>? settings;

  /// Pre-fills the name field. Set when arriving from HomeScreen, which
  /// already collected the player's name at login.
  final String? initialName;

  /// Skips the manual "افتح غرفة" tap and connects immediately on open —
  /// used for the "إنشاء لعبة" / "لعبة ودية" home cards. Falls back to the
  /// normal form if it fails, so this is purely a UX shortcut, not a new
  /// connection path.
  final bool autoOpen;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final _nameCtrl = TextEditingController(
    text: Account.instance.me?.name ?? (widget.initialName?.trim().isNotEmpty == true ? widget.initialName : 'لاعب'),
  );

  bool get _auto => widget.autoOpen || widget.joinCode != null;

  RoomConnection? _connection;
  String _openStatus = 'idle'; // idle | connecting | error
  String? _lastError;
  Timer? _errorTimer;
  RoomView? _view;

  /// A rejected action (e.g. a card played a beat too late) shows briefly, then clears
  /// itself — it isn't a connection problem, so it shouldn't sit on screen forever.
  void _flashError(String e) {
    _errorTimer?.cancel();
    setState(() => _lastError = e);
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lastError = null);
    });
  }

  @override
  void initState() {
    super.initState();
    if (_auto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRoom());
    }
  }

  Future<void> _openRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    _errorTimer?.cancel();
    setState(() {
      _openStatus = 'connecting';
      _lastError = null;
    });
    try {
      final conn = widget.joinCode != null
          ? await gameServer.joinRoom(code: widget.joinCode!, playerName: name)
          : await gameServer.openRoom(playerName: name, variant: widget.variant, settings: widget.settings);
      _connection = conn;
      conn.onState.listen((v) => setState(() => _view = v));
      conn.onError.listen((e) => _flashError(errorText(e)));
      conn.onStatus.listen((_) => setState(() {})); // repaint the reconnecting banner
      setState(() => _openStatus = 'connected');
    } catch (e) {
      setState(() {
        _openStatus = 'error';
        _lastError = errorText(e);
      });
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    // leaving the table: stop the voice and any sound still scheduled for it
    Sound.instance.stopAll();
    _connection?.leave();
    _nameCtrl.dispose();
    super.dispose();
  }

  // --- top bar ---------------------------------------------------------------

  Future<T?> _sheet<T>(String title, Widget body) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: SamrahColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 20, color: SamrahColors.text),
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }

  /// ≡ : game rules + leave the game.
  void _openMenu() {
    _sheet<void>(
      'القائمة',
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(Icons.menu_book_outlined, 'قواعد اللعبة', () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RulesScreen(variant: _view?.variant ?? widget.variant)));
            }),
            const Divider(height: 1),
            // sound settings (for this session)
            StatefulBuilder(
              builder: (ctx, setLocal) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _soundSwitch(Icons.volume_up_outlined, 'المؤثرات الصوتية', Sound.instance.effects, (v) => setLocal(() => Sound.instance.effects = v)),
                  _soundSwitch(Icons.record_voice_over_outlined, 'نطق الخيارات', Sound.instance.voice, (v) => setLocal(() => Sound.instance.voice = v)),
                ],
              ),
            ),
            const Divider(height: 1),
            _menuItem(Icons.logout, 'الخروج من اللعبة', () {
              Navigator.pop(ctx);
              _confirmLeave();
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _soundSwitch(IconData icon, String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        secondary: Icon(icon, color: SamrahColors.text),
        title: Text(label, style: const TextStyle(color: SamrahColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: SamrahColors.onSelected,
        activeTrackColor: SamrahColors.selectedBg,
      );

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? const Color(0xFFF2A08E) : SamrahColors.text;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirmLeave() async {
    final playing = _view?.status == 'playing';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SamrahColors.surface,
        title: const Text('الخروج من اللعبة؟'),
        content: Text(playing ? 'اللعبة جارية. إذا خرجت فسيُكمل الحاسوب اللعب عنك.' : 'ستخرج من الغرفة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: SamrahColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'اخرج',
              style: TextStyle(color: Color(0xFFF2A08E), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(); // dispose() leaves the room
  }

  /// Invite: the room code, with a copy button.
  void _openInvite() {
    final code = _view!.code;
    _sheet<void>(
      'دعوة صديق',
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'شارك رمز الغرفة مع صديقك ليدخل:',
              textAlign: TextAlign.center,
              style: TextStyle(color: SamrahColors.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: SamrahColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SamrahColors.fieldBorder),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: SamrahColors.text, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 6),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('انسخ الرمز'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                await Clipboard.setData(ClipboardData(text: code));
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('تم نسخ الرمز'), duration: Duration(seconds: 2)));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Players at the table, with their status.
  void _openPlayers() {
    final v = _view!;
    _sheet<void>(
      'اللاعبون على الطاولة',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < v.seats.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: SamrahColors.avatarBg,
                child: v.seats[i]?.bot == true
                    ? const Icon(Icons.smart_toy_outlined, color: SamrahColors.text, size: 20)
                    : Text(
                        v.seats[i]?.name.characters.first ?? '+',
                        style: const TextStyle(color: SamrahColors.text, fontWeight: FontWeight.w700),
                      ),
              ),
              title: Text(
                v.seats[i] == null ? 'مقعد شاغر' : '${v.seats[i]!.name}${i == v.mySeat ? ' (أنت)' : ''}${i == v.ownerSeat ? ' · صاحب الغرفة' : ''}',
                style: const TextStyle(color: SamrahColors.text),
              ),
              trailing: v.seats[i] == null ? null : Text(_seatStatus(v.seats[i]!), style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
              // a player with an account: their page (message, block, report)
              onTap: v.seats[i]?.uid == null || i == v.mySeat
                  ? null
                  : () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userRef: v.seats[i]!.uid!)));
                    },
            ),
        ],
      ),
    );
  }

  static String _seatStatus(SeatInfo s) {
    if (s.bot) return 'حاسوب';
    if (!s.connected) return 'منقطع';
    if (s.auto) return 'الحاسوب يلعب عنه';
    return 'متصل';
  }

  @override
  Widget build(BuildContext context) {
    final conn = _connection;
    return Scaffold(
      appBar: AppBar(
        title: _view == null ? null : Text(variantNameAr(_view!.variant), style: GoogleFonts.cairo(fontSize: 20, color: SamrahColors.textMuted)),
        shape: const Border(bottom: BorderSide(color: SamrahColors.line)),
        leading: IconButton(icon: const Icon(Icons.menu), tooltip: 'القائمة', onPressed: _openMenu),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt), tooltip: 'دعوة صديق', onPressed: _view == null ? null : _openInvite),
          IconButton(icon: const Icon(Icons.group_outlined), tooltip: 'اللاعبون', onPressed: _view == null ? null : _openPlayers),
        ],
      ),
      // coming from the home screen the table opens by itself: show the brand while it does,
      // and fall back to the name form only if opening failed (or was never automatic)
      body: conn != null
          ? _connectedBody(conn)
          : _auto && _openStatus != 'error'
          ? _preparingTable()
          : _openForm(),
    );
  }

  /// Shown while a table is being opened: the Samrah mark and wordmark with a slim
  /// progress line — no connection wording, so the wait reads as part of the game.
  Widget _preparingTable() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopIn(
            from: 0.7,
            duration: Motion.slow,
            child: Image.asset('assets/brand/samrah-mark.png', height: 140, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          EnterFrom(
            delay: const Duration(milliseconds: 200),
            child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 44, fit: BoxFit.contain, semanticLabel: 'سمرة'),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 3, color: SamrahColors.accent, backgroundColor: SamrahColors.surface2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: PopIn(
              from: 0.7,
              duration: Motion.slow,
              child: Image.asset('assets/brand/samrah-mark.png', height: 140, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 8),
          EnterFrom(
            delay: const Duration(milliseconds: 200),
            child: Center(
              child: Image.asset('assets/brand/samrah-wordmark-ar.png', height: 44, fit: BoxFit.contain, semanticLabel: 'سمرة'),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameCtrl,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'اسم اللاعب'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openStatus == 'connecting' ? null : _openRoom,
            child: Text(_openStatus == 'error' ? 'حاول مجدداً' : 'افتح غرفة'),
          ),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'خطأ: $_lastError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SamrahColors.suitRed),
              ),
            ),
        ],
      ),
    );
  }

  Widget _connectedBody(RoomConnection conn) {
    final v = _view;
    // connected, waiting for the first table state: keep the same brand screen, no spinner swap
    if (v == null) return _preparingTable();
    if (conn.status == ConnStatus.closed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('انقطع الاتصال نهائياً. ${_lastError ?? ""}', textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        if (conn.status == ConnStatus.reconnecting)
          Container(
            width: double.infinity,
            color: SamrahColors.accent,
            padding: const EdgeInsets.all(6),
            child: const Text(
              'جارٍ إعادة الاتصال…',
              textAlign: TextAlign.center,
              style: TextStyle(color: SamrahColors.onAccent, fontWeight: FontWeight.w600),
            ),
          ),
        if (_lastError != null)
          Container(
            width: double.infinity,
            color: SamrahColors.surface2,
            padding: const EdgeInsets.all(6),
            child: Text(
              'خطأ: $_lastError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SamrahColors.suitRed),
            ),
          ),
        Expanded(
          child: v.status == 'waiting'
              ? WaitingScreen(view: v, onStart: () => conn.send('start'), onInvite: _openInvite)
              : isTrixVariant(v.variant)
              ? TrixGameScreen(view: v, conn: conn)
              : isB187Variant(v.variant)
              ? B187GameScreen(view: v, conn: conn)
              : isBalootVariant(v.variant)
              ? BalootGameScreen(view: v, conn: conn)
              : isHandVariant(v.variant)
              ? HandGameScreen(view: v, conn: conn)
              : GameScreen(view: v, conn: conn),
        ),
      ],
    );
  }
}
