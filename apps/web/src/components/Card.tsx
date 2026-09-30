import type { CSSProperties } from 'react';
import { type Card as CardId, type Suit, rankOf, suitOf } from '@lamma/rules';
import { SUIT_NAME, rankLabel } from '../i18n.ts';

/**
 * Isolated playing-card component (design direction 1 «ديوانية», design/card-spec.md).
 * All sizes derive from --cw (card width). Suits are SVG symbols, never Unicode glyphs (iOS renders them as emoji).
 */

const SUIT_SYMBOL_ID: Record<Suit, string> = { S: 'suit-s', H: 'suit-h', D: 'suit-d', C: 'suit-c' };

/** Mount once near the root. */
export function SuitSprite() {
  return (
    <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true" focusable="false">
      <symbol id="suit-s" viewBox="0 0 100 100">
        <path d="M50 4C62 25 95 40 95 62C95 76 84 85 72 85C63 85 56 80 53 75C54 84 58 91 67 97H33C42 91 46 84 47 75C44 80 37 85 28 85C16 85 5 76 5 62C5 40 38 25 50 4Z" />
      </symbol>
      <symbol id="suit-h" viewBox="0 0 100 100">
        <path d="M50 92C20 68 4 50 4 31C4 15 16 5 30 5C40 5 47 11 50 19C53 11 60 5 70 5C84 5 96 15 96 31C96 50 80 68 50 92Z" />
      </symbol>
      <symbol id="suit-d" viewBox="0 0 100 100">
        <path d="M50 2L88 50L50 98L12 50Z" />
      </symbol>
      <symbol id="suit-c" viewBox="0 0 100 100">
        <circle cx="50" cy="27" r="21" />
        <circle cx="26" cy="58" r="21" />
        <circle cx="74" cy="58" r="21" />
        <path d="M42 44H58L55 66C56 80 60 89 68 97H32C40 89 44 80 45 66Z" />
      </symbol>
    </svg>
  );
}

export function SuitIcon({ suit, className }: { suit: Suit; className?: string }) {
  return (
    <svg className={`suit-icon suit-${suit} ${className ?? ''}`} viewBox="0 0 100 100" aria-hidden="true" focusable="false">
      <use href={`#${SUIT_SYMBOL_ID[suit]}`} />
    </svg>
  );
}

/** Suit name + symbol in a cream chip (red on espresso is too weak, so the symbol sits on card colour). */
export function SuitLabel({ suit }: { suit: Suit }) {
  return (
    <span className="suit-label">
      {SUIT_NAME[suit]}{' '}
      <span className="suitchip">
        <SuitIcon suit={suit} />
      </span>
    </span>
  );
}

export type CardState = 'normal' | 'playable' | 'disabled' | 'selected';

interface CardProps {
  card?: CardId;
  /** face-down */
  back?: boolean;
  /** card width in px (drives every other dimension) */
  width: number;
  state?: CardState;
  onClick?: () => void;
  style?: CSSProperties;
  className?: string;
}

export function PlayingCard({ card, back, width, state = 'normal', onClick, style, className }: CardProps) {
  const vars = { '--cw': `${width}px`, ...style } as CSSProperties;
  if (back || !card) {
    return <div className={`pcard back ${className ?? ''}`} style={vars} role="img" aria-label="ورقة مقلوبة" />;
  }
  const suit = suitOf(card);
  const rank = rankOf(card);
  const label = rankLabel(rank);
  const face = rank >= 11 && rank <= 13;
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      className={`pcard face suit-${suit} rank-${rank} st-${state} ${face ? "court" : ""} ${className ?? ""}`}
      style={vars}
      role={onClick ? undefined : 'img'}
      aria-label={`${label} ${SUIT_NAME[suit]}`}
      aria-disabled={state === 'disabled' || undefined}
      onClick={onClick}
      type={onClick ? 'button' : undefined}
    >
      <span className="corner">
        <b className="rank">{label}</b>
        <SuitIcon suit={suit} className="corner-suit" />
      </span>
      {face ? (
        <span className="court-mark">
          <span className="court-letter">{label}</span>
          <SuitIcon suit={suit} className="court-suit" />
        </span>
      ) : (
        <SuitIcon suit={suit} className="pip" />
      )}
      {width >= 72 && (
        <span className="corner corner-2">
          <b className="rank">{label}</b>
          <SuitIcon suit={suit} className="corner-suit" />
        </span>
      )}
    </Tag>
  );
}
