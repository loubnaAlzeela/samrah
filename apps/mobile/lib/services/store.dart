// The store's catalogue (how every card back and table looks) and the player's side of it: the two wallets
// («وحدات» / «نجوم»), what the player owns and uses, the gold membership and the daily gift. The numbers and the
// ownership live on the server (lib/services/account.dart); this class reads them from there and sends every
// purchase there. Money packs are bought through the phone's store (lib/services/purchases.dart).
import 'package:flutter/material.dart';

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

/// A pack of currency bought with real money. [id] is the product id in Google Play and the App Store;
/// [price] is shown until the store answers with the local price.
class CoinPack {
  const CoinPack(this.id, this.amount, this.price, {this.bonus = 0, this.tag});
  final String id;
  final int amount;
  final String price;
  final int bonus;
  final String? tag;
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

  static const unitPacks = [
    CoinPack('units_500', 500, '0.99\$'),
    CoinPack('units_1200', 1200, '1.99\$', bonus: 100),
    CoinPack('units_3500', 3500, '4.99\$', bonus: 500, tag: 'الأكثر شراءً'),
    CoinPack('units_8000', 8000, '9.99\$', bonus: 1500),
    CoinPack('units_18000', 18000, '19.99\$', bonus: 4000),
    CoinPack('units_50000', 50000, '49.99\$', bonus: 15000, tag: 'أفضل قيمة'),
  ];

  static const starPacks = [
    CoinPack('stars_50', 50, '0.99\$'),
    CoinPack('stars_120', 120, '1.99\$', bonus: 10),
    CoinPack('stars_350', 350, '4.99\$', bonus: 50, tag: 'الأكثر شراءً'),
    CoinPack('stars_800', 800, '9.99\$', bonus: 150),
  ];

  static List<CoinPack> get allPacks => [...unitPacks, ...starPacks];

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

  CardBackStyle get cardBack => cardBacks.firstWhere((b) => b.id == (_me?.backId ?? 'orange'), orElse: () => cardBacks.first);
  TableStyle get table => tables.firstWhere((t) => t.id == (_me?.tableId ?? 'cream'), orElse: () => tables.first);

  bool owns(String id) => (_me?.owned ?? const ['orange', 'cream']).contains(id);
  bool inUse(String id) => id == cardBack.id || id == table.id;

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

  Future<String?> useBack(String id) => _do('/store/use', {'id': id});

  Future<String?> useTable(String id) => _do('/store/use', {'id': id});

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
