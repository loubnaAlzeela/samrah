// The server's data until the real database exists: one JSON document kept in memory and written to
// $LAMMA_DATA_DIR/samrah.json (atomically, a moment after each change, and on shutdown). Every module reaches
// the data through the typed collections below and never through the file, so moving to PostgreSQL later means
// replacing this file and the few `db.*` calls, not the rules around them.
//
// Without LAMMA_DATA_DIR (tests) nothing is written. On Railway the directory must be a mounted volume, or the
// data is lost on every deploy.
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
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

class Db {
  data: DbShape = empty();
  private file: string | null = null;
  private timer: NodeJS.Timeout | null = null;

  /** Loads the file from [dir] (created if missing); with no dir the data lives in memory only. */
  open(dir: string | undefined) {
    this.file = dir ? join(dir, 'samrah.json') : null;
    this.data = empty();
    if (!this.file) return;
    mkdirSync(dir!, { recursive: true });
    if (existsSync(this.file)) this.data = { ...empty(), ...(JSON.parse(readFileSync(this.file, 'utf8')) as Partial<DbShape>) };
  }

  /** A new short id with a prefix, e.g. `c12`. */
  id(prefix: string): string {
    return `${prefix}${(this.data.nextId++).toString(36)}`;
  }

  /** Marks the data changed: written within half a second. */
  touch() {
    if (!this.file || this.timer) return;
    this.timer = setTimeout(() => this.flush(), 500);
  }

  flush() {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (!this.file) return;
    const d = this.data;
    for (const k of Object.keys(KEEP) as (keyof typeof KEEP)[]) {
      const list = d[k] as unknown[];
      if (list.length > KEEP[k]) list.splice(0, list.length - KEEP[k]);
    }
    const tmp = `${this.file}.tmp`;
    writeFileSync(tmp, JSON.stringify(d));
    renameSync(tmp, this.file);
  }

  /** Tests: start from nothing. */
  reset() {
    this.data = empty();
  }
}

export const db = new Db();
