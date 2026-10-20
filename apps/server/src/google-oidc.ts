// Verifies the Google-signed OIDC bearer token Pub/Sub attaches to a push notification (Google Play's Real-Time
// Developer Notifications arrive this way): RS256 against Google's own public keys, issuer, audience and expiry.
// Same shape as Apple's identity-token check in auth-providers.ts (checkAppleToken) — fetch the provider's JWKS by
// `kid`, cache it for an hour, verify.
import { createPublicKey, verify } from 'node:crypto';

interface GoogleJwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
}

let cached: { at: number; keys: GoogleJwk[] } | null = null;

async function googleOidcKey(kid: string): Promise<GoogleJwk | undefined> {
  const fresh = cached && Date.now() - cached.at < 3600000;
  if (!fresh || !cached!.keys.some((k) => k.kid === kid)) {
    const res = await fetch('https://www.googleapis.com/oauth2/v3/certs');
    if (!res.ok) return undefined;
    cached = { at: Date.now(), keys: ((await res.json()) as { keys: GoogleJwk[] }).keys };
  }
  return cached!.keys.find((k) => k.kid === kid);
}

/** Checks a Google-issued OIDC bearer token: signature, issuer, audience and expiry. Returns its `email` (the
 * service account Pub/Sub used to sign the push) on success, or `null` on any failure. Never throws. */
export async function verifyGoogleOidcToken(token: string, audience: string): Promise<string | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [h, p, s] = parts as [string, string, string];
    const json = (x: string) => JSON.parse(Buffer.from(x, 'base64url').toString('utf8'));
    const header = json(h) as { alg?: string; kid?: string };
    const payload = json(p) as { iss?: string; aud?: string; exp?: number; email?: string };
    if (header.alg !== 'RS256' || !header.kid) return null;
    const jwk = await googleOidcKey(header.kid);
    if (!jwk) return null;
    const ok = verify('RSA-SHA256', Buffer.from(`${h}.${p}`), createPublicKey({ key: { kty: jwk.kty, n: jwk.n, e: jwk.e }, format: 'jwk' }), Buffer.from(s, 'base64url'));
    if (!ok) return null;
    if (payload.iss !== 'https://accounts.google.com' && payload.iss !== 'accounts.google.com') return null;
    if (payload.aud !== audience) return null;
    if ((payload.exp ?? 0) * 1000 < Date.now()) return null;
    return payload.email ?? null;
  } catch {
    return null;
  }
}
