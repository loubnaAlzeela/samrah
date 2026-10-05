// The store's catalogue (how every card back, table, seat ring, name colour, badge, card-play effect and emote looks,
// and the boosters) and the player's side of it: the two wallets
// («وحدات» / «نجوم»), what the player owns and uses, the gold membership and the daily gift. The numbers and the
// ownership live on the server (lib/services/account.dart); this class reads them from there and sends every
// purchase there. Money packs are bought through the phone's store (lib/services/purchases.dart).
import 'package:flutter/material.dart';

import '../widgets/emote_face.dart';
import 'account.dart';
import 'api.dart';
import 'error_text.dart';

/// A card-back design: the back colour, its rim and the mark in the middle.
class CardBackStyle {
  const CardBackStyle({required this.id, required this.name, required this.price, required this.color, required this.rim, required this.mark, this.symbol = BackSymbol.diamond, this.vipOnly = false});
  final String id;
  final String name;

  /// In «وحدات»; 0 = free.
  final int price;
  final Color color;
  final Color rim;
  final Color mark;
  final BackSymbol symbol;

  /// Members only (العضوية الذهبية), not sold on its own.
  final bool vipOnly;
}

enum BackSymbol { diamond, star, spade, heart }

/// A table design. The felt stays light so the text drawn on it keeps reading.
class TableStyle {
  const TableStyle({required this.id, required this.name, required this.price, required this.center, required this.mid, required this.edge, required this.rim, this.vipOnly = false});
  final String id;
  final String name;
  final int price;
  final Color center;
  final Color mid;
  final Color edge;

  /// The raised rim: light, base, dark.
  final List<Color> rim;
  final bool vipOnly;
}

/// A colour ring around the seat's avatar ([colors] go round it; one colour = a plain ring).
class SeatStyle {
  const SeatStyle({required this.id, required this.name, required this.price, required this.colors, this.vipOnly = false});
  final String id;
  final String name;
  final int price;
  final List<Color> colors;
  final bool vipOnly;
}

/// The colour of the player's name on the table.
class NameStyle {
  const NameStyle({required this.id, required this.name, required this.price, required this.color, this.vipOnly = false});
  final String id;
  final String name;
  final int price;
  final Color color;
  final bool vipOnly;
}

/// A small badge on the avatar's corner: an [icon] or a [glyph]; neither = no badge.
class BadgeStyle {
  const BadgeStyle({required this.id, required this.name, required this.price, this.icon, this.glyph, this.color = Colors.transparent, this.vipOnly = false});
  final String id;
  final String name;
  final int price;
  final IconData? icon;
  final String? glyph;
  final Color color;
  final bool vipOnly;

  bool get none => icon == null && glyph == null;
}

/// What a card does as it lands when this player plays it: a ring of [color], and [glyph] (if any) thrown around it.
class HitStyle {
  const HitStyle({required this.id, required this.name, required this.price, required this.color, this.glyph, this.vipOnly = false});
  final String id;
  final String name;
  final int price;
  final Color color;
  final String? glyph;
  final bool vipOnly;

  bool get none => id == 'hit_none';
}

/// A face sent at the table (from the chat sheet). Owned ones only; there is nothing to "use". Drawn, not named: the
/// catalogue shows the picture and the price, nothing else — [label] is only the expression word, for a screen
/// reader, and is never shown as a caption.
class EmoteItem {
  const EmoteItem({required this.id, required this.faceId, required this.label, required this.price, this.vipOnly = false});
  final String id;

  /// which face it draws (lib/widgets/emote_face.dart kEmoteFaces).
  final String faceId;
  final String label;
  final int price;
  final bool vipOnly;
}

/// Doubles the experience earned for [hours]; paid in «نجوم» and spent at once.
class Booster {
  const Booster(this.id, this.hours, this.price);
  final String id;
  final int hours;
  final int price;
}

/// What a seat wears, as the server sends it (item ids by kind).
class SeatLook {
  const SeatLook({this.seat = 'seat_plain', this.name = 'name_plain', this.badge = 'badge_none', this.hit = 'hit_none'});
  final String seat;
  final String name;
  final String badge;
  final String hit;

  static SeatLook? fromJson(Object? json) {
    if (json is! Map) return null;
    return SeatLook(
      seat: json['seat'] as String? ?? 'seat_plain',
      name: json['name'] as String? ?? 'name_plain',
      badge: json['badge'] as String? ?? 'badge_none',
      hit: json['hit'] as String? ?? 'hit_none',
    );
  }

  SeatStyle get seatStyle => Store.seatStyle(seat);
  NameStyle get nameStyle => Store.nameStyle(name);
  BadgeStyle get badgeStyle => Store.badgeStyle(badge);
  HitStyle get hitStyle => Store.hitStyle(hit);
}

/// A pack of currency bought with real money. [id] is the product id in Google Play and the App Store;
/// [price] is shown until the store answers with the local price.
class CoinPack {
  const CoinPack(this.id, this.amount, this.price, {this.name, this.bonus = 0, this.tag});
  final String id;
  final String? name;
  final int amount;
  final String price;
  final int bonus;
  final String? tag;
}

/// The one-time welcome offer as the server describes it (open for some days after the account is made).
class Offer {
  const Offer({required this.until, required this.units, required this.boostHours, required this.item});
  final DateTime until;
  final int units;
  final int boostHours;
  final String item;
}

class Store extends ChangeNotifier {
  Store._() {
    Account.instance.addListener(notifyListeners);
  }
  static final instance = Store._();

  static const cardBacks = [
    CardBackStyle(id: 'orange', name: 'البرتقالي', price: 0, color: Color(0xFFC8650C), rim: Color(0xFFFAF3E1), mark: Color(0xFFFAF3E1)),
    CardBackStyle(id: 'navy', name: 'الكحلي', price: 300, color: Color(0xFF1E2F55), rim: Color(0xFFFAF3E1), mark: Color(0xFFE8C77A), symbol: BackSymbol.star),
    CardBackStyle(id: 'emerald', name: 'الزمردي', price: 300, color: Color(0xFF1F5C46), rim: Color(0xFFFAF3E1), mark: Color(0xFFF5E7C6), symbol: BackSymbol.spade),
    CardBackStyle(id: 'wine', name: 'العنّابي', price: 500, color: Color(0xFF6E1F2C), rim: Color(0xFFF5E7C6), mark: Color(0xFFE8C77A), symbol: BackSymbol.heart),
    CardBackStyle(id: 'charcoal', name: 'الفحمي', price: 500, color: Color(0xFF2A2A2A), rim: Color(0xFFFA8112), mark: Color(0xFFFA8112), symbol: BackSymbol.star),
    CardBackStyle(id: 'gold', name: 'الذهبي', price: 0, color: Color(0xFF151515), rim: Color(0xFFE8C77A), mark: Color(0xFFE8C77A), symbol: BackSymbol.star, vipOnly: true),
  ];

  static const tables = [
    TableStyle(
      id: 'cream', name: 'الكريمي', price: 0,
      center: Color(0xFFF9E6A8), mid: Color(0xFFF0D88E), edge: Color(0xFFE0C474),
      rim: [Color(0xFFFFB066), Color(0xFFFA8112), Color(0xFFB85600)],
    ),
    TableStyle(
      id: 'mint', name: 'النعناعي', price: 400,
      center: Color(0xFFDDF0DF), mid: Color(0xFFC6E4CA), edge: Color(0xFFA9D2AF),
      rim: [Color(0xFF6FA57A), Color(0xFF3F7A4C), Color(0xFF285533)],
    ),
    TableStyle(
      id: 'sky', name: 'السماوي', price: 400,
      center: Color(0xFFDCEBF5), mid: Color(0xFFC4DCEC), edge: Color(0xFFA6C7DE),
      rim: [Color(0xFF6E93B5), Color(0xFF3D6489), Color(0xFF26445F)],
    ),
    TableStyle(
      id: 'rose', name: 'الوردي', price: 600,
      center: Color(0xFFF7E1DF), mid: Color(0xFFEFCBC8), edge: Color(0xFFE0AFAB),
      rim: [Color(0xFFB8706E), Color(0xFF8C3F43), Color(0xFF5F262B)],
    ),
    TableStyle(
      id: 'sand', name: 'الرملي', price: 600,
      center: Color(0xFFF3E9D8), mid: Color(0xFFE6D6BC), edge: Color(0xFFD3BE9C),
      rim: [Color(0xFF8A7458), Color(0xFF5E4B36), Color(0xFF3C2F21)],
    ),
    TableStyle(
      id: 'royal', name: 'الملكي', price: 0, vipOnly: true,
      center: Color(0xFFF6EDD3), mid: Color(0xFFEBDDB4), edge: Color(0xFFD9C58E),
      rim: [Color(0xFF3A3A3A), Color(0xFF151515), Color(0xFF000000)],
    ),
  ];

  static const seats = [
    SeatStyle(id: 'seat_plain', name: 'الكريمي', price: 0, colors: [Color(0xFFF5E7C6)]),
    SeatStyle(id: 'seat_orange', name: 'البرتقالي', price: 600, colors: [Color(0xFFFA8112)]),
    SeatStyle(id: 'seat_teal', name: 'الفيروزي', price: 600, colors: [Color(0xFF2EC4B6)]),
    SeatStyle(id: 'seat_violet', name: 'البنفسجي', price: 800, colors: [Color(0xFF9B6BFF), Color(0xFF5B3DC8)]),
    SeatStyle(id: 'seat_ruby', name: 'الياقوتي', price: 800, colors: [Color(0xFFFF4D6D), Color(0xFF9E1B32)]),
    SeatStyle(id: 'seat_rainbow', name: 'قوس قزح', price: 1500, colors: [Color(0xFFFF4D6D), Color(0xFFFA8112), Color(0xFFFFD166), Color(0xFF2EC4B6), Color(0xFF9B6BFF), Color(0xFFFF4D6D)]),
    SeatStyle(id: 'seat_gold', name: 'الذهبي', price: 0, vipOnly: true, colors: [Color(0xFFFFE7A3), Color(0xFFE8C77A), Color(0xFF9C7A2E), Color(0xFFFFE7A3)]),
  ];

  static const names = [
    NameStyle(id: 'name_plain', name: 'الكريمي', price: 0, color: Color(0xFFFAF3E1)),
    NameStyle(id: 'name_orange', name: 'البرتقالي', price: 400, color: Color(0xFFFFA24C)),
    NameStyle(id: 'name_mint', name: 'النعناعي', price: 400, color: Color(0xFF7DE2B4)),
    NameStyle(id: 'name_sky', name: 'السماوي', price: 400, color: Color(0xFF7CC4FF)),
    NameStyle(id: 'name_pink', name: 'الوردي', price: 600, color: Color(0xFFFF8FB1)),
    NameStyle(id: 'name_lilac', name: 'الليلكي', price: 600, color: Color(0xFFC6A8FF)),
    NameStyle(id: 'name_gold', name: 'الذهبي', price: 0, vipOnly: true, color: Color(0xFFE8C77A)),
  ];

  static const badges = [
    BadgeStyle(id: 'badge_none', name: 'بلا شارة', price: 0),
    BadgeStyle(id: 'badge_spade', name: 'البستوني', price: 800, glyph: '♠', color: Color(0xFF3A3A3A)),
    BadgeStyle(id: 'badge_heart', name: 'القلب', price: 800, icon: Icons.favorite_rounded, color: Color(0xFFD7263D)),
    BadgeStyle(id: 'badge_fire', name: 'اللهب', price: 1200, icon: Icons.local_fire_department_rounded, color: Color(0xFFFA8112)),
    BadgeStyle(id: 'badge_bolt', name: 'البرق', price: 1200, icon: Icons.bolt_rounded, color: Color(0xFF2E86DE)),
    BadgeStyle(id: 'badge_diamond', name: 'الألماسة', price: 2500, icon: Icons.diamond_rounded, color: Color(0xFF2EC4B6)),
    BadgeStyle(id: 'badge_crown', name: 'التاج', price: 0, vipOnly: true, icon: Icons.workspace_premium_rounded, color: Color(0xFFB8902F)),
  ];

  static const hits = [
    HitStyle(id: 'hit_none', name: 'بلا ضربة', price: 0, color: Colors.transparent),
    HitStyle(id: 'hit_wave', name: 'الموجة', price: 1000, color: Color(0xFFFAF3E1)),
    HitStyle(id: 'hit_sparks', name: 'الشرر', price: 1200, color: Color(0xFFFFB066), glyph: '✦'),
    HitStyle(id: 'hit_hearts', name: 'القلوب', price: 1500, color: Color(0xFFFF4D6D), glyph: '♥'),
    HitStyle(id: 'hit_fire', name: 'اللهب', price: 2000, color: Color(0xFFFA8112), glyph: '🔥'),
    HitStyle(id: 'hit_stars', name: 'النجوم', price: 0, vipOnly: true, color: Color(0xFFE8C77A), glyph: '★'),
  ];

  /// Every face (lib/widgets/emote_face.dart): the ids and prices mirror the server's
  /// (accounts.ts EMOTE_FACES) so what is bought here is what is owned there.
  static final List<EmoteItem> emotes = [
    for (final f in kEmoteFaces) EmoteItem(id: 'emo_${f.id}', faceId: f.id, label: f.label, price: f.price),
  ];

  static const boosters = [
    Booster('boost_3h', 3, 30),
    Booster('boost_12h', 12, 80),
    Booster('boost_24h', 24, 140),
  ];

  static SeatStyle seatStyle(String id) => seats.firstWhere((x) => x.id == id, orElse: () => seats.first);
  static NameStyle nameStyle(String id) => names.firstWhere((x) => x.id == id, orElse: () => names.first);
  static BadgeStyle badgeStyle(String id) => badges.firstWhere((x) => x.id == id, orElse: () => badges.first);
  static HitStyle hitStyle(String id) => hits.firstWhere((x) => x.id == id, orElse: () => hits.first);

  static const unitPacks = [
    CoinPack('units_500', 500, '0.99\$', name: 'حفنة وحدات'),
    CoinPack('units_1200', 1200, '1.99\$', name: 'صُرّة وحدات', bonus: 100),
    CoinPack('units_3500', 3500, '4.99\$', name: 'كومة وحدات', bonus: 500),
    CoinPack('units_8000', 8000, '9.99\$', name: 'كيس وحدات', bonus: 1500),
    CoinPack('units_18000', 18000, '19.99\$', name: 'حقيبة وحدات', bonus: 4000, tag: 'الأكثر شراءً'),
    CoinPack('units_50000', 50000, '49.99\$', name: 'صندوق وحدات', bonus: 15000),
    CoinPack('units_100000', 100000, '99.99\$', name: 'خزنة وحدات', bonus: 35000, tag: 'أفضل قيمة'),
  ];

  static const starPacks = [
    CoinPack('stars_50', 50, '0.99\$', name: 'نجوم قليلة'),
    CoinPack('stars_120', 120, '1.99\$', name: 'باقة نجوم', bonus: 10),
    CoinPack('stars_350', 350, '4.99\$', name: 'سماء نجوم', bonus: 50, tag: 'الأكثر شراءً'),
    CoinPack('stars_800', 800, '9.99\$', name: 'مجرّة نجوم', bonus: 150),
  ];

  /// The welcome offer's product (what it adds comes from the server: [offer]), sold at [offerShare] of its full
  /// price ([offerWas] until the store answers with the local price).
  static const offerPack = CoinPack('offer_starter', 6000, '4.99\$', name: 'عرض الترحيب');
  static const offerShare = 0.3;
  static const offerWas = '16.63\$';

  static List<CoinPack> get allPacks => [...unitPacks, ...starPacks, offerPack];

  /// Gold membership: price in «نجوم», for 30 days.
  static const vipPrice = 300;
  static const dailyGift = 100;

  Me? get _me => Account.instance.me;

  int get units => _me?.units ?? 0;
  int get stars => _me?.stars ?? 0;
  bool get vip => _me?.vip ?? false;
  DateTime? get vipUntil => _me?.vipUntil;
  bool get giftClaimed => _me?.giftTaken ?? false;

  /// Members get the gift twice over.
  int get giftAmount => _me?.giftAmount ?? (vip ? dailyGift * 2 : dailyGift);

  /// What I wear on the table.
  SeatLook get look => SeatLook.fromJson(_me?.raw['look']) ?? const SeatLook();

  /// Experience counts double until then (null = no booster running).
  DateTime? get boostUntil {
    final ms = _me?.raw['boostUntil'] as num?;
    final t = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }

  /// The welcome offer while it is open to me.
  Offer? get offer {
    final o = _me?.raw['offer'];
    if (o is! Map) return null;
    final until = DateTime.fromMillisecondsSinceEpoch((o['until'] as num).toInt());
    if (!until.isAfter(DateTime.now())) return null;
    return Offer(until: until, units: (o['units'] as num).toInt(), boostHours: (o['boostHours'] as num).toInt(), item: o['item'] as String);
  }

  CardBackStyle get cardBack => cardBacks.firstWhere((b) => b.id == (_me?.backId ?? 'orange'), orElse: () => cardBacks.first);
  TableStyle get table => tables.firstWhere((t) => t.id == (_me?.tableId ?? 'cream'), orElse: () => tables.first);

  bool owns(String id) => (_me?.owned ?? const ['orange', 'cream']).contains(id);
  bool inUse(String id) {
    final l = look;
    return id == cardBack.id || id == table.id || id == l.seat || id == l.name || id == l.badge || id == l.hit;
  }

  /// Each action answers null when done, or the Arabic reason it was refused.
  Future<String?> _do(String path, [Object? body]) async {
    try {
      await Account.instance.call(path, body);
      return null;
    } on ApiError catch (e) {
      return errorText(e.code);
    }
  }

  /// Spends the item's price in «وحدات».
  Future<String?> buy(String id) => _do('/store/buy', {'id': id});

  /// Wears an owned item: a card back, a table, a seat ring, a name colour, a badge or a card-play effect.
  Future<String?> use(String id) => _do('/store/use', {'id': id});

  Future<String?> useBack(String id) => use(id);

  Future<String?> useTable(String id) => use(id);

  Future<String?> buyVip() => _do('/store/vip');

  /// The daily gift: the amount added, or an error.
  Future<(int?, String?)> claimGift() async {
    try {
      final r = await Api.instance.post('/store/gift') as Map;
      Account.instance.apply(r['me']);
      return ((r['added'] as num).toInt(), null);
    } on ApiError catch (e) {
      return (null, errorText(e.code));
    }
  }
}
