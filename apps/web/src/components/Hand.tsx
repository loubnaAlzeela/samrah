import { useEffect, useState } from 'react';
import { type Card as CardId, type Suit, rankOf, suitOf } from '@lamma/rules';
import { PlayingCard, type CardState } from './Card.tsx';

const ORDER: Suit[] = ['S', 'H', 'C', 'D']; // alternate black/red (card-spec §2)

/** Sort for display: trump suit first (once declared), then ♠ ♥ ♣ ♦, high to low. */
export function sortForDisplay(hand: CardId[], trump: Suit | null): CardId[] {
  const order = trump ? [trump, ...ORDER.filter((s) => s !== trump)] : ORDER;
  return hand.slice().sort((a, b) => order.indexOf(suitOf(a)) - order.indexOf(suitOf(b)) || rankOf(b) - rankOf(a));
}

/** Hand strip on the 390 stage: left 6, right 6 -> 378 wide; cards 84x118 (layout-v2 §3). */
const STRIP_W = 378;
const CARD_W = 84;
const MAX_STEP = 40;

interface HandProps {
  cards: CardId[];
  trump: Suit | null;
  /** cards that may be played now; null = not my turn to play (no dimming, no lifting) */
  legal: CardId[] | null;
  onPlay: (c: CardId) => void;
}

/**
 * The player's hand: a flat row (no fan, no rotation), always dir="ltr" so each card covers the right side of
 * the previous one and the top-left index stays readable. Tap once to select, tap again to play (unchanged).
 */
export function Hand({ cards, trump, legal, onPlay }: HandProps) {
  const [selected, setSelected] = useState<CardId | null>(null);
  const sorted = sortForDisplay(cards, trump);
  const n = sorted.length;
  const step = n > 1 ? Math.min(MAX_STEP, (STRIP_W - CARD_W) / (n - 1)) : 0;
  const offset = (STRIP_W - (CARD_W + step * (n - 1))) / 2;

  useEffect(() => {
    if (selected && (!legal || !legal.includes(selected) || !cards.includes(selected))) setSelected(null);
  }, [legal, cards, selected]);

  return (
    <div className="hand" dir="ltr" aria-label={`ورقك: ${n} ورقة`}>
      {sorted.map((c, i) => {
        const canPlay = legal ? legal.includes(c) : false;
        const state: CardState = legal === null ? 'normal' : selected === c ? 'selected' : canPlay ? 'playable' : 'disabled';
        return (
          <PlayingCard
            key={c}
            card={c}
            width={CARD_W}
            state={state}
            className={`in-hand ${i === n - 1 ? 'last' : ''}`}
            style={{ left: `${offset + i * step}px`, zIndex: i }}
            onClick={() => {
              if (!legal || !canPlay) return;
              if (selected === c) {
                setSelected(null);
                onPlay(c);
              } else setSelected(c);
            }}
          />
        );
      })}
    </div>
  );
}
