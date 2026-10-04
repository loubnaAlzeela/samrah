// Signing in with a phone number (an SMS code through Twilio Verify) or with Google (an ID token from the app's
// Google sign-in). Both link to the current account when the player is signed in, or sign in to the account
// they were linked to before (on a new phone).
//
// Ready once the environment holds the keys:
//   Phone:  TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SID
//   Google: GOOGLE_CLIENT_IDS (the app's OAuth client ids, comma separated)
import { db } from './data/db.ts';
import { type User, createGuest, newSession } from './accounts.ts';
import { cleanPhone, fail } from './util.ts';

export const phoneReady = () => !!(process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN && process.env.TWILIO_VERIFY_SID);
export const googleReady = () => !!process.env.GOOGLE_CLIENT_IDS;

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

function attach(current: User | null, kind: 'phone' | 'google', key: string, name: unknown): { user: User; token: string | null; linked: boolean } {
  const index = kind === 'phone' ? db.data.phones : db.data.google;
  const ownerId = index[key];
  if (current) {
    if (ownerId && ownerId !== current.id) fail(kind === 'phone' ? 'phoneTaken' : 'googleTaken', 409);
    if (kind === 'phone') {
      if (current.phone) delete db.data.phones[current.phone];
      current.phone = key;
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
  else user.googleId = key;
  index[key] = user.id;
  db.touch();
  return { user, token, linked: false };
}
