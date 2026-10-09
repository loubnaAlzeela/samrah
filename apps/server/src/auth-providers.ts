// Signing in with Google (an ID token from the app's Google sign-in) or with Apple (an identity token from Sign in
// with Apple): the only two ways in. A new player's account is made on the first successful sign-in. Signed in already,
// either one is linked to the current account instead; signed out, it signs in to the account it was linked to.
//
// Ready once the environment holds the keys:
//   Google: GOOGLE_CLIENT_IDS (the app's OAuth client ids, comma separated)
//   Apple:  signing in needs no secret; the token's audience must be APPLE_BUNDLE_ID (default com.samrah.app).
//           To revoke the Apple sign-in when an account is deleted (App Store rule), also APPLE_TEAM_ID,
//           APPLE_KEY_ID and APPLE_PRIVATE_KEY (the .p8 key: PEM text, with \n for the line breaks, or base64 of it).
import { createPrivateKey, createPublicKey, sign, verify } from 'node:crypto';
import { db } from './data/db.ts';
import { type User, createAccount, newSession } from './accounts.ts';
import { fail } from './util.ts';

export const googleReady = () => !!process.env.GOOGLE_CLIENT_IDS;
export const appleReady = () => true;

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

export async function signInWithApple(current: User | null, idToken: unknown, name: unknown, authorizationCode?: unknown) {
  if (typeof idToken !== 'string' || idToken.length > 4096) fail('badToken');
  const t = await checkAppleToken(idToken as string);
  const out = attach(current, 'apple', t.sub, name);
  // Apple's code is traded for the refresh token that deleting the account must revoke; sign-in works without it
  if (typeof authorizationCode === 'string' && authorizationCode.length < 2000 && appleRevokable()) {
    const refresh = await appleRefreshToken(authorizationCode);
    if (refresh) {
      out.user.appleRefreshToken = refresh;
      db.touch();
    }
  }
  return out;
}

// ── revoking the Apple sign-in (when the account is deleted) ─────────────────

const appleRevokable = () => !!(process.env.APPLE_TEAM_ID && process.env.APPLE_KEY_ID && process.env.APPLE_PRIVATE_KEY);
const appleClientId = () => process.env.APPLE_BUNDLE_ID || 'com.samrah.app';

/** The .p8 key from the environment: PEM text (\n allowed for line breaks) or base64 of it. */
function applePem(): string {
  const raw = process.env.APPLE_PRIVATE_KEY!.trim().replace(/\\n/g, '\n');
  return raw.includes('BEGIN') ? raw : Buffer.from(raw, 'base64').toString('utf8');
}

/** Apple's "client secret": a short ES256 token signed with our key. */
function appleClientSecret(): string {
  const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${enc({ alg: 'ES256', kid: process.env.APPLE_KEY_ID, typ: 'JWT' })}.${enc({
    iss: process.env.APPLE_TEAM_ID,
    iat: now,
    exp: now + 300,
    aud: 'https://appleid.apple.com',
    sub: appleClientId(),
  })}`;
  const sig = sign('sha256', Buffer.from(unsigned), { key: createPrivateKey(applePem()), dsaEncoding: 'ieee-p1363' });
  return `${unsigned}.${sig.toString('base64url')}`;
}

async function appleRefreshToken(code: string): Promise<string | null> {
  try {
    const res = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: appleClientId(), client_secret: appleClientSecret(), code, grant_type: 'authorization_code' }),
    });
    if (!res.ok) {
      console.error('[apple] token exchange failed', res.status);
      return null;
    }
    return ((await res.json()) as { refresh_token?: string }).refresh_token ?? null;
  } catch (e) {
    console.error('[apple] token exchange failed', e);
    return null;
  }
}

/** Tells Apple the player has left (account deletion). Best effort: the deletion itself never waits on it or fails by it. */
export async function revokeAppleSignIn(refreshToken: string | null) {
  if (!refreshToken || !appleRevokable()) return;
  try {
    const res = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: appleClientId(), client_secret: appleClientSecret(), token: refreshToken, token_type_hint: 'refresh_token' }),
    });
    if (!res.ok) console.error('[apple] revoke failed', res.status);
  } catch (e) {
    console.error('[apple] revoke failed', e);
  }
}

function attach(current: User | null, kind: 'google' | 'apple', key: string, name: unknown): { user: User; token: string | null; linked: boolean } {
  const index = kind === 'google' ? db.data.google : db.data.apple;
  const ownerId = index[key];
  if (current) {
    if (ownerId && ownerId !== current.id) fail(kind === 'google' ? 'googleTaken' : 'appleTaken', 409);
    if (kind === 'apple') {
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
  // the first sign-in with this Google / Apple account: the player's account is made now
  const { user, token } = createAccount(name, kind, key);
  return { user, token, linked: false };
}
