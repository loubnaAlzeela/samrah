// Bottom nav — 5 tabs, home raised per design/layout-v3.md §8.
// Order (right to left, matching RTL layout): المتجر، الألعاب، الرئيسية، الأندية، التحديات.
import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.index, required this.onTap, this.challengeBadge = 0, this.clubsLocked = true});
  final int index;
  final ValueChanged<int> onTap;

  /// Finished challenges whose prize is waiting; no badge at 0.
  final int challengeBadge;

  /// The clubs tab carries a small lock until they open.
  final bool clubsLocked;

  static const _items = [
    (Icons.storefront_outlined, 'المتجر'),
    (Icons.style_outlined, 'الألعاب'),
    (Icons.home_filled, 'الرئيسية'),
    (Icons.shield_outlined, 'الأندية'),
    (Icons.emoji_events_outlined, 'المسابقات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: const BoxDecoration(
        color: SamrahColors.surface,
        border: Border(top: BorderSide(color: SamrahColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _items.length; i++) _item(i),
        ],
      ),
    );
  }

  Widget _item(int i) {
    final (icon, label) = _items[i];
    final selected = i == index;
    final isHome = i == 2;
    final color = selected ? SamrahColors.selectedBg : SamrahColors.textMuted;

    final iconWidget = isHome
        ? Container(
            width: 54,
            height: 54,
            transform: Matrix4.translationValues(0, -14, 0),
            decoration: BoxDecoration(
              color: SamrahColors.bg,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? SamrahColors.selectedBg : SamrahColors.line, width: 2),
            ),
            child: Icon(icon, color: color, size: 24),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 24),
              if (i == 3 && clubsLocked)
                const Positioned(right: -2, top: -2, child: Icon(Icons.lock, size: 12, color: SamrahColors.textMuted)),
              if (false && i == 4 && challengeBadge > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: SamrahColors.suitRed, shape: BoxShape.circle),
                    child: Text('$challengeBadge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          );

    return InkWell(
      onTap: () => onTap(i),
      child: SizedBox(
        width: 70,
        height: 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10.5, height: 1, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
