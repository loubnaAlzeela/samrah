// The server's data: one JSON document kept in memory and saved after each change (within half a second, and
// on shutdown). Every module reaches the data through the typed collections below and never through storage.
//
// Where it is saved:
//   DATABASE_URL set    -> PostgreSQL, one JSONB row in `samrah_state` (DATABASE_SSL=1 for RDS and other TLS-only
//                          servers). A first start with an empty database imports $LAMMA_DATA_DIR/samrah.json if it exists.
//   else LAMMA_DATA_DIR -> $LAMMA_DATA_DIR/samrah.json, written atomically. On Railway that must be a mounted volume.
//   neither (tests)     -> memory only.
//
// One server instance only: the game rooms live in its memory, and so does this document.
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import pg from 'pg';
import type { User } from '../accounts.ts';
import type { Club } from '../clubs.ts';
import type { Competition } from '../competitions.ts';
import type { DirectMessage, Notification, Report, Feedback } from '../social.ts';

export interface LedgerEntry {
  userId: string;
  currency: 'units' | 'stars';
  /** positive = credit, negative = debit */
  amount: number;
  /** the balance after this entry */
  balance: number;
  reason: string;
  at: number;
}

export interface Purchase {
  /** the store's own transaction / order id: a purchase is credited once */
  id: string;
  userId: string;
  platform: 'android' | 'ios' | 'test';
  productId: string;
  currency: 'units' | 'stars';
  amount: number;
  at: number;
}

export interface DbShape {
  version: 1;
  /** the next public player number (shown as the player's ID) */
  nextUserNo: number;
  nextId: number;
  users: Record<string, User>;
  /** session token -> user id */
  sessions: Record<string, { userId: string; createdAt: number }>;
  /** lower-cased email -> user id */
  emails: Record<string, string>;
  /** phone (E.164) -> user id */
  phones: Record<string, string>;
  /** Google account id -> user id */
  google: Record<string, string>;
  /** Apple account id (the token's `sub`) -> user id */
  apple: Record<string, string>;
  ledger: LedgerEntry[];
  purchases: Record<string, Purchase>;
  messages: DirectMessage[];
  notifications: Notification[];
  reports: Report[];
  feedback: Feedback[];
  clubs: Record<string, Club>;
  competitions: Record<string, Competition>;
}

function empty(): DbShape {
  return {
    version: 1,
    nextUserNo: 100001,
    nextId: 1,
    users: {},
    sessions: {},
    emails: {},
    phones: {},
    google: {},
    apple: {},
    ledger: [],
    purchases: {},
    messages: [],
    notifications: [],
    reports: [],
    feedback: [],
    clubs: {},
    competitions: {},
  };
}

/** Old lists are trimmed so the file stays small (the database will keep everything). */
const KEEP = { ledger: 20000, messages: 20000, notifications: 20000, reports: 5000, feedback: 5000 };

const ROW = 1;

class Db {
  data: DbShape = empty();
  private file: string | null = null;
  private pool: pg.Pool | null = null;
  private timer: NodeJS.Timeout | null = null;
  private saving: Promise<void> | null = null;
  private dirty = false;

  /** Loads the data: from PostgreSQL if [databaseUrl] is given, else from the file in [dir]; with neither, memory only. */
  async open(dir: string | undefined, databaseUrl?: string) {
    this.file = dir && !databaseUrl ? join(dir, 'samrah.json') : null;
    this.data = empty();
    this.dirty = false;
    if (databaseUrl) {
      await this.openPostgres(dir, databaseUrl);
      return;
    }
    if (!this.file) return;
    mkdirSync(dir!, { recursive: true });
    if (existsSync(this.file)) this.data = merge(JSON.parse(readFileSync(this.file, 'utf8')));
  }

  private async openPostgres(dir: string | undefined, url: string) {
    this.pool = new pg.Pool({ connectionString: url, max: 3, ssl: process.env.DATABASE_SSL === '1' ? { rejectUnauthorized: false } : undefined });
    await this.pool.query(
      'CREATE TABLE IF NOT EXISTS samrah_state (id integer PRIMARY KEY, data jsonb NOT NULL, updated_at timestamptz NOT NULL DEFAULT now())',
    );
    const row = await this.pool.query<{ data: Partial<DbShape> }>('SELECT data FROM samrah_state WHERE id = $1', [ROW]);
    if (row.rows[0]) {
      this.data = merge(row.rows[0].data);
      return;
    }
    // an empty database: bring over the file the server used before, once
    const old = dir ? join(dir, 'samrah.json') : null;
    if (old && existsSync(old)) {
      this.data = merge(JSON.parse(readFileSync(old, 'utf8')));
      console.log(`[db] imported ${old} into PostgreSQL`);
    }
    await this.save();
  }

  /** A new short id with a prefix, e.g. `c12`. */
  id(prefix: string): string {
    return `${prefix}${(this.data.nextId++).toString(36)}`;
  }

  /** Marks the data changed: saved within half a second. */
  touch() {
    this.dirty = true;
    if ((!this.file && !this.pool) || this.timer) return;
    this.timer = setTimeout(() => {
      this.timer = null;
      void this.flush().catch((e) => {
        console.error('[db] save failed, retrying in 5s', e);
        this.timer = setTimeout(() => {
          this.timer = null;
          this.touch();
        }, 5000);
      });
    }, 500);
  }

  /** Saves now (and waits for a save already running). On shutdown this is awaited before the process exits. */
  async flush() {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (!this.file && !this.pool) return;
    // one save at a time; changes made during a save get another one right after it
    while (this.saving || this.dirty) {
      if (this.saving) {
        await this.saving.catch(() => {});
        continue;
      }
      this.saving = this.save().finally(() => {
        this.saving = null;
      });
      await this.saving;
    }
  }

  private async save() {
    this.dirty = false;
    const d = this.data;
    for (const k of Object.keys(KEEP) as (keyof typeof KEEP)[]) {
      const list = d[k] as unknown[];
      if (list.length > KEEP[k]) list.splice(0, list.length - KEEP[k]);
    }
    try {
      if (this.pool) {
        await this.pool.query(
          'INSERT INTO samrah_state (id, data) VALUES ($1, $2::jsonb) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now()',
          [ROW, JSON.stringify(d)],
        );
      } else if (this.file) {
        const tmp = `${this.file}.tmp`;
        writeFileSync(tmp, JSON.stringify(d));
        renameSync(tmp, this.file);
      }
    } catch (e) {
      this.dirty = true;
      throw e;
    }
  }

  /** Closes the connection to PostgreSQL (after a flush). */
  async close() {
    await this.flush();
    await this.pool?.end();
    this.pool = null;
  }

  /** Tests: start from nothing. */
  reset() {
    this.data = empty();
  }
}

/** A stored document on top of the empty one, so collections added later exist in old data. */
function merge(stored: Partial<DbShape>): DbShape {
  return { ...empty(), ...stored };
}

export const db = new Db();
