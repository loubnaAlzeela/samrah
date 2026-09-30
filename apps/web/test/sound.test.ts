import { describe, expect, it } from 'vitest';
import { SOUND_PLANS, type SoundEvent, planFor } from '../src/sound.ts';

const EVENTS: SoundEvent[] = ['deal', 'cardPlay', 'trickWin', 'bid', 'pass', 'timerWarning', 'gameWin', 'gameLose'];

describe('sound plans (pure data, no AudioContext needed)', () => {
  it('every required event has a plan with at least one tone', () => {
    for (const e of EVENTS) {
      expect(SOUND_PLANS[e]).toBeDefined();
      expect(SOUND_PLANS[e].length).toBeGreaterThan(0);
    }
  });

  it('every tone step is audible and short (mobile speakers, no licensed samples)', () => {
    for (const e of EVENTS) {
      for (const step of planFor(e)) {
        expect(step.freq).toBeGreaterThan(80); // audible range
        expect(step.freq).toBeLessThan(2000);
        expect(step.at).toBeGreaterThanOrEqual(0);
        expect(step.dur).toBeGreaterThan(0);
        expect(step.dur).toBeLessThan(0.5); // short, not a full jingle
        expect(step.peak).toBeGreaterThan(0);
        expect(step.peak).toBeLessThanOrEqual(0.3); // quiet by default
      }
    }
  });

  it('multi-tone plans play in order (each step starts no earlier than the previous)', () => {
    for (const e of EVENTS) {
      const steps = planFor(e);
      for (let i = 1; i < steps.length; i++) expect(steps[i].at).toBeGreaterThanOrEqual(steps[i - 1].at);
    }
  });

  it('gameWin sounds distinctly different from gameLose (not the same tones)', () => {
    const win = planFor('gameWin').map((s) => s.freq);
    const lose = planFor('gameLose').map((s) => s.freq);
    expect(win).not.toEqual(lose);
    // win trends upward (resolves "up"), lose trends downward
    expect(win[win.length - 1]).toBeGreaterThan(win[0]);
    expect(lose[lose.length - 1]).toBeLessThan(lose[0]);
  });

  it('bid and pass are distinct tones', () => {
    expect(planFor('bid')[0].freq).not.toBe(planFor('pass')[0].freq);
  });
});
