/// A playing card as the wire protocol encodes it: `${suit}${rank}`, e.g.
/// "H14" = Ace of hearts, "S10" = ten of spades (see
/// packages/rules/src/cards.ts `card()`/`suitOf()`/`rankOf()`).
library;

enum CardSuit { spades, hearts, diamonds, clubs }

const Map<String, CardSuit> _suitByCode = {
  'S': CardSuit.spades,
  'H': CardSuit.hearts,
  'D': CardSuit.diamonds,
  'C': CardSuit.clubs,
};

const Map<CardSuit, String> _suitSymbol = {
  CardSuit.spades: '♠',
  CardSuit.hearts: '♥',
  CardSuit.diamonds: '♦',
  CardSuit.clubs: '♣',
};

const Map<CardSuit, String> _suitCode = {
  CardSuit.spades: 'S',
  CardSuit.hearts: 'H',
  CardSuit.diamonds: 'D',
  CardSuit.clubs: 'C',
};

/// Arabic suit names.
const Map<CardSuit, String> suitNameAr = {
  CardSuit.spades: 'بستوني',
  CardSuit.hearts: 'قلب',
  CardSuit.diamonds: 'ديناري',
  CardSuit.clubs: 'سباتي',
};

/// Display order for the hand: trump
/// suit first once declared, then ♠ ♥ ♣ ♦ (alternating colours), high to low.
/// [power] replaces the plain rank order inside a suit (Baloot: 10 above K).
/// [suitOrder] replaces the whole suit order (187: ♥ ♦ ♠ ♣ with the trump first).
List<String> sortForDisplay(List<String> hand, String? trump, {int Function(String card)? power, List<String>? suitOrder}) {
  const base = ['S', 'H', 'C', 'D'];
  final order = suitOrder ?? (trump != null ? [trump, ...base.where((s) => s != trump)] : base);
  final sorted = [...hand];
  sorted.sort((a, b) {
    final bySuit = order.indexOf(a[0]) - order.indexOf(b[0]);
    if (bySuit != 0) return bySuit;
    if (power != null) return power(b) - power(a);
    return int.parse(b.substring(1)) - int.parse(a.substring(1));
  });
  return sorted;
}

class GameCard {
  final CardSuit suit;
  final int rank; // 2..14 (11=J, 12=Q, 13=K, 14=A)
  /// The original wire code, e.g. "H14" — send this straight back in a `play` message.
  final String code;

  const GameCard._(this.suit, this.rank, this.code);

  factory GameCard.parse(String wire) {
    final suit = _suitByCode[wire[0]];
    final rank = int.tryParse(wire.substring(1));
    if (suit == null || rank == null || rank < 2 || rank > 14) {
      throw FormatException('bad card code: $wire');
    }
    return GameCard._(suit, rank, wire);
  }

  bool get isRed => suit == CardSuit.hearts || suit == CardSuit.diamonds;

  String get rankLabel => switch (rank) {
        14 => 'A',
        13 => 'K',
        12 => 'Q',
        11 => 'J',
        _ => '$rank',
      };

  String get suitSymbol => _suitSymbol[suit]!;
  String get suitCode => _suitCode[suit]!;

  @override
  String toString() => code;
}

/// Parses a suit letter from a server message (e.g. `trump`), or null.
CardSuit? suitFromCode(String? c) => c == null ? null : _suitByCode[c];

/// Suit symbol/name straight from a wire suit letter ('H'/'D'/'S'/'C'),
/// without needing a full card code — used for the trump chip/picker.
String suitSymbolFromCode(String c) => _suitByCode[c] != null ? _suitSymbol[_suitByCode[c]]! : c;
String suitNameArFromCode(String c) => _suitByCode[c] != null ? suitNameAr[_suitByCode[c]]! : c;
