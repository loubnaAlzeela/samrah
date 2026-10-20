// Buying «وحدات» and «نجوم» with real money, through Google Play and the App Store. The app buys a product with
// the phone's store and sends the proof here; the server asks the store itself whether the purchase is real and
// paid, credits the wallet once per store transaction, and (Google) consumes it so it can be bought again.
//
// Ready once the environment holds the store keys:
//   Google Play: GOOGLE_SERVICE_ACCOUNT_JSON (a service account invited to the Play Console with "View financial
//                data" + "Manage orders"), GOOGLE_PLAY_PACKAGE (default com.samrah.app)
//   App Store:   APPLE_IAP_ISSUER_ID, APPLE_IAP_KEY_ID, APPLE_IAP_PRIVATE_KEY (the .p8 key, \n allowed),
//                APPLE_BUNDLE_ID (default com.samrah.app)
// IAP_TEST_MODE=1 accepts fake purchases on a development server (never when NODE_ENV=production).
//
// Every purchase is bound to the account that makes it (Apple's `appAccountToken`, Google's `obfuscatedAccountId`,
// both set by the app from `iapAccountToken(u.id)` — see iap-account-token.ts): without this, a purchase token or
// transaction id that leaked (logs, a proxy, a compromised device) could be redeemed into a different account than
// the one that paid for it — whichever account reaches /purchases first keeps the credit. A legacy app build that
// predates this check sends no binding at all; that is let through (nothing to compare), but a *present and wrong*
// binding always fails hard.
//
// apps/server/src/iap-webhooks.ts handles the store telling us *after the fact* that a purchase was refunded or
// revoked (App Store Server Notifications V2, Google Play RTDN) and calls [revokePurchase] here to claw the
// balance back; see that file for the one-time setup each store needs (a URL to register, nothing in code).
import { createSign } from 'node:crypto';
import { db } from './data/db.ts';
import { type User, OFFER, addBoost, credit, debit, offerView } from './accounts.ts';
import { googleAccessToken, serviceAccount } from './google.ts';
import { iapAccountToken } from './iap-account-token.ts';
import { checkAppleTransaction, AppleVerificationError } from './apple-jws.ts';
import { notify } from './social.ts';
import { fail } from './util.ts';

/** The products as set up in both stores (same ids), with what each one adds to the wallet (bonus included).
 * [offer] marks the one-time welcome offer: it also brings a booster and an emote (accounts.ts OFFER). */
export const PRODUCTS: Record<string, { currency: 'units' | 'stars'; amount: number; offer?: boolean }> = {
  units_500: { currency: 'units', amount: 500 },
  units_1200: { currency: 'units', amount: 1300 },
  units_3500: { currency: 'units', amount: 4000 },
  units_8000: { currency: 'units', amount: 9500 },
  units_18000: { currency: 'units', amount: 22000 },
  units_50000: { currency: 'units', amount: 65000 },
  units_100000: { currency: 'units', amount: 135000 },
  [OFFER.id]: { currency: 'units', amount: OFFER.units, offer: true },
  stars_50: { currency: 'stars', amount: 50 },
  stars_120: { currency: 'stars', amount: 130 },
  stars_350: { currency: 'stars', amount: 400 },
  stars_800: { currency: 'stars', amount: 950 },
};

const PACKAGE = () => process.env.GOOGLE_PLAY_PACKAGE || 'com.samrah.app';
const BUNDLE = () => process.env.APPLE_BUNDLE_ID || 'com.samrah.app';
const testMode = () => process.env.IAP_TEST_MODE === '1' && process.env.NODE_ENV !== 'production';

export function paymentsStatus() {
  return {
    android: !!serviceAccount(),
    ios: !!(process.env.APPLE_IAP_ISSUER_ID && process.env.APPLE_IAP_KEY_ID && process.env.APPLE_IAP_PRIVATE_KEY),
    test: testMode(),
    products: PRODUCTS,
  };
}

/** Checks a purchase with its store and credits it once. Returns what was added. */
export async function verifyPurchase(u: User, body: { platform?: unknown; productId?: unknown; token?: unknown }) {
  const productId = typeof body.productId === 'string' ? body.productId : '';
  const product = PRODUCTS[productId] ?? fail('badProduct');
  const token = typeof body.token === 'string' && body.token.length > 0 && body.token.length < 8000 ? body.token : fail('badToken');
  let txId: string;
  let accountToken: string | undefined;
  const platform = body.platform;
  if (platform === 'android') ({ txId, accountToken } = await checkGoogle(productId, token));
  else if (platform === 'ios') ({ txId, accountToken } = await checkApple(productId, token));
  else if (platform === 'test' && testMode()) txId = `test:${token}`;
  else fail('badPlatform');

  // Present and wrong: someone else's completed purchase, redeemed into this account. Absent: an app build from
  // before this check shipped — allow it (there is nothing to compare), but never a mismatch.
  if (accountToken !== undefined && accountToken !== iapAccountToken(u.id)) fail('purchaseAccountMismatch', 409);

  const key = `${platform}:${txId!}`;
  // the offer once per account, while it is open (a resend of the same purchase is answered below)
  if (product.offer && !db.data.purchases[key] && !offerView(u)) fail('offerGone', 409);
  const seen = db.data.purchases[key];
  if (seen) {
    // the app may resend after a lost answer: fine for the same player, refused for anyone else
    if (seen.userId !== u.id) fail('purchaseUsed', 409);
    return { added: 0, currency: seen.currency, already: true };
  }
  db.data.purchases[key] = { id: key, userId: u.id, platform: platform as 'android' | 'ios' | 'test', productId, currency: product.currency, amount: product.amount, at: Date.now() };
  credit(u, product.currency, product.amount, `purchase:${productId}`);
  if (product.offer) {
    u.offerTaken = true;
    addBoost(u, OFFER.boostHours);
    if (!u.owned.includes(OFFER.item)) u.owned.push(OFFER.item);
  }
  if (platform === 'android') void consumeGoogle(productId, token);
  return { added: product.amount, currency: product.currency, already: false };
}

/** The store told us, after the fact, that a purchase was refunded or revoked (iap-webhooks.ts). Debits whatever
 * of it the wallet still holds (never below zero, and never a boost/offer item already used) and marks it so a
 * repeat notification is a no-op. [key] is `platform:txId`, the same dedup key [verifyPurchase] stored it under. */
export function revokePurchase(key: string, reason: string) {
  const p = db.data.purchases[key];
  if (!p || p.revokedAt) return;
  p.revokedAt = Date.now();
  const u = db.data.users[p.userId];
  if (u) {
    const amount = Math.min(u[p.currency], p.amount);
    if (amount > 0) debit(u, p.currency, amount, reason);
    notify(u.id, 'system', 'استُرجعت عملية شراء', `استرجع متجر التطبيقات عملية شراء سابقة (${p.productId})، فخُصم ما تبقّى من رصيدها: ${amount} ${p.currency === 'stars' ? 'نجمة' : 'وحدة'}.`);
  }
  db.touch();
}

// ── Google Play ──────────────────────────────────────────────────────────────

const PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const playUrl = (productId: string, token: string) =>
  `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE()}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`;

interface GoogleProductPurchase {
  purchaseState?: number;
  orderId?: string;
  consumptionState?: number;
  obfuscatedExternalAccountId?: string;
}

/** Fetches the raw Play purchase record — shared with the RTDN webhook, which only has a purchaseToken. */
async function googleProductPurchase(productId: string, token: string): Promise<GoogleProductPurchase> {
  if (!serviceAccount()) fail('paymentsOff', 503);
  const auth = await googleAccessToken(PLAY_SCOPE);
  const res = await fetch(playUrl(productId, token), { headers: { authorization: `Bearer ${auth}` } });
  if (res.status === 404 || res.status === 400) fail('badPurchase', 402);
  if (!res.ok) fail('storeUnreachable', 502);
  return (await res.json()) as GoogleProductPurchase;
}

async function checkGoogle(productId: string, token: string): Promise<{ txId: string; accountToken?: string }> {
  const p = await googleProductPurchase(productId, token);
  // 0 = purchased (1 = cancelled, 2 = pending)
  if (p.purchaseState !== 0) fail(p.purchaseState === 2 ? 'purchasePending' : 'badPurchase', 402);
  return { txId: p.orderId || token, accountToken: p.obfuscatedExternalAccountId };
}

/** Used only by the RTDN webhook: the order id for a purchase token, to find our own dedup/ledger record by it
 * (a cancellation/refund notification carries the purchase token, not the order id we keyed the record by). */
export async function googleOrderIdOf(productId: string, purchaseToken: string): Promise<string | null> {
  try {
    const p = await googleProductPurchase(productId, purchaseToken);
    return p.orderId ?? null;
  } catch {
    return null;
  }
}

async function consumeGoogle(productId: string, token: string) {
  try {
    const auth = await googleAccessToken(PLAY_SCOPE);
    await fetch(`${playUrl(productId, token)}:consume`, { method: 'POST', headers: { authorization: `Bearer ${auth}` } });
  } catch (e) {
    console.error('[payments] consume', (e as Error).message);
  }
}

// ── App Store ────────────────────────────────────────────────────────────────

function appleJwt(): string {
  const key = process.env.APPLE_IAP_PRIVATE_KEY!.replace(/\\n/g, '\n');
  const now = Math.floor(Date.now() / 1000);
  const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned = `${enc({ alg: 'ES256', kid: process.env.APPLE_IAP_KEY_ID, typ: 'JWT' })}.${enc({
    iss: process.env.APPLE_IAP_ISSUER_ID,
    iat: now,
    exp: now + 1200,
    aud: 'appstoreconnect-v1',
    bid: BUNDLE(),
  })}`;
  const sig = createSign('SHA256').update(unsigned).sign({ key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${unsigned}.${sig}`;
}

async function checkApple(productId: string, transactionId: string): Promise<{ txId: string; accountToken?: string }> {
  if (!paymentsStatus().ios) fail('paymentsOff', 503);
  if (!/^\d{1,30}$/.test(transactionId)) fail('badToken');
  const jwt = appleJwt();
  // production first; a TestFlight / sandbox purchase is only known to the sandbox
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await fetch(`https://${host}/inApps/v1/transactions/${transactionId}`, { headers: { authorization: `Bearer ${jwt}` } });
    if (res.status === 404) continue;
    if (!res.ok) fail('storeUnreachable', 502);
    const { signedTransactionInfo } = (await res.json()) as { signedTransactionInfo: string };
    // Fetched from Apple over TLS with our own key, so this payload is already authentic — but checkAppleTransaction
    // verifies its x5c chain and signature anyway (cheap, and the same verifier the webhook relies on for a POST
    // that arrives with no such TLS guarantee), and it is what surfaces `appAccountToken`.
    let tx;
    try {
      tx = checkAppleTransaction(signedTransactionInfo, { bundleId: BUNDLE(), allowSandbox: host.includes('sandbox') });
    } catch (e) {
      if (e instanceof AppleVerificationError) fail('badPurchase', 402);
      throw e;
    }
    if (tx.productId !== productId || tx.revocationDate) fail('badPurchase', 402);
    return { txId: tx.transactionId, accountToken: tx.appAccountToken };
  }
  return fail('badPurchase', 402);
}
