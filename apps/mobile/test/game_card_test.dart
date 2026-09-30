// Card-code parsing (rank label + suit color) drives what the player reads
// off their hand — worth a direct test rather than trusting it by eye.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_card.dart';

void main() {
  test('parses rank and suit from the wire code', () {
    final ace = GameCard.parse('H14');
    expect(ace.suit, CardSuit.hearts);
    expect(ace.rank, 14);
    expect(ace.rankLabel, 'A');
    expect(ace.isRed, isTrue);

    final ten = GameCard.parse('S10');
    expect(ten.suit, CardSuit.spades);
    expect(ten.rankLabel, '10');
    expect(ten.isRed, isFalse);

    final jack = GameCard.parse('C11');
    expect(jack.rankLabel, 'J');
    expect(jack.isRed, isFalse);

    final queenDiamonds = GameCard.parse('D12');
    expect(queenDiamonds.rankLabel, 'Q');
    expect(queenDiamonds.isRed, isTrue);
  });

  test('rejects malformed codes', () {
    expect(() => GameCard.parse('X5'), throwsFormatException);
    expect(() => GameCard.parse('H1'), throwsFormatException);
    expect(() => GameCard.parse('H15'), throwsFormatException);
  });
}
