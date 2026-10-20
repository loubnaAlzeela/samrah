import { describe, expect, it, beforeAll } from 'vitest';

beforeAll(async () => {
  const { db } = await import('../src/data/db.ts');
  await db.open(undefined); // memory only
});

describe('iapAccountToken', () => {
  it('is a stable, UUID-shaped value derived from the account id, unique per account', async () => {
    const { iapAccountToken } = await import('../src/iap-account-token.ts');
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    const a = iapAccountToken('u1');
    const b = iapAccountToken('u2');
    expect(a).toMatch(uuid);
    expect(b).toMatch(uuid);
    expect(a).not.toBe(b);
    expect(iapAccountToken('u1')).toBe(a); // deterministic
  });
});

describe('revokePurchase', () => {
  it('debits the credited amount, clamped at zero, and is a no-op the second time', async () => {
    const { db } = await import('../src/data/db.ts');
    const { createAccount } = await import('../src/accounts.ts');
    const { revokePurchase } = await import('../src/payments.ts');
    const { user } = createAccount('Reem', 'google', `revoke-test-${Date.now()}`);
    const startUnits = user.units;
    db.data.purchases['ios:tx-1'] = { id: 'ios:tx-1', userId: user.id, platform: 'ios', productId: 'units_3500', currency: 'units', amount: 4000, at: Date.now() };
    user.units += 4000; // what verifyPurchase would have credited

    revokePurchase('ios:tx-1', 'test-refund');
    expect(user.units).toBe(startUnits);
    expect(db.data.purchases['ios:tx-1'].revokedAt).toBeTypeOf('number');

    user.units += 100; // spent most of it already by the time the refund notice arrives
    revokePurchase('ios:tx-1', 'test-refund-again'); // already revoked: must not touch the wallet twice
    expect(user.units).toBe(startUnits + 100);
  });

  it('clamps to whatever the wallet still holds instead of going negative', async () => {
    const { db } = await import('../src/data/db.ts');
    const { createAccount } = await import('../src/accounts.ts');
    const { revokePurchase } = await import('../src/payments.ts');
    const { user } = createAccount('Nour', 'apple', `revoke-test-spent-${Date.now()}`);
    // the player already spent the purchased units before the refund notice arrived: the wallet (the welcome
    // balance alone, 2000) holds less than the refunded purchase (4000)
    db.data.purchases['ios:tx-2'] = { id: 'ios:tx-2', userId: user.id, platform: 'ios', productId: 'units_3500', currency: 'units', amount: 4000, at: Date.now() };

    revokePurchase('ios:tx-2', 'test-refund-spent');
    expect(user.units).toBe(0); // debited down to zero, never below
  });

  it('ignores an unknown purchase key', async () => {
    const { createAccount } = await import('../src/accounts.ts');
    const { revokePurchase } = await import('../src/payments.ts');
    const { user } = createAccount('Sara', 'google', `revoke-test-unknown-${Date.now()}`);
    expect(() => revokePurchase('ios:does-not-exist', 'test')).not.toThrow();
    expect(user.units).toBeGreaterThanOrEqual(0);
  });
});
