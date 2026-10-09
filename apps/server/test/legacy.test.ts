import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('data saved before email and phone sign-in were removed', () => {
  it('drops the email and phone indexes and fields, keeps the accounts and their Google / Apple links', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'samrah-legacy-'));
    const user = { id: 'u1', no: 100001, name: 'قديم', email: 'a@b.co', passwordHash: 'scrypt$x$y', phone: '+966500000000', googleId: 'g1', appleId: null, units: 7 };
    writeFileSync(
      join(dir, 'samrah.json'),
      JSON.stringify({ version: 1, users: { u1: user }, emails: { 'a@b.co': 'u1' }, phones: { '+966500000000': 'u1' }, google: { g1: 'u1' } }),
    );
    const { db } = await import('../src/data/db.ts');
    await db.open(dir);
    const d = db.data as unknown as Record<string, unknown>;
    expect(d.emails).toBeUndefined();
    expect(d.phones).toBeUndefined();
    expect(db.data.deletedProviders).toEqual({});
    expect(db.data.google.g1).toBe('u1');
    const u = db.data.users.u1 as unknown as Record<string, unknown>;
    expect(u).toMatchObject({ name: 'قديم', units: 7, googleId: 'g1', appleRefreshToken: null });
    for (const k of ['email', 'passwordHash', 'phone']) expect(u[k]).toBeUndefined();
    await db.close();
  });
});
