import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS, SPEED_SECONDS, mergeSettings } from '../src/index.ts';

describe('mergeSettings (untrusted input)', () => {
  it('defaults: private, chat on, kick off, normal speed, 41, level 1', () => {
    expect(DEFAULT_SETTINGS).toEqual({ visibility: 'private', chat: true, kick: false, noLeave: false, speed: 'normal', target: 41, minLevel: 1, voice: false, players: 4 });
  });
  it('speeds map to 45 / 30 / 15 seconds', () => expect(SPEED_SECONDS).toEqual({ slow: 45, normal: 30, fast: 15 }));
  it('applies a valid partial patch', () => {
    expect(mergeSettings(DEFAULT_SETTINGS, { speed: 'fast', target: 61, visibility: 'public', kick: true, minLevel: 7 }, 'tarneeb')).toMatchObject({
      speed: 'fast',
      target: 61,
      visibility: 'public',
      kick: true,
      minLevel: 7,
    });
  });
  it('rejects bad values and unknown keys', () => {
    for (const bad of [{ speed: 'warp' }, { target: 50 }, { chat: 'yes' }, { minLevel: 0 }, { minLevel: 2.5 }, { minLevel: 51 }, { visibility: 'secret' }, { owner: 'me' }, null, 'x'])
      expect(mergeSettings(DEFAULT_SETTINGS, bad, 'tarneeb')).toBeNull();
  });
  it('syrian41 forces target 41', () => expect(mergeSettings(DEFAULT_SETTINGS, { target: 61 }, 'syrian41')!.target).toBe(41));
});
