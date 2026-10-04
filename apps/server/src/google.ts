// Google service-account access tokens (OAuth 2 JWT bearer flow), for Firebase Cloud Messaging and the Google Play
// purchase checks. The key comes from GOOGLE_SERVICE_ACCOUNT_JSON: the JSON file Google gives for a service account,
// pasted as one environment variable (or base64 of it).
import { createSign } from 'node:crypto';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id?: string;
}

let account: ServiceAccount | null | undefined;

export function serviceAccount(): ServiceAccount | null {
  if (account !== undefined) return account;
  const raw = process.env.GOOGLE_SERVICE_ACCOUNT_JSON?.trim();
  account = null;
  if (raw) {
    try {
      const json = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
      const a = JSON.parse(json) as ServiceAccount;
      if (a.client_email && a.private_key) account = a;
    } catch {
      console.error('[google] GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON');
    }
  }
  return account;
}

const cache = new Map<string, { token: string; until: number }>();

/** An access token for [scope], cached until a minute before it expires. */
export async function googleAccessToken(scope: string): Promise<string> {
  const a = serviceAccount();
  if (!a) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON is not set');
  const hit = cache.get(scope);
  if (hit && hit.until > Date.now()) return hit.token;
  const now = Math.floor(Date.now() / 1000);
  const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned = `${enc({ alg: 'RS256', typ: 'JWT' })}.${enc({ iss: a.client_email, scope, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })}`;
  const sig = createSign('RSA-SHA256').update(unsigned).sign(a.private_key).toString('base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${sig}` }),
  });
  if (!res.ok) throw new Error(`google token: ${res.status} ${await res.text()}`);
  const body = (await res.json()) as { access_token: string; expires_in: number };
  cache.set(scope, { token: body.access_token, until: Date.now() + (body.expires_in - 60) * 1000 });
  return body.access_token;
}
