import { type ReactNode, useLayoutEffect, useRef, useState } from 'react';

/** Design canvas of layout-v2 (390 wide, 844 tall minus the 47px status-bar area). */
export const STAGE_W = 390;
export const STAGE_H = 797;
const MAX_SCALE = 1.25;

/**
 * Renders children on a fixed 390x797 canvas (designer coordinates) scaled to fit the viewport inside the
 * safe area, centred horizontally. Pure presentation: no game logic.
 */
export function Stage({ children, className }: { children: ReactNode; className?: string }) {
  const outer = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useLayoutEffect(() => {
    const el = outer.current;
    if (!el) return;
    const measure = () => {
      const cs = getComputedStyle(el);
      const w = el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
      const h = el.clientHeight - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
      setScale(Math.max(0.5, Math.min(w / STAGE_W, h / STAGE_H, MAX_SCALE)));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  return (
    <div className="stage-outer" ref={outer}>
      <div className="stage-box" style={{ width: STAGE_W * scale, height: STAGE_H * scale }}>
        <div className={`stage ${className ?? ''}`} style={{ transform: `scale(${scale})` }}>
          {children}
        </div>
      </div>
    </div>
  );
}
