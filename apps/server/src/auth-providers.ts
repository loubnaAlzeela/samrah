// Signing in with a phone number (an SMS code through Twilio Verify), with Google (an ID token from the app's
// Google sign-in) or with Apple (an identity token from Sign in with Apple). All link to the current account when the player is signed in, or sign in to the account
// they were linked to before (on a new phone).
//
// Ready once the environment holds the keys:
//   Phone:  TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SID
//   Google: GOOGLE_CLIENT_IDS (the app's OAuth client ids, comma separated)
//   Apple:  needs no secret; the token's audience must be APPLE_BUNDLE_ID (default com.samrah.app)
import { createPublicKey, verify } from 'node:crypto';
import { db } from './data/db.ts';
import { type User, createGuest, newSession } from './accounts.ts';
import { cleanPhone, fail } from './util.ts';

export const phoneReady = () => !!(process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN && process.env.TWILIO_VERIFY_SID);
export const googleReady = () => !!process.env.GOOGLE_CLIENT_IDS;
export const appleReady = () => true;

async function twilio(path: string, form: Record<string, string>) {
  const sid = process.env.TWILIO_ACCOUNT_SID!;
  const res = await fetch(`https://verify.twilio.com/v2/Services/${process.env.TWILIO_VERIFY_SID}/${path}`, {
    method: 'POST',
    headers: {
      authorization: `Basic ${Buffer.from(`${sid}:${process.env.TWILIO_AUTH_TOKEN}`).toString('base64')}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(form),
  });
  return { ok: res.ok, status: res.status, body: (await res.json().catch(() => ({}))) as { status?: string } };
}

const lastCode = new Map<string, number>();

export async function sendPhoneCode(phoneArg: unknown) {
  if (!phoneReady()) fail('phoneOff', 503);
  const phone = cleanPhone(phoneArg) ?? fail('badPhone');
  if (Date.now() - (lastCode.get(phone) ?? 0) < 60000) fail('tooFast', 429);
  lastCode.set(phone, Date.now());
  const r = await twilio('Verifications', { To: phone, Channel: 'sms' });
  if (!r.ok) fail('smsFailed', 502);
}

/** Checks the code; links the phone to [current], or signs in to the account it belongs to (a new one if none). */
export async function verifyPhoneCode(current: User | null, phoneArg: unknown, code: unknown, name: unknown) {
  if (!phoneReady()) fail('phoneOff', 503);
  const phone = cleanPhone(phoneArg) ?? fail('badPhone');
  if (typeof code !== 'string' || !/^\d{4,10}$/.test(code)) fail('badCode');
  const r = await twilio('VerificationCheck', { To: phone, Code: code as string });
  if (!r.ok || r.body.status !== 'approved') fail('badCode', 401);
  return attach(current, 'phone', phone, name);
}

interface GoogleToken {
  aud: string;
  sub: string;
  email?: string;
  email_verified?: string | boolean;
  name?: string;
  exp: string;
}

export async function signInWithGoogle(current: User | null, idToken: unknown, name: unknown) {
  if (!googleReady()) fail('googleOff', 503);
  if (typeof idToken !== 'string' || idToken.length > 4096) fail('badToken');
  // Google checks the signature and expiry; we check the token was made for this app
  const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken as string)}`);
  if (!res.ok) fail('badToken', 401);
  const t = (await res.json()) as GoogleToken;
  const allowed = process.env.GOOGLE_CLIENT_IDS!.split(',').map((x) => x.trim());
  if (!allowed.includes(t.aud) || Number(t.exp) * 1000 < Date.now()) fail('badToken', 401);
  return attach(current, 'google', t.sub, name ?? t.name);
}

interface AppleJwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
}

let appleKeys: { at: number; keys: AppleJwk[] } | null = null;

async function appleKey(kid: string): Promise<AppleJwk | undefined> {
  const fresh = appleKeys && Date.now() - appleKeys.at < 3600000;
  if (!fresh || !appleKeys!.keys.some((k) => k.kid === kid)) {
    const res = await fetch('https://appleid.apple.com/auth/keys');
    if (!res.ok) fail('badToken', 502);
    appleKeys = { at: Date.now(), keys: ((await res.json()) as { keys: AppleJwk[] }).keys };
  }
  return appleKeys!.keys.find((k) => k.kid === kid);
}

/** Checks an Apple identity token (RS256 against Apple's public keys, issuer, audience, expiry) and answers its `sub`. */
export async function checkAppleToken(idToken: string): Promise<{ sub: string; name?: string }> {
  const parts = idToken.split('.');
  if (parts.length !== 3) fail('badToken', 401);
  const [h, p, s] = parts as [string, string, string];
  const json = (x: string) => JSON.parse(Buffer.from(x, 'base64url').toString('utf8'));
  let header: { alg?: string; kid?: string };
  let t: { iss?: string; aud?: string; sub?: string; exp?: number };
  try {
    header = json(h);
    t = json(p);
  } catch {
    fail('badToken', 401);
  }
  if (header!.alg !== 'RS256' || !header!.kid) fail('badToken', 401);
  const jwk = await appleKey(header!.kid!);
  if (!jwk) fail('badToken', 401);
  const ok = verify('RSA-SHA256', Buffer.from(`${h}.${p}`), createPublicKey({ key: { kty: jwk!.kty, n: jwk!.n, e: jwk!.e }, format: 'jwk' }), Buffer.from(s, 'base64url'));
  const aud = process.env.APPLE_BUNDLE_ID || 'com.samrah.app';
  if (!ok || t!.iss !== 'https://appleid.apple.com' || t!.aud !== aud || !t!.sub || (t!.exp ?? 0) * 1000 < Date.now()) fail('badToken', 401);
  return { sub: t!.sub! };
}

export async function signInWithApple(current: User | null, idToken: unknown, name: unknown) {
  if (typeof idToken !== 'string' || idToken.length > 4096) fail('badToken');
  const t = await checkAppleToken(idToken as string);
  return attach(current, 'apple', t.sub, name);
}

function attach(current: User | null, kind: 'phone' | 'google' | 'apple', key: string, name: unknown): { user: User; token: string | null; linked: boolean } {
  const index = kind === 'phone' ? db.data.phones : kind === 'google' ? db.data.google : db.data.apple;
  const ownerId = index[key];
  if (current) {
    if (ownerId && ownerId !== current.id) fail(kind === 'phone' ? 'phoneTaken' : kind === 'google' ? 'googleTaken' : 'appleTaken', 409);
    if (kind === 'phone') {
      if (current.phone) delete db.data.phones[current.phone];
      current.phone = key;
    } else if (kind === 'apple') {
      if (current.appleId) delete db.data.apple[current.appleId];
      current.appleId = key;
    } else {
      if (current.googleId) delete db.data.google[current.googleId];
      current.googleId = key;
    }
    index[key] = current.id;
    db.touch();
    return { user: current, token: null, linked: true };
  }
  const owner = ownerId ? db.data.users[ownerId] : undefined;
  if (owner) {
    if (owner.banned) fail('banned', 403);
    return { user: owner, token: newSession(owner), linked: false };
  }
  // a first sign-in with a phone or Google account that was never linked: a new account
  const { user, token } = createGuest(typeof name === 'string' && name.trim().length >= 2 ? name : 'لاعب');
  if (kind === 'phone') user.phone = key;
  else if (kind === 'apple') user.appleId = key;
  else user.googleId = key;
  index[key] = user.id;
  db.touch();
  return { user, token, linked: false };
}
