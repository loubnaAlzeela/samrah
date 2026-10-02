// The store's state: the two wallets («وحدات» / «نجوم»), what the player owns and
// what is in use (card back, table). DEMO ONLY — held in memory and reset on every
// launch; there are no accounts or payments yet (design/layout-v3.md §9-10). When
// the server gets accounts, balances and ownership move there and this becomes a
// thin cache of what it says.
import 'package:flutter/material.dart';

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

/// A pack of currency bought with real money (prices are placeholders).
class CoinPack {
  const CoinPack(this.amount, this.price, {this.bonus = 0, this.tag});
  final int amount;
  final String price;
  final int bonus;
  final String? tag;
}

class Store extends ChangeNotifier {
  Store._();
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
    CoinPack(500, '0.99\$'),
    CoinPack(1200, '1.99\$', bonus: 100),
    CoinPack(3500, '4.99\$', bonus: 500, tag: 'الأكثر شراءً'),
    CoinPack(8000, '9.99\$', bonus: 1500),
    CoinPack(18000, '19.99\$', bonus: 4000),
    CoinPack(50000, '49.99\$', bonus: 15000, tag: 'أفضل قيمة'),
  ];

  static const starPacks = [
    CoinPack(50, '0.99\$'),
    CoinPack(120, '1.99\$', bonus: 10),
    CoinPack(350, '4.99\$', bonus: 50, tag: 'الأكثر شراءً'),
    CoinPack(800, '9.99\$', bonus: 150),
  ];

  /// Gold membership: price in «نجوم», for 30 days.
  static const vipPrice = 300;
  static const dailyGift = 100;

  // demo balances so the store and the competitions can be tried end to end
  int units = 20000;
  int stars = 50;
  bool vip = false;
  bool giftClaimed = false;

  final Set<String> _owned = {'orange', 'cream'};
  String _backId = 'orange';
  String _tableId = 'cream';

  CardBackStyle get cardBack => cardBacks.firstWhere((b) => b.id == _backId);
  TableStyle get table => tables.firstWhere((t) => t.id == _tableId);

  bool owns(String id) => _owned.contains(id);
  bool inUse(String id) => id == _backId || id == _tableId;

  /// Spends [price] «وحدات» on item [id]; false when the balance is short.
  bool buy(String id, int price) {
    if (owns(id) || units < price) return false;
    units -= price;
    _owned.add(id);
    notifyListeners();
    return true;
  }

  /// Takes [amount] «وحدات» (entry fees, competition prizes); false when short.
  bool spend(int amount) {
    if (amount < 0 || units < amount) return false;
    units -= amount;
    notifyListeners();
    return true;
  }

  void earn(int amount) {
    if (amount <= 0) return;
    units += amount;
    notifyListeners();
  }

  /// Stars won (challenge rewards).
  void earnStars(int amount) {
    if (amount <= 0) return;
    stars += amount;
    notifyListeners();
  }

  void useBack(String id) {
    if (!owns(id)) return;
    _backId = id;
    notifyListeners();
  }

  void useTable(String id) {
    if (!owns(id)) return;
    _tableId = id;
    notifyListeners();
  }

  bool buyVip() {
    if (vip || stars < vipPrice) return false;
    stars -= vipPrice;
    vip = true;
    _owned.addAll([for (final b in cardBacks) if (b.vipOnly) b.id, for (final t in tables) if (t.vipOnly) t.id]);
    notifyListeners();
    return true;
  }

  /// Members get the gift twice over.
  int get giftAmount => vip ? dailyGift * 2 : dailyGift;

  void claimGift() {
    if (giftClaimed) return;
    units += giftAmount;
    giftClaimed = true;
    notifyListeners();
  }
}
