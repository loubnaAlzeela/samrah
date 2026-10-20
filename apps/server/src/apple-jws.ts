// Verifies an Apple-signed JWS (a StoreKit2 transaction, or an App Store Server Notification) end to end: the
// x5c certificate chain must lead to Apple's own pinned root, every certificate in it must carry Apple's marker
// extensions and be valid at the signing time, and the JWS signature itself must verify with the leaf key. Apple's
// REST APIs are reached over TLS with our own authenticated request, so a response fetched directly from them is
// already trustworthy without this — but App Store Server Notifications arrive as an unauthenticated POST to our
// own endpoint, so verifying the signature chain ourselves there is the only thing standing between us and anyone
// who can reach that URL. Ported from the 187 (Majlis187) api-server, which reviewed this pattern; see
// artifacts/api-server/src/lib/payments/apple.ts in that project.
import { X509Certificate, verify as cryptoVerify } from 'node:crypto';

/** Apple Root CA - G3 (valid until 2039), pinned. Source: https://www.apple.com/certificateauthority/ */
export const APPLE_ROOT_CA_G3_PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----
`;
export const APPLE_ROOT_CA_G3_SHA256 = '63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79';
if (new X509Certificate(APPLE_ROOT_CA_G3_PEM).fingerprint256 !== APPLE_ROOT_CA_G3_SHA256) {
  throw new Error('Pinned Apple root certificate does not match its fingerprint');
}

export class AppleVerificationError extends Error {}
const fail = (message: string): never => {
  throw new AppleVerificationError(message);
};

// DER of the Apple marker extensions: 1.2.840.113635.100.6.11.1 (leaf, "receipt signing") and 1.2.840.113635.100.6.2.1
// (intermediate, "WWDR"). Apple documents both as required on any chain that signs transactions and notifications.
const LEAF_OID = Buffer.from([0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x0b, 0x01]);
const INTERMEDIATE_OID = Buffer.from([0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x01]);

const b64urlJson = (part: string): Record<string, any> => {
  try {
    return JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
  } catch {
    return fail('malformed JWS');
  }
};

export type AppleJwsOptions = { roots?: string[]; now?: number };

/**
 * Verifies an Apple signed payload (a transaction or a server notification) END TO END and returns its claims:
 * ES256 only; the x5c chain must be leaf -> intermediate -> root with each certificate issued and signed by the next,
 * every certificate valid at the signing time, the root must be one of the pinned Apple roots, the leaf and the
 * intermediate must carry Apple's marker extensions, and the JWS signature must verify with the leaf key.
 * A self-signed or otherwise forged JWS fails at the root or signature step.
 */
export function verifyAppleJws(jws: string, options: AppleJwsOptions = {}): Record<string, any> {
  const roots = (options.roots ?? [APPLE_ROOT_CA_G3_PEM]).map((pem) => new X509Certificate(pem));
  const now = options.now ?? Date.now();
  const parts = typeof jws === 'string' ? jws.split('.') : [];
  if (parts.length !== 3 || parts.some((part) => !part)) return fail('malformed JWS');
  const header = b64urlJson(parts[0]);
  if (header.alg !== 'ES256') return fail('unsupported algorithm');
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3 || header.x5c.some((c: unknown) => typeof c !== 'string')) return fail('bad certificate chain');
  let chain: X509Certificate[];
  try {
    chain = header.x5c.map((der: string) => new X509Certificate(Buffer.from(der, 'base64')));
  } catch {
    return fail('unreadable certificate');
  }
  const [leaf, intermediate, root] = chain;

  if (!roots.some((pinned) => pinned.fingerprint256 === root.fingerprint256 && pinned.raw.equals(root.raw))) return fail('untrusted root certificate');
  if (!root.verify(root.publicKey) || !intermediate.checkIssued(root) || !intermediate.verify(root.publicKey) || !leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey))
    return fail('certificate chain does not verify');
  if (!leaf.raw.includes(LEAF_OID) || !intermediate.raw.includes(INTERMEDIATE_OID)) return fail('missing Apple certificate extension');

  const payload = b64urlJson(parts[1]);
  // Validate certificates at the time Apple signed (a stored transaction outlives the leaf), never in the future.
  const signedAt = typeof payload.signedDate === 'number' ? Math.min(payload.signedDate, now) : now;
  for (const cert of chain) {
    if (signedAt < Date.parse(cert.validFrom) || signedAt > Date.parse(cert.validTo)) return fail('certificate not valid at signing time');
  }
  const key = leaf.publicKey;
  if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') return fail('leaf key must be P-256');
  const ok = cryptoVerify('sha256', Buffer.from(`${parts[0]}.${parts[1]}`), { key, dsaEncoding: 'ieee-p1363' }, Buffer.from(parts[2], 'base64url'));
  if (!ok) return fail('bad signature');
  return payload;
}

export type AppleTransaction = {
  transactionId: string;
  productId: string;
  bundleId: string;
  environment: string;
  type?: string;
  appAccountToken?: string;
  revocationDate?: number;
  quantity?: number;
  signedDate?: number;
};

/** Verifies a transaction JWS and the facts we depend on. Throws AppleVerificationError with a reason on any mismatch. */
export function checkAppleTransaction(jws: string, expect: { bundleId: string; allowSandbox: boolean }, options: AppleJwsOptions = {}): AppleTransaction {
  const tx = verifyAppleJws(jws, options) as AppleTransaction;
  if (!expect.bundleId || tx.bundleId !== expect.bundleId) return fail('wrong bundle id');
  if (tx.environment !== 'Production' && !(tx.environment === 'Sandbox' && expect.allowSandbox)) return fail(`environment ${tx.environment} not accepted`);
  if (typeof tx.transactionId !== 'string' || !tx.transactionId || typeof tx.productId !== 'string') return fail('incomplete transaction');
  return tx;
}

export type AppleNotification = {
  notificationType: string;
  subtype?: string;
  data?: { bundleId?: string; environment?: string; signedTransactionInfo?: string };
};

/** Verifies an App Store Server Notification V2 envelope (`{signedPayload}`) and returns its claims. */
export function verifyAppleNotification(signedPayload: string, options: AppleJwsOptions = {}): AppleNotification {
  return verifyAppleJws(signedPayload, options) as AppleNotification;
}
