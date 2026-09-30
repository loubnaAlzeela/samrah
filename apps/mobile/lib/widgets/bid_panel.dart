// Bidding window over the table: «اختر الطلبة», a grid of every bid (7..13,
// or 2..13 in Syrian 41) with the ones below the server's `minBid` disabled,
// and «تمرير» underneath (Tarneeb only). Neutral buttons — brass stays for
// the one primary action per screen.
import 'package:flutter/material.dart';

import '../theme/samrah_theme.dart';

class BidPanel extends StatelessWidget {
  const BidPanel({super.key, required this.minBid, required this.syrian, required this.onBid, required this.onPass});

  final int? minBid;
  final bool syrian;
  final ValueChanged<int> onBid;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    final first = syrian ? 2 : 7;
    final min = minBid ?? first;
    final cols = syrian ? 4 : 3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var b = first; b <= 13; b++) _BidButton(value: b, enabled: b >= min, kaboot: b == 13 && !syrian, onTap: () => onBid(b)),
              // keep the grid left-aligned in full rows
              for (var i = 0; i < (cols - (14 - first) % cols) % cols; i++) const SizedBox(width: 46, height: 40),
            ],
          ),
        ),
        if (!syrian) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: SamrahColors.surface2,
                foregroundColor: SamrahColors.text,
                side: const BorderSide(color: SamrahColors.fieldBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: onPass,
              child: const Text('تمرير'),
            ),
          ),
        ],
      ],
    );
  }
}

class _BidButton extends StatelessWidget {
  const _BidButton({required this.value, required this.enabled, required this.kaboot, required this.onTap});
  final int value;
  final bool enabled;
  final bool kaboot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? SamrahColors.surface2 : SamrahColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: enabled ? SamrahColors.fieldBorder : SamrahColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 46,
          height: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: enabled ? SamrahColors.text : SamrahColors.disabledText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                  decorationColor: SamrahColors.disabledText,
                ),
              ),
              if (kaboot) const Text('كبوت', style: TextStyle(color: SamrahColors.textMuted, fontSize: 8, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
