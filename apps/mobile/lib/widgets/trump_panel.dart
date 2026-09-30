// Trump-suit picker, shown to the bid winner after the auction closes: four
// square buttons, each the suit on a cream chip with its name underneath.
import 'package:flutter/material.dart';

import '../models/game_card.dart';
import '../theme/samrah_theme.dart';
import 'suit_icon.dart';

class TrumpPanel extends StatelessWidget {
  const TrumpPanel({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  static const _suits = ['H', 'D', 'S', 'C'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final s in _suits)
          Material(
            color: SamrahColors.surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: SamrahColors.fieldBorder)),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onPick(s),
              child: SizedBox(
                width: 46,
                height: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SuitChip(suit: s, size: 26),
                    const SizedBox(height: 4),
                    Text(suitNameArFromCode(s), style: const TextStyle(color: SamrahColors.text, fontSize: 10, height: 1)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
