// The mobile screens show a finished trick's winner from `turn` (lastTrick still holds the previous trick until
// the pause ends). Every trick game must therefore hand the turn to the trick's real winner at once, e.g. a trump
// played on another suit wins it.
import { describe, expect, it } from 'vitest';
import { type AnyGame, actAny, advanceAny, autoActionAny, balootTrickWinner, isTrixVariant, newAnyGame, trickWinner } from '../src/index.ts';
import { seeded } from './helpers.ts';

function winnerOf(g: AnyGame): number {
  const t = g.trick as { seat: number; card: string }[];
  if (g.variant === 'baloot') return balootTrickWinner(t as never, (g as unknown as { trump: never }).trump);
  if (isTrixVariant(g.variant)) return trickWinner(t as never, null);
  return trickWinner(t as never, (g as unknown as { trump: never }).trump);
}

describe('trickDone: turn = the trick winner', () => {
  for (const variant of ['tarneeb', 'syrian41', 'trix', 'baloot'] as const) {
    it(variant, () => {
      const r = seeded(77);
      let g = newAnyGame({ variant }, r);
      let checked = 0;
      let trumped = 0;
      for (let steps = 0; steps < 4000 && g.phase !== 'gameOver'; steps++) {
        if (g.phase === 'trickDone') {
          expect(g.turn).toBe(winnerOf(g));
          const trump = (g as { trump?: string | null }).trump;
          const t = g.trick as { seat: number; card: string }[];
          if (trump && t[0].card[0] !== trump && t.some((p) => p.card[0] === trump)) {
            expect(t.find((p) => p.seat === g.turn)!.card[0]).toBe(trump);
            trumped++;
          }
          checked++;
        }
        if (g.phase === 'trickDone' || g.phase === 'handOver') {
          g = advanceAny(g, r);
          continue;
        }
        // the Tarneeb autopilot always passes (redeal): open the auction with a 7 so tricks get played
        const opens = g.variant === 'tarneeb' && g.phase === 'bidding' && !(g as { highBid: unknown }).highBid;
        const res = actAny(g, g.turn, opens ? { type: 'bid', value: 7 } : autoActionAny(g, g.turn));
        if (!res.ok) throw new Error(res.error);
        g = res.state;
      }
      expect(checked).toBeGreaterThan(20);
      if (variant !== 'trix') expect(trumped).toBeGreaterThan(0);
    });
  }
});
