import { signed } from '../i18n.ts';

/** A number with Western digits; negatives use U+2212 inside <bdi dir="ltr"> so the sign never flips in RTL text. */
export function Num({ value, plus = false, className }: { value: number; plus?: boolean; className?: string }) {
  return (
    <bdi dir="ltr" className={`num ${value < 0 ? 'neg' : ''} ${className ?? ''}`}>
      {signed(value, plus)}
    </bdi>
  );
}
