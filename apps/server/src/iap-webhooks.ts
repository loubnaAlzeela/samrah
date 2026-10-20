// The stores telling us, after the fact, that a purchase we already credited was refunded or revoked — so the
// wallet gets debited to match. Mounted outside /api (these are called by Apple/Google, never by the app, and
// carry no session bearer token; each one authenticates itself its own way, below).
//
// One-time setup per store (nothing here does this — it's a console click, not code):
//   Apple:  App Store Connect -> this app -> App Information -> App Store Server Notifications -> set the
//           Production and Sandbox URLs to https://<this server>/iap/apple (Version 2).
//   Google: Play Console -> Monetization setup -> create a Pub/Sub topic for real-time developer notifications ->
//           in Google Cloud Console, add a push subscription on that topic: endpoint https://<this server>/iap/google,
//           "Enable authentication" checked, audience = that same URL. Then set GOOGLE_RTDN_AUDIENCE here to it too.
import express, { Router } from 'express';
import { googleOrderIdOf, revokePurchase } from './payments.ts';
import { AppleVerificationError, verifyAppleJws, verifyAppleNotification } from './apple-jws.ts';
import { verifyGoogleOidcToken } from './google-oidc.ts';

const BUNDLE = () => process.env.APPLE_BUNDLE_ID || 'com.samrah.app';
const PACKAGE = () => process.env.GOOGLE_PLAY_PACKAGE || 'com.samrah.app';

export function iapWebhooksRouter(): Router {
  const r = Router();
  r.use(express.json({ limit: '64kb' }));

  // Apple App Store Server Notifications V2: `{signedPayload}`, a JWS we verify ourselves end to end (see
  // apple-jws.ts) — nothing about this request is otherwise authenticated.
  r.post('/apple', (req, res) => {
    const signedPayload = req.body?.signedPayload;
    if (typeof signedPayload !== 'string') {
      res.status(400).json({ error: 'badNotification' });
      return;
    }
    let notif: Awaited<ReturnType<typeof verifyAppleNotification>>;
    try {
      notif = verifyAppleNotification(signedPayload);
    } catch (e) {
      console.error('[iap] apple notification', e instanceof AppleVerificationError ? e.message : e);
      res.status(400).json({ error: 'badSignature' });
      return;
    }
    // A notification for a different app somehow reaching this server: ignore, not an error (and not retried).
    if (notif.data?.bundleId && notif.data.bundleId !== BUNDLE()) {
      res.json({ ok: true });
      return;
    }
    if ((notif.notificationType === 'REFUND' || notif.notificationType === 'REVOKE') && notif.data?.signedTransactionInfo) {
      let tx: { transactionId?: unknown };
      try {
        tx = verifyAppleJws(notif.data.signedTransactionInfo);
      } catch (e) {
        console.error('[iap] apple notification transaction', e instanceof AppleVerificationError ? e.message : e);
        res.status(400).json({ error: 'badSignature' });
        return;
      }
      if (typeof tx.transactionId === 'string') revokePurchase(`ios:${tx.transactionId}`, `appleRefund:${notif.notificationType}`);
    }
    res.json({ ok: true });
  });

  // Google Play Real-Time Developer Notifications via a Pub/Sub push subscription: authenticated by the OIDC
  // bearer token Pub/Sub attaches, verified against GOOGLE_RTDN_AUDIENCE (see the setup note above).
  r.post('/google', async (req, res) => {
    const audience = process.env.GOOGLE_RTDN_AUDIENCE;
    if (!audience) {
      console.error('[iap] GOOGLE_RTDN_AUDIENCE is not set; refusing an unverifiable Google notification');
      res.status(503).json({ error: 'rtdnOff' });
      return;
    }
    const auth = req.headers.authorization;
    const token = auth?.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!token || !(await verifyGoogleOidcToken(token, audience))) {
      res.status(401).json({ error: 'badToken' });
      return;
    }
    let payload: { packageName?: string; oneTimeProductNotification?: { notificationType?: number; purchaseToken?: string; sku?: string } };
    try {
      payload = JSON.parse(Buffer.from(req.body?.message?.data ?? '', 'base64').toString('utf8'));
    } catch {
      res.status(400).json({ error: 'badNotification' });
      return;
    }
    if (payload.packageName && payload.packageName !== PACKAGE()) {
      res.json({ ok: true });
      return;
    }
    const n = payload.oneTimeProductNotification;
    // type 2 = ONE_TIME_PRODUCT_CANCELED (refunded or charged back). Type 1 (PURCHASED) needs no action here —
    // the app already calls POST /purchases itself once it has the receipt.
    if (n?.notificationType === 2 && typeof n.sku === 'string' && typeof n.purchaseToken === 'string') {
      const orderId = await googleOrderIdOf(n.sku, n.purchaseToken);
      if (orderId) revokePurchase(`android:${orderId}`, 'googleRefund');
    }
    res.json({ ok: true });
  });

  return r;
}
