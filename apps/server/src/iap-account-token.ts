// A stable, non-secret identifier for in-app-purchase account binding: Apple StoreKit2's `appAccountToken` and
// Google Play's `obfuscatedAccountId` both want a value the app sets when a purchase starts and the store hands
// back unchanged when the purchase is verified, so the server can confirm the purchase was made *for this account*
// rather than a transaction id or purchase token that leaked or was replayed by a different account. Apple
// additionally requires the value to look like a UUID. Deriving it from the account id (instead of storing a
// random one) means `/me` can hand it to the app with no extra database field or migration, and payments.ts can
// recompute the same value to check a purchase against, with nothing secret to leak if it did.
import { createHash } from 'node:crypto';

export function iapAccountToken(userId: string): string {
  const h = createHash('sha256').update(`samrah:iap-account:${userId}`).digest();
  const b = Buffer.from(h.subarray(0, 16));
  b[6] = (b[6] & 0x0f) | 0x50; // version 5 (name-based, SHA-1/256 derived) — Apple only checks the UUID *shape*
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  const hex = b.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
