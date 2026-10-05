// The table's chat and gifts (design/layout-v3.md §6): the chat button opens a sheet of the emotes the player owns
// from the store, quick messages and a text field; a message shows for four seconds as a cream bubble beside its
// sender's avatar (an emote shows large, on its own). The gift button
// sends a small gift, paid in «وحدات», to another player at the table; the whole table sees it fly across.
// Every game screen puts a [TableSocialLayer] over its stage, with the centre of each seat's avatar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/room_view.dart';
import '../services/account.dart';
import '../services/colyseus_client.dart';
import '../services/sound.dart';
import '../services/store.dart';
import 'emote_face.dart';
import '../theme/samrah_theme.dart';

/// The gifts (the server holds the same list with the prices it charges).
const kGifts = [
  ('rose', 'وردة', '🌹', 20),
  ('coffee', 'فنجان قهوة', '☕', 30),
  ('tea', 'كاسة شاي', '🍵', 30),
  ('dates', 'تمر', '🌴', 50),
  ('cake', 'كيكة', '🎂', 100),
  ('trophy', 'كأس', '🏆', 200),
  ('crown', 'تاج', '👑', 500),
  ('diamond', 'ألماسة', '💎', 1000),
];

String giftEmoji(String id) => kGifts.firstWhere((g) => g.$1 == id, orElse: () => kGifts.first).$3;

/// Price from the server's list when it has one.
int giftPrice(String id) {
  final list = Account.instance.config['gifts'] as List?;
  final g = list?.cast<Map>().where((g) => g['id'] == id).firstOrNull;
  return (g?['price'] as num?)?.toInt() ?? kGifts.firstWhere((x) => x.$1 == id).$4;
}

const kQuickMessages = ['السلام عليكم', 'أهلاً وسهلاً', 'يلا بسرعة', 'لعب حلو 👏', 'حظ أوفر', 'مبروك', 'سامحونا', 'شكراً', 'جولة ثانية؟', 'مع السلامة'];

/// Chat bubbles and flying gifts over the stage (a fixed 390-wide canvas, left to right).
class TableSocialLayer extends StatefulWidget {
  const TableSocialLayer({super.key, required this.conn, required this.anchor, required this.mySeat});
  final RoomConnection conn;

  /// The centre of [seat]'s avatar on the stage.
  final Offset Function(int seat) anchor;
  final int mySeat;

  @override
  State<TableSocialLayer> createState() => _TableSocialLayerState();
}

class _Bubble {
  _Bubble(this.seat, this.text, this.key, {this.emote});
  final int seat;
  final String text;
  final Key key;

  /// a store emote's id (lib/widgets/emote_face.dart): the face alone, large, in place of [text]
  final String? emote;
}

class _Flying {
  _Flying(this.gift, this.from, this.to, this.key);
  final String gift;
  final int from;
  final int to;
  final Key key;
}

class _TableSocialLayerState extends State<TableSocialLayer> {
  final List<_Bubble> _bubbles = [];
  final List<_Flying> _gifts = [];
  late StreamSubscription<TableChat> _chatSub;
  late StreamSubscription<TableGift> _giftSub;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _chatSub = widget.conn.onChat.listen((m) {
      if (m.emote != null) Sound.instance.playEmote(m.emote!);
      final b = _Bubble(m.seat, m.text, ValueKey('b${_n++}'), emote: m.emote);
      setState(() {
        // one bubble per seat: a new message replaces the last one
        _bubbles.removeWhere((x) => x.seat == m.seat);
        _bubbles.add(b);
      });
      Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _bubbles.remove(b));
      });
    });
    _giftSub = widget.conn.onGift.listen((g) {
      final f = _Flying(g.gift, g.from, g.to, ValueKey('g${_n++}'));
      setState(() => _gifts.add(f));
      Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _gifts.remove(f));
      });
    });
  }

  @override
  void dispose() {
    _chatSub.cancel();
    _giftSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: [
        for (final b in _bubbles) _bubble(b),
        for (final g in _gifts) _fly(g),
      ]),
    );
  }

  Widget _bubble(_Bubble b) {
    final a = widget.anchor(b.seat);
    const w = 150.0;
    // beside the avatar, towards the middle of the table; mine above my panel
    double left;
    double top;
    if (b.seat == widget.mySeat) {
      left = a.dx - 10;
      top = a.dy - 96;
    } else if (a.dx > 260) {
      left = a.dx - w - 34;
      top = a.dy - 30;
    } else if (a.dx < 130) {
      left = a.dx + 34;
      top = a.dy - 30;
    } else {
      left = a.dx - w / 2;
      top = a.dy + 40;
    }
    return Positioned(
      key: b.key,
      left: left.clamp(4, 390 - w - 4),
      top: top,
      width: w,
      child: Semantics(
        liveRegion: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Align(
            alignment: Alignment.center,
            child: b.emote != null
                ? SizedBox(width: 56, height: 56, child: DecoratedBox(decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))]), child: EmoteFace(id: b.emote!, size: 56)))
                : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: SamrahColors.selectedBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(b.text, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SamrahColors.onSelected, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fly(_Flying g) {
    final from = widget.anchor(g.from);
    final to = widget.anchor(g.to);
    return TweenAnimationBuilder<double>(
      key: g.key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2400),
      builder: (_, t, _) {
        // fly for the first 60%, then sit on the receiver and grow a little before fading
        final travel = Curves.easeInOutCubic.transform((t / 0.6).clamp(0, 1));
        final p = Offset.lerp(from, to, travel)!;
        final lift = -60 * (1 - (2 * travel - 1) * (2 * travel - 1)); // an arc
        final scale = t < 0.6 ? 1.0 + 0.4 * travel : 1.4 + 0.3 * ((t - 0.6) / 0.4);
        final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0);
        return Positioned(
          left: p.dx - 20,
          top: p.dy - 20 + lift,
          child: Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: Text(giftEmoji(g.gift), style: const TextStyle(fontSize: 32)))),
        );
      },
    );
  }
}

/// The chat sheet: recent messages, quick messages, and a text field.
Future<void> openTableChat(BuildContext context, RoomConnection conn, RoomView view) async {
  if (!view.chatOn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الدردشة مغلقة في هذه اللعبة'), duration: Duration(seconds: 2)));
    return;
  }
  final text = TextEditingController();
  String name(int s) => s < view.seats.length ? (view.seats[s]?.name ?? '؟') : '؟';
  void send(String t) {
    final m = t.trim();
    if (m.isEmpty) return;
    conn.send('chat', {'text': m});
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SamrahColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
      // Only the message list below listens to the chat stream: a message arriving mid-close (an emote
      // tap pops the sheet and echoes back almost at once) must not rebuild the TextField's subtree —
      // Navigator.pop() resolves [showModalBottomSheet]'s future (and so disposes [text]) before the
      // sheet's own closing animation finishes, so anything still rebuilding that controller in during
      // those last frames crashes it ("used after being disposed").
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 10),
        Text('الدردشة', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w700)),
        StreamBuilder<TableChat>(
          stream: conn.onChat,
          builder: (ctx, _) => conn.chatLog.isEmpty
              ? const SizedBox.shrink()
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    reverse: true,
                    shrinkWrap: true,
                    children: [
                      for (final m in conn.chatLog.reversed.take(30))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${name(m.seat)}: ', style: TextStyle(color: m.seat == view.mySeat ? SamrahColors.accent : SamrahColors.textMuted, fontWeight: FontWeight.w700)),
                            TextSpan(text: m.text, style: const TextStyle(color: SamrahColors.text)),
                          ])),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        // my emotes from the store
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in Store.emotes)
                if (Store.instance.owns(e.id))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Material(
                      color: SamrahColors.surface2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          conn.send('emote', {'id': e.id});
                          Navigator.pop(ctx);
                        },
                        child: SizedBox(width: 52, height: 52, child: Semantics(label: e.label, child: EmoteFace(id: e.id, size: 52))),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in kQuickMessages)
            ActionChip(
              label: Text(q),
              backgroundColor: SamrahColors.surface2,
              onPressed: () {
                send(q);
                Navigator.pop(ctx);
              },
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: text,
              maxLength: 120,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(hintText: 'اكتب رسالة', isDense: true, counterText: ''),
              onSubmitted: (t) {
                send(t);
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: SamrahColors.accent, foregroundColor: SamrahColors.onAccent),
            onPressed: () {
              send(text.text);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.send_rounded, textDirection: TextDirection.rtl),
          ),
        ]),
      ]),
    ),
  );
  text.dispose();
}

/// The gift sheet: who receives it, then which gift.
Future<void> openGiftSheet(BuildContext context, RoomConnection conn, RoomView view) async {
  if (!Account.instance.signedIn) return;
  final me = view.mySeat;
  final targets = [
    for (var i = 0; i < view.seats.length; i++)
      if (i != me && view.seats[i] != null && !view.seats[i]!.bot && view.seats[i]!.uid != null) i,
  ];
  if (targets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد لاعب على الطاولة يمكن إهداؤه'), duration: Duration(seconds: 2)));
    return;
  }
  var to = targets.first;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: SamrahColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SamrahColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 10),
          Text('أرسل هدية', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ListenableBuilder(
            listenable: Account.instance,
            builder: (_, _) => Text('رصيدك ${Account.instance.me?.units ?? 0} وحدة', textAlign: TextAlign.center, style: const TextStyle(color: SamrahColors.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
            for (final s in targets)
              ChoiceChip(
                label: Text(view.seats[s]!.name),
                selected: s == to,
                selectedColor: SamrahColors.selectedBg,
                labelStyle: TextStyle(color: s == to ? SamrahColors.onSelected : SamrahColors.text, fontWeight: FontWeight.w600),
                onSelected: (_) => set(() => to = s),
              ),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (id, name, emoji, _) in kGifts)
                Material(
                  color: SamrahColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      conn.send('gift', {'seat': to, 'gift': id});
                      Navigator.pop(ctx);
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(emoji, style: const TextStyle(fontSize: 30)),
                      Text(name, style: const TextStyle(color: SamrahColors.text, fontSize: 11)),
                      Text('${giftPrice(id)}', style: const TextStyle(color: SamrahColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
        ]),
      ),
    ),
  );
}
