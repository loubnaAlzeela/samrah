import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';

// Runs against a real PostgreSQL when TEST_DATABASE_URL is set (it creates and drops the table `samrah_state`).
const url = process.env.TEST_DATABASE_URL;

describe.skipIf(!url)('PostgreSQL storage', () => {
  const pool = new pg.Pool({ connectionString: url });
  afterAll(() => pool.end());

  it('imports the old file once, saves changes, and loads them back', async () => {
    await pool.query('DROP TABLE IF EXISTS samrah_state');
    const dir = mkdtempSync(join(tmpdir(), 'samrah-'));
    writeFileSync(join(dir, 'samrah.json'), JSON.stringify({ version: 1, nextUserNo: 100777, emails: { 'a@b.c': 'u1' } }));
    const { db } = await import('../src/data/db.ts');

    await db.open(dir, url);
    expect(db.data.nextUserNo).toBe(100777);
    expect(db.data.emails['a@b.c']).toBe('u1');
    expect(db.data.apple).toEqual({});
    db.data.nextUserNo = 100900;
    db.touch();
    db.data.nextUserNo = 100901; // changed again before the save runs: the last value wins
    db.touch();
    await db.close();

    // a second start reads the database, not the file
    await db.open(dir, url);
    expect(db.data.nextUserNo).toBe(100901);
    await db.close();
    expect((await pool.query('SELECT count(*)::int AS n FROM samrah_state')).rows[0].n).toBe(1);
  });
});
