// Small helpers shared by the account, club and competition modules.
import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

/** A refusal the API sends back as `{error: code}` with an HTTP status; the app turns the code into Arabic. */
export class ApiError extends Error {
  constructor(public status: number, public code: string, public extra?: Record<string, unknown>) {
    super(code);
  }
}

export const fail = (code: string, status = 400, extra?: Record<string, unknown>): never => {
  throw new ApiError(status, code, extra);
};

export const newSecret = (bytes = 24) => randomBytes(bytes).toString('base64url');

/** The players are in the Gulf and the Levant: days and weeks turn at midnight UTC+3. */
const ZONE_MS = 3 * 3600 * 1000;

/** `2026-10-03` for the local day of [t]. */
export function dayKey(t = Date.now()): string {
  return new Date(t + ZONE_MS).toISOString().slice(0, 10);
}

/** The week starts on Saturday: the key is the date of that Saturday. */
export function weekKey(t = Date.now()): string {
  const local = new Date(t + ZONE_MS);
  const back = (local.getUTCDay() + 1) % 7; // Saturday -> 0, Sunday -> 1, … Friday -> 6
  return new Date(local.getTime() - back * 86400000).toISOString().slice(0, 10);
}

/** Free text from a player: no control or direction-override characters, single spaces, at most [max] long. */
export function cleanText(x: unknown, max: number): string | null {
  if (typeof x !== 'string') return null;
  const t = x.replace(/[\u0000-\u0008\u000b-\u001f\u007f‎‏‪-‮⁦-⁩]/g, '').replace(/[ \t]+/g, ' ').trim();
  if (t.length === 0) return null;
  return t.slice(0, max);
}

export function hashPassword(pw: string): string {
  const salt = randomBytes(16);
  const hash = scryptSync(pw, salt, 32);
  return `scrypt$${salt.toString('base64url')}$${hash.toString('base64url')}`;
}

export function checkPassword(pw: string, stored: string | null): boolean {
  if (!stored) return false;
  const [kind, salt, hash] = stored.split('$');
  if (kind !== 'scrypt' || !salt || !hash) return false;
  const want = Buffer.from(hash, 'base64url');
  const got = scryptSync(pw, Buffer.from(salt, 'base64url'), want.length);
  return timingSafeEqual(want, got);
}

export const isEmail = (x: unknown): x is string => typeof x === 'string' && x.length <= 120 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(x);

/** A phone number in international form, e.g. +9665…; spaces and dashes are dropped. */
export function cleanPhone(x: unknown): string | null {
  if (typeof x !== 'string') return null;
  const p = x.replace(/[\s-]/g, '').replace(/^00/, '+');
  return /^\+[1-9]\d{7,14}$/.test(p) ? p : null;
}

/** Fisher–Yates with crypto-strength randomness is not needed here; Math.random is fine for seating. */
export function shuffle<T>(a: T[]): T[] {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
