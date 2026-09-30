import { soundOn } from './net.ts';

/**
 * Every sound in the game is synthesized with the Web Audio API — no audio files, no licensed samples.
 * Keeps the app small and avoids any rights question. `SOUND_PLANS` is pure data (frequency/duration per
 * event) so it can be unit-tested without a real AudioContext; `playSound` is the only part that touches audio.
 */
export type SoundEvent = 'deal' | 'cardPlay' | 'trickWin' | 'bid' | 'pass' | 'timerWarning' | 'gameWin' | 'gameLose';

export interface ToneStep {
  /** frequency in Hz */
  freq: number;
  /** start offset from the moment the sound is triggered, in seconds */
  at: number;
  /** duration in seconds */
  dur: number;
  type: OscillatorType;
  /** peak gain, 0..1 */
  peak: number;
}

/** One short, low-key tone (or a tiny sequence) per event. Kept quiet and brief on purpose (mobile speakers). */
export const SOUND_PLANS: Record<SoundEvent, ToneStep[]> = {
  deal: [
    { freq: 520, at: 0, dur: 0.09, type: 'triangle', peak: 0.12 },
    { freq: 660, at: 0.06, dur: 0.12, type: 'triangle', peak: 0.12 },
  ],
  cardPlay: [{ freq: 900, at: 0, dur: 0.045, type: 'square', peak: 0.05 }],
  trickWin: [
    { freq: 660, at: 0, dur: 0.09, type: 'sine', peak: 0.16 },
    { freq: 880, at: 0.08, dur: 0.14, type: 'sine', peak: 0.16 },
  ],
  bid: [{ freq: 740, at: 0, dur: 0.08, type: 'triangle', peak: 0.12 }],
  pass: [{ freq: 330, at: 0, dur: 0.09, type: 'triangle', peak: 0.1 }],
  timerWarning: [{ freq: 880, at: 0, dur: 0.07, type: 'square', peak: 0.14 }],
  gameWin: [
    { freq: 523, at: 0, dur: 0.16, type: 'triangle', peak: 0.15 },
    { freq: 659, at: 0.11, dur: 0.16, type: 'triangle', peak: 0.15 },
    { freq: 784, at: 0.22, dur: 0.16, type: 'triangle', peak: 0.15 },
    { freq: 1047, at: 0.33, dur: 0.22, type: 'triangle', peak: 0.15 },
  ],
  gameLose: [
    { freq: 392, at: 0, dur: 0.18, type: 'sine', peak: 0.12 },
    { freq: 330, at: 0.12, dur: 0.18, type: 'sine', peak: 0.12 },
    { freq: 262, at: 0.24, dur: 0.26, type: 'sine', peak: 0.12 },
  ],
};

export function planFor(event: SoundEvent): ToneStep[] {
  return SOUND_PLANS[event];
}

// ---------------------------------------------------------------------------------------------------------
// Audio engine. Browsers refuse to start an AudioContext before a user gesture, so `primeAudio()` must run
// from a real click/tap handler — call it once, anywhere early (App.tsx does it on the first pointerdown).
let ctx: AudioContext | null = null;
let primed = false;

export function primeAudio() {
  if (primed) return;
  primed = true;
  const Ctor = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return;
  try {
    ctx = new Ctor();
    if (ctx.state === 'suspended') void ctx.resume();
  } catch {
    ctx = null;
  }
}

function scheduleTone(c: AudioContext, step: ToneStep) {
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = step.type;
  osc.frequency.value = step.freq;
  const t0 = c.currentTime + step.at;
  gain.gain.setValueAtTime(0, t0);
  gain.gain.linearRampToValueAtTime(step.peak, t0 + 0.008);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + step.dur);
  osc.connect(gain).connect(c.destination);
  osc.start(t0);
  osc.stop(t0 + step.dur + 0.02);
}

/** Play one event's plan, unless the player muted sound or the browser has no Web Audio support. Never throws. */
export function playSound(event: SoundEvent) {
  if (!soundOn()) return;
  if (!primed) primeAudio();
  if (!ctx) return;
  try {
    if (ctx.state === 'suspended') void ctx.resume();
    for (const step of SOUND_PLANS[event]) scheduleTone(ctx, step);
  } catch {
    /* audio is a nice-to-have; never break the game over it */
  }
}
