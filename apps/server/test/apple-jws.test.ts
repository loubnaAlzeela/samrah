import { describe, expect, it } from 'vitest';
import * as a from '../src/apple-jws.ts';
import { makeChain, makeSelfSigned, signJws } from './helpers/apple-chain.ts';

const chain = makeChain();
const tx = { transactionId: '2000000123', productId: 'units_3500', bundleId: 'com.samrah.app', environment: 'Production', type: 'Consumable', quantity: 1, signedDate: Date.now() };

it('the pinned Apple root is the real Apple Root CA - G3', () => {
  expect(a.APPLE_ROOT_CA_G3_SHA256).toBe('63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79');
});

it('a correctly chained and signed JWS verifies against the root we trust', () => {
  const payload = a.verifyAppleJws(signJws(tx, chain), { roots: [chain.rootPem] });
  expect(payload.transactionId).toBe('2000000123');
});

it('the same JWS is rejected when the trusted root is not the one it chains to (default = Apple’s real root)', () => {
  expect(() => a.verifyAppleJws(signJws(tx, chain))).toThrow(/untrusted root/);
  expect(() => a.verifyAppleJws(signJws(tx, chain), { roots: [makeChain({ name: 'Other' }).rootPem] })).toThrow(/untrusted root/);
});

it('a self-signed JWS that claims to be a full chain is rejected, even if it trusts itself', () => {
  const forged = makeSelfSigned();
  expect(() => a.verifyAppleJws(signJws(tx, forged))).toThrow(/untrusted root/);
  expect(() => a.verifyAppleJws(signJws(tx, forged), { roots: [forged.rootPem] })).toThrow(/chain|issued|extension/);
});

it('tampering with the payload, the algorithm or the certificate list is rejected', () => {
  const good = signJws(tx, chain).split('.');
  const tampered = `${good[0]}.${Buffer.from(JSON.stringify({ ...tx, productId: 'units_8000' })).toString('base64url')}.${good[2]}`;
  expect(() => a.verifyAppleJws(tampered, { roots: [chain.rootPem] })).toThrow(/bad signature/);
  expect(() => a.verifyAppleJws(signJws(tx, chain, { alg: 'none' }), { roots: [chain.rootPem] })).toThrow(/algorithm/);
  expect(() => a.verifyAppleJws(signJws(tx, { ...chain, x5c: [chain.x5c[0], chain.x5c[1]] as unknown as Chain['x5c'] }), { roots: [chain.rootPem] })).toThrow(/certificate chain/);
  expect(() => a.verifyAppleJws(signJws(tx, { ...chain, x5c: [chain.x5c[1], chain.x5c[0], chain.x5c[2]] }), { roots: [chain.rootPem] })).toThrow(/chain|issued|extension/);
  expect(() => a.verifyAppleJws('not.a.jws', { roots: [chain.rootPem] })).toThrow(/malformed|unreadable/);
  expect(() => a.verifyAppleJws('', { roots: [chain.rootPem] })).toThrow(/malformed/);
});

it("a chain without Apple's marker extensions is rejected", () => {
  const plain = makeChain({ markers: false, name: 'Plain' });
  expect(() => a.verifyAppleJws(signJws(tx, plain), { roots: [plain.rootPem] })).toThrow(/extension/);
});

it('certificates must be valid at the signing time', () => {
  const farFuture = Date.now() + 20 * 365 * 24 * 3600_000;
  const longAgo = Date.now() - 30 * 365 * 24 * 3600_000;
  expect(() => a.verifyAppleJws(signJws({ ...tx, signedDate: farFuture }, chain), { roots: [chain.rootPem], now: farFuture })).toThrow(/not valid at signing time/);
  expect(() => a.verifyAppleJws(signJws({ ...tx, signedDate: longAgo }, chain), { roots: [chain.rootPem] })).toThrow(/not valid at signing time/);
});

describe('checkAppleTransaction', () => {
  const options = { roots: [chain.rootPem] };
  const ok = { bundleId: 'com.samrah.app', allowSandbox: false };

  it('enforces bundle id and environment', () => {
    expect(a.checkAppleTransaction(signJws(tx, chain), ok, options).productId).toBe('units_3500');
    expect(() => a.checkAppleTransaction(signJws({ ...tx, bundleId: 'com.evil.app' }, chain), ok, options)).toThrow(/bundle/);
    expect(() => a.checkAppleTransaction(signJws({ ...tx, environment: 'Sandbox' }, chain), ok, options)).toThrow(/environment/);
    expect(a.checkAppleTransaction(signJws({ ...tx, environment: 'Sandbox' }, chain), { ...ok, allowSandbox: true }, options).environment).toBe('Sandbox');
    expect(() => a.checkAppleTransaction(signJws({ ...tx, environment: 'Xcode' }, chain), { ...ok, allowSandbox: true }, options)).toThrow(/environment/);
  });

  it('surfaces appAccountToken when the purchase carried one (account-binding check)', () => {
    const bound = a.checkAppleTransaction(signJws({ ...tx, appAccountToken: 'abc-123' }, chain), ok, options);
    expect(bound.appAccountToken).toBe('abc-123');
    const unbound = a.checkAppleTransaction(signJws(tx, chain), ok, options);
    expect(unbound.appAccountToken).toBeUndefined();
  });

  it('rejects a revoked transaction only when the caller checks revocationDate (it is surfaced, not auto-rejected)', () => {
    const revoked = a.checkAppleTransaction(signJws({ ...tx, revocationDate: Date.now() }, chain), ok, options);
    expect(revoked.revocationDate).toBeTypeOf('number');
  });
});

describe('verifyAppleNotification', () => {
  it('verifies an App Store Server Notification V2 envelope the same way as a transaction', () => {
    const notif = { notificationType: 'REFUND', subtype: undefined, data: { bundleId: 'com.samrah.app', environment: 'Production', signedTransactionInfo: signJws(tx, chain) } };
    const verified = a.verifyAppleNotification(signJws(notif, chain), { roots: [chain.rootPem] });
    expect(verified.notificationType).toBe('REFUND');
    expect(verified.data?.bundleId).toBe('com.samrah.app');
  });

  it('rejects a forged notification the same way as a forged transaction', () => {
    const forged = makeSelfSigned();
    const notif = { notificationType: 'REFUND', data: { bundleId: 'com.samrah.app' } };
    expect(() => a.verifyAppleNotification(signJws(notif, forged), { roots: [chain.rootPem] })).toThrow(/untrusted root|chain|issued|extension/);
  });
});

type Chain = import('./helpers/apple-chain.ts').Chain;
