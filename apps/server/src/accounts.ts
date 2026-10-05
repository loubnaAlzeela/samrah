// Players: the account (a guest on first launch; an email, phone or Google account can be linked later and used
// to sign in on another phone), the two wallets with their ledger, what the player owns and uses from the store,
// the gold membership, the daily gift, the level (from experience earned by playing), game statistics, the daily
// and weekly challenges, settings, and the block list.
import { db } from './data/db.ts';
import { ApiError, checkPassword, cleanText, dayKey, fail, hashPassword, isEmail, newSecret, weekKey } from './util.ts';
import { notify } from './social.ts';
import { addClubPoints } from './clubs.ts';

// ── the economy (one place to tune) ──────────────────────────────────────────

export const ECONOMY = {
  /** what a new account starts with */
  startUnits: 2000,
  startStars: 20,
  dailyGift: 100,
  /** gold membership: price in «نجوم» for [vipDays] days */
  vipPrice: 300,
  vipDays: 30,
  /** a player may rename once a day */
  renameEveryMs: 24 * 3600 * 1000,
};

/** What a store item is: the kind decides where it shows (a card back, the table, the seat ring, the name's colour,
 * a badge beside the name, an effect when a card is played, an emote sent at the table, or an experience booster). */
export type ItemKind = 'back' | 'table' | 'seat' | 'name' | 'badge' | 'hit' | 'emote' | 'boost';

/** The kinds a player wears (one of each at a time); back and table have their own fields. */
export const LOOK_KINDS = ['seat', 'name', 'badge', 'hit'] as const;
export type LookKind = (typeof LOOK_KINDS)[number];

/** Samrah's own mascot (the «وحدات» coin — lib/widgets/emote_face.dart draws it), one fixed colour, each item
 * just a different face — no colour picks to buy. [emoji] is only a plain-text fallback (for a push notification,
 * say) — the table itself draws the mascot's own vector face. */
const EMOTE_FACES = [
  { id: 'laugh', price: 0, emoji: '😂' },
  { id: 'wink', price: 300, emoji: '😉' },
  { id: 'shock', price: 300, emoji: '😲' },
  { id: 'cry', price: 300, emoji: '😭' },
  { id: 'sleep', price: 300, emoji: '😴' },
  { id: 'think', price: 300, emoji: '🤔' },
  { id: 'nervous', price: 400, emoji: '😬' },
  { id: 'angry', price: 400, emoji: '😠' },
  { id: 'tease', price: 400, emoji: '😜' },
  { id: 'cool', price: 600, emoji: '😎' },
  { id: 'love', price: 600, emoji: '🥰' },
  { id: 'star', price: 600, emoji: '🤩' },
  { id: 'sad', price: 300, emoji: '😢' },
  { id: 'bored', price: 300, emoji: '😐' },
  { id: 'shy', price: 400, emoji: '😊' },
  { id: 'surprised', price: 400, emoji: '😮' },
  { id: 'proud', price: 400, emoji: '😁' },
  { id: 'dizzy', price: 600, emoji: '😵' },
  { id: 'clap', price: 600, emoji: '👏' },
  { id: 'thumbsup', price: 600, emoji: '👍' },
  { id: 'strong', price: 800, emoji: '💪' },
  { id: 'kiss', price: 800, emoji: '😘' },
] as const;

function emoteItems(): Record<string, { kind: 'emote'; price: number; emoji: string }> {
  const out: Record<string, { kind: 'emote'; price: number; emoji: string }> = {};
  for (const f of EMOTE_FACES) out[`emo_${f.id}`] = { kind: 'emote', price: f.price, emoji: f.emoji };
  return out;
}

/** Store items (the app draws them; the server only knows ids and prices). Price 0 = everyone has it. Prices are in
 * «وحدات» unless [stars]. A booster is not kept: buying one doubles the experience earned for [hours]. */
export const ITEMS: Record<string, { kind: ItemKind; price: number; vipOnly?: boolean; stars?: boolean; hours?: number; emoji?: string }> = {
  orange: { kind: 'back', price: 0 },
  navy: { kind: 'back', price: 300 },
  emerald: { kind: 'back', price: 300 },
  wine: { kind: 'back', price: 500 },
  charcoal: { kind: 'back', price: 500 },
  gold: { kind: 'back', price: 0, vipOnly: true },
  cream: { kind: 'table', price: 0 },
  mint: { kind: 'table', price: 400 },
  sky: { kind: 'table', price: 400 },
  rose: { kind: 'table', price: 600 },
  sand: { kind: 'table', price: 600 },
  royal: { kind: 'table', price: 0, vipOnly: true },

  seat_plain: { kind: 'seat', price: 0 },
  seat_orange: { kind: 'seat', price: 600 },
  seat_teal: { kind: 'seat', price: 600 },
  seat_violet: { kind: 'seat', price: 800 },
  seat_ruby: { kind: 'seat', price: 800 },
  seat_rainbow: { kind: 'seat', price: 1500 },
  seat_gold: { kind: 'seat', price: 0, vipOnly: true },

  name_plain: { kind: 'name', price: 0 },
  name_orange: { kind: 'name', price: 400 },
  name_mint: { kind: 'name', price: 400 },
  name_sky: { kind: 'name', price: 400 },
  name_pink: { kind: 'name', price: 600 },
  name_lilac: { kind: 'name', price: 600 },
  name_gold: { kind: 'name', price: 0, vipOnly: true },

  badge_none: { kind: 'badge', price: 0 },
  badge_spade: { kind: 'badge', price: 800 },
  badge_heart: { kind: 'badge', price: 800 },
  badge_fire: { kind: 'badge', price: 1200 },
  badge_bolt: { kind: 'badge', price: 1200 },
  badge_diamond: { kind: 'badge', price: 2500 },
  badge_crown: { kind: 'badge', price: 0, vipOnly: true },

  hit_none: { kind: 'hit', price: 0 },
  hit_wave: { kind: 'hit', price: 1000 },
  hit_sparks: { kind: 'hit', price: 1200 },
  hit_hearts: { kind: 'hit', price: 1500 },
  hit_fire: { kind: 'hit', price: 2000 },
  hit_stars: { kind: 'hit', price: 0, vipOnly: true },

  ...emoteItems(),

  boost_3h: { kind: 'boost', price: 30, stars: true, hours: 3 },
  boost_12h: { kind: 'boost', price: 80, stars: true, hours: 12 },
  boost_24h: { kind: 'boost', price: 140, stars: true, hours: 24 },
};

/** What a new player wears. */
export const DEFAULT_LOOK: Record<LookKind, string> = { seat: 'seat_plain', name: 'name_plain', badge: 'badge_none', hit: 'hit_none' };

/** The one-time welcome offer, bought with real money (payments.ts): how long it stays open after the account is
 * made, and what it brings. */
export const OFFER = { id: 'offer_starter', days: 7, units: 6000, boostHours: 12, item: 'emo_love' };

// ── levels ───────────────────────────────────────────────────────────────────

/** Experience for a finished game, and the extra for winning it. */
export const XP_PLAYED = 20;
export const XP_WON = 30;
export const MAX_LEVEL = 100;

/** Total experience needed to reach [level]: 0, 100, 300, 600, 1000… (each level asks 100 more than the last). */
export const xpForLevel = (level: number) => (100 * (level - 1) * level) / 2;

export function levelOf(xp: number): number {
  let l = 1;
  while (l < MAX_LEVEL && xp >= xpForLevel(l + 1)) l++;
  return l;
}

// ── challenges ───────────────────────────────────────────────────────────────

/** What a finished game tells the challenges. */
export interface MatchEvent {
  variant: string;
  won: boolean;
  /** a private room with at least one other human (a friend) */
  withFriend: boolean;
}

export interface ChallengeDef {
  id: string;
  period: 'day' | 'week';
  title: string;
  icon: string;
  goal: number;
  /** «نجوم» */
  reward: number;
  /** the game family it counts in; null = any */
  game: string | null;
  /** how much a finished game adds (0 = this game does not count) */
  count: (e: MatchEvent, seen: string[]) => number;
}

const TARNEEB = ['tarneeb', 'syrian41', 'tarneeb400'];
const TRIX = ['trix', 'trixPartners', 'trixComplex', 'trixComplexPartners'];

/** Every task is decided by finished games (or, for the competition one, by joining a competition). */
export const CHALLENGES: ChallengeDef[] = [
  { id: 'd-play3', period: 'day', title: 'العب 3 جولات من أي لعبة', icon: 'style', goal: 3, reward: 5, game: null, count: () => 1 },
  { id: 'd-tarneeb2', period: 'day', title: 'افز بجولتين طرنيب', icon: 'trophy', goal: 2, reward: 8, game: 'tarneeb', count: (e) => (TARNEEB.includes(e.variant) && e.won ? 1 : 0) },
  { id: 'd-win1', period: 'day', title: 'افز بجولة من أي لعبة', icon: 'target', goal: 1, reward: 6, game: null, count: (e) => (e.won ? 1 : 0) },
  {
    id: 'd-trixhand',
    period: 'day',
    title: 'العب جولة تركس وجولة هاند',
    icon: 'shuffle',
    goal: 2,
    reward: 6,
    game: null,
    // one for the first Trix game of the day, one for the first Hand game
    count: (e, seen) => (TRIX.includes(e.variant) && !seen.some((v) => TRIX.includes(v)) ? 1 : e.variant === 'hand' && !seen.includes('hand') ? 1 : 0),
  },
  { id: 'd-friend', period: 'day', title: 'العب مع صديق في غرفة خاصة', icon: 'group', goal: 1, reward: 5, game: null, count: (e) => (e.withFriend ? 1 : 0) },
  { id: 'w-play25', period: 'week', title: 'العب 25 جولة', icon: 'style', goal: 25, reward: 30, game: null, count: () => 1 },
  { id: 'w-baloot10', period: 'week', title: 'افز بـ10 جولات بلوت', icon: 'trophy', goal: 10, reward: 40, game: 'baloot', count: (e) => (e.variant === 'baloot' && e.won ? 1 : 0) },
  { id: 'w-win15', period: 'week', title: 'افز بـ15 جولة من أي لعبة', icon: 'star', goal: 15, reward: 50, game: null, count: (e) => (e.won ? 1 : 0) },
  {
    id: 'w-variety',
    period: 'week',
    title: 'جرّب 4 ألعاب مختلفة',
    icon: 'grid',
    goal: 4,
    reward: 25,
    game: null,
    count: (e, seen) => (seen.includes(e.variant) ? 0 : 1),
  },
  { id: 'w-comp', period: 'week', title: 'اشترك في مسابقة', icon: 'medal', goal: 1, reward: 20, game: null, count: () => 0 },
];

// ── the account ──────────────────────────────────────────────────────────────

export interface UserSettings {
  /** others see when the player is online */
  showOnline: boolean;
  /** who may send private messages */
  allowMessages: 'all' | 'none';
  /** who may send gifts at the table (gifts from blocked players never arrive) */
  allowGifts: boolean;
  /** appears in the public ranking */
  showInRanking: boolean;
  /** which notifications reach the phone (they are always listed in the app) */
  notify: { messages: boolean; clubs: boolean; competitions: boolean; gifts: boolean; challenges: boolean; system: boolean };
}

export interface User {
  id: string;
  /** the public player number */
  no: number;
  name: string;
  country: string | null;
  createdAt: number;
  lastSeen: number;
  renamedAt: number | null;
  email: string | null;
  passwordHash: string | null;
  phone: string | null;
  googleId: string | null;
  units: number;
  stars: number;
  vipUntil: number | null;
  owned: string[];
  backId: string;
  tableId: string;
  /** seat ring, name colour, badge and card-play effect (missing on older accounts: [DEFAULT_LOOK]) */
  look?: Partial<Record<LookKind, string>>;
  /** experience counts double until then */
  boostUntil?: number | null;
  /** the welcome offer was bought */
  offerTaken?: boolean;
  /** the day (dayKey) the daily gift was last taken */
  giftDay: string | null;
  xp: number;
  stats: {
    played: number;
    won: number;
    byVariant: Record<string, { played: number; won: number }>;
    week: string;
    weekPlayed: number;
    weekWon: number;
    /** experience earned this week (the weekly ranking) */
    weekXp: number;
    giftsReceived: number;
  };
  challenges: {
    day: string;
    week: string;
    progress: Record<string, number>;
    claimed: string[];
    /** the games played today / this week (for the "different games" tasks) */
    dayGames: string[];
    weekGames: string[];
  };
  settings: UserSettings;
  blocked: string[];
  pushTokens: string[];
  clubId: string | null;
  /** competitions: 'organise' = may not organise, 'all' = may not organise or join (decided by the team) */
  compBanned: false | 'organise' | 'all';
  /** organiser rating points (see competitions.ts) */
  compRating?: number;
  /** suspended by the team: cannot sign in */
  banned: boolean;
}

const DEFAULT_SETTINGS: UserSettings = {
  showOnline: true,
  allowMessages: 'all',
  allowGifts: true,
  showInRanking: true,
  notify: { messages: true, clubs: true, competitions: true, gifts: true, challenges: true, system: true },
};

export function cleanName(x: unknown): string | null {
  const n = cleanText(x, 16);
  return n && n.length >= 2 ? n : null;
}

export function createGuest(nameArg: unknown, country?: unknown): { user: User; token: string } {
  const name = cleanName(nameArg) ?? fail('badName');
  const d = db.data;
  const now = Date.now();
  const user: User = {
    id: db.id('u'),
    no: d.nextUserNo++,
    name,
    country: typeof country === 'string' && /^[A-Z]{2}$/.test(country) ? country : null,
    createdAt: now,
    lastSeen: now,
    renamedAt: null,
    email: null,
    passwordHash: null,
    phone: null,
    googleId: null,
    units: 0,
    stars: 0,
    vipUntil: null,
    owned: ['orange', 'cream'],
    backId: 'orange',
    tableId: 'cream',
    look: { ...DEFAULT_LOOK },
    boostUntil: null,
    offerTaken: false,
    giftDay: null,
    xp: 0,
    stats: { played: 0, won: 0, byVariant: {}, week: weekKey(now), weekPlayed: 0, weekWon: 0, weekXp: 0, giftsReceived: 0 },
    challenges: { day: dayKey(now), week: weekKey(now), progress: {}, claimed: [], dayGames: [], weekGames: [] },
    settings: structuredClone(DEFAULT_SETTINGS),
    blocked: [],
    pushTokens: [],
    clubId: null,
    compBanned: false,
    banned: false,
  };
  d.users[user.id] = user;
  credit(user, 'units', ECONOMY.startUnits, 'welcome');
  credit(user, 'stars', ECONOMY.startStars, 'welcome');
  notify(user.id, 'system', 'أهلاً بك في سمرة', `رقمك في اللعبة ${user.no}. أضفنا إلى محفظتك ${ECONOMY.startUnits} وحدة و${ECONOMY.startStars} نجمة هدية ترحيب.`);
  return { user, token: newSession(user) };
}

export function newSession(user: User): string {
  const token = newSecret();
  db.data.sessions[token] = { userId: user.id, createdAt: Date.now() };
  db.touch();
  return token;
}

export function userByToken(token: unknown): User | null {
  if (typeof token !== 'string' || token.length < 10) return null;
  const s = db.data.sessions[token];
  const u = s ? db.data.users[s.userId] : undefined;
  return u && !u.banned ? u : null;
}

export function requireUser(token: unknown): User {
  const u = userByToken(token);
  if (!u) throw new ApiError(401, 'signedOut');
  u.lastSeen = Date.now();
  rollPeriods(u);
  return u;
}

export const userById = (id: unknown): User | null => (typeof id === 'string' ? (db.data.users[id] ?? null) : null);

/** Finds a player by number (the ID shown in the app) or by internal id. */
export function findUser(ref: unknown): User | null {
  if (typeof ref === 'number' || (typeof ref === 'string' && /^\d{6,}$/.test(ref))) {
    const no = Number(ref);
    return Object.values(db.data.users).find((u) => u.no === no) ?? null;
  }
  return userById(ref);
}

export function signOut(token: string) {
  delete db.data.sessions[token];
  db.touch();
}

/** Sign-in on another phone: email + password. */
export function loginWithEmail(emailArg: unknown, password: unknown): { user: User; token: string } {
  if (!isEmail(emailArg) || typeof password !== 'string') fail('badLogin', 401);
  const id = db.data.emails[(emailArg as string).toLowerCase()];
  const u = id ? db.data.users[id] : undefined;
  if (!u || !checkPassword(password as string, u.passwordHash)) fail('badLogin', 401);
  if (u!.banned) fail('banned', 403);
  return { user: u!, token: newSession(u!) };
}

/** Links an email and password to the account (or changes the password: the current one is then required). */
export function setEmailPassword(u: User, emailArg: unknown, password: unknown, current: unknown) {
  if (!isEmail(emailArg)) fail('badEmail');
  if (typeof password !== 'string' || password.length < 8 || password.length > 100) fail('weakPassword');
  if (u.passwordHash && !checkPassword(typeof current === 'string' ? current : '', u.passwordHash)) fail('wrongPassword', 403);
  const email = (emailArg as string).toLowerCase();
  const owner = db.data.emails[email];
  if (owner && owner !== u.id) fail('emailTaken', 409);
  if (u.email && u.email !== email) delete db.data.emails[u.email];
  u.email = email;
  u.passwordHash = hashPassword(password as string);
  db.data.emails[email] = u.id;
  db.touch();
}

/** Signs out every other phone (security). */
export function signOutOthers(u: User, keep: string) {
  for (const [t, s] of Object.entries(db.data.sessions)) if (s.userId === u.id && t !== keep) delete db.data.sessions[t];
  db.touch();
}

export function sessionCount(u: User): number {
  return Object.values(db.data.sessions).filter((s) => s.userId === u.id).length;
}

/** Deletes the account and everything that points at it (store policies require this to be possible in the app). */
export function deleteAccount(u: User) {
  const d = db.data;
  for (const [t, s] of Object.entries(d.sessions)) if (s.userId === u.id) delete d.sessions[t];
  if (u.email) delete d.emails[u.email];
  if (u.phone) delete d.phones[u.phone];
  if (u.googleId) delete d.google[u.googleId];
  d.messages = d.messages.filter((m) => m.from !== u.id && m.to !== u.id);
  d.notifications = d.notifications.filter((n) => n.userId !== u.id);
  for (const other of Object.values(d.users)) other.blocked = other.blocked.filter((b) => b !== u.id);
  delete d.users[u.id];
  db.touch();
}

// ── wallet ───────────────────────────────────────────────────────────────────

export function credit(u: User, currency: 'units' | 'stars', amount: number, reason: string) {
  if (!Number.isInteger(amount) || amount <= 0) return;
  u[currency] += amount;
  db.data.ledger.push({ userId: u.id, currency, amount, balance: u[currency], reason, at: Date.now() });
  db.touch();
}

/** Takes [amount] or refuses with `noUnits` / `noStars` (nothing changes then). */
export function debit(u: User, currency: 'units' | 'stars', amount: number, reason: string) {
  if (!Number.isInteger(amount) || amount < 0) fail('badAmount');
  if (amount === 0) return;
  if (u[currency] < amount) fail(currency === 'units' ? 'noUnits' : 'noStars', 402, { need: amount });
  u[currency] -= amount;
  db.data.ledger.push({ userId: u.id, currency, amount: -amount, balance: u[currency], reason, at: Date.now() });
  db.touch();
}

export const isVip = (u: User) => u.vipUntil !== null && u.vipUntil > Date.now();

/** Everything the player may use: what they bought, what is free, and the members' items while a member. */
export function ownedItems(u: User): string[] {
  const vip = isVip(u);
  const out = new Set(u.owned);
  for (const [id, it] of Object.entries(ITEMS)) if (it.kind !== 'boost' && ((it.price === 0 && !it.vipOnly) || (it.vipOnly && vip))) out.add(id);
  return [...out];
}

export const ownsItem = (u: User, id: string) => ownedItems(u).includes(id);

/** What the player wears now (a members' item falls back to the default once the membership ends). */
export function lookOf(u: User): Record<LookKind, string> {
  const out = { ...DEFAULT_LOOK };
  for (const k of LOOK_KINDS) {
    const id = u.look?.[k];
    if (id && ITEMS[id]?.kind === k && ownsItem(u, id)) out[k] = id;
  }
  return out;
}

export const isBoosted = (u: User) => !!u.boostUntil && u.boostUntil > Date.now();

/** Experience counts double for [hours] more (added to a booster still running). */
export function addBoost(u: User, hours: number) {
  u.boostUntil = (isBoosted(u) ? u.boostUntil! : Date.now()) + hours * 3600000;
  db.touch();
}

export function buyItem(u: User, id: unknown) {
  const item = typeof id === 'string' ? ITEMS[id] : undefined;
  if (!item) fail('badItem');
  if (item!.vipOnly) fail('vipOnly', 403);
  const currency = item!.stars ? 'stars' : 'units';
  if (item!.kind === 'boost') {
    debit(u, currency, item!.price, `item:${id}`);
    addBoost(u, item!.hours!);
    return;
  }
  if (ownsItem(u, id as string)) fail('owned');
  debit(u, currency, item!.price, `item:${id}`);
  u.owned.push(id as string);
  db.touch();
}

export function useItem(u: User, id: unknown) {
  const item = typeof id === 'string' ? ITEMS[id] : undefined;
  if (!item || item.kind === 'emote' || item.kind === 'boost') fail('badItem');
  if (!ownsItem(u, id as string)) fail('notOwned', 403);
  if (item!.kind === 'back') u.backId = id as string;
  else if (item!.kind === 'table') u.tableId = id as string;
  else u.look = { ...lookOf(u), [item!.kind]: id as string };
  db.touch();
}

export function buyVip(u: User) {
  debit(u, 'stars', ECONOMY.vipPrice, 'vip');
  const from = isVip(u) ? u.vipUntil! : Date.now();
  u.vipUntil = from + ECONOMY.vipDays * 86400000;
  db.touch();
}

export const giftAmount = (u: User) => (isVip(u) ? ECONOMY.dailyGift * 2 : ECONOMY.dailyGift);

export function claimGift(u: User): number {
  const today = dayKey();
  if (u.giftDay === today) fail('giftTaken');
  const amount = giftAmount(u);
  u.giftDay = today;
  credit(u, 'units', amount, 'dailyGift');
  return amount;
}

// ── profile & settings ───────────────────────────────────────────────────────

export function rename(u: User, nameArg: unknown) {
  const name = cleanName(nameArg) ?? fail('badName');
  if (name === u.name) return;
  if (u.renamedAt && Date.now() - u.renamedAt < ECONOMY.renameEveryMs) fail('renameTooSoon', 429, { at: u.renamedAt + ECONOMY.renameEveryMs });
  u.name = name;
  u.renamedAt = Date.now();
  db.touch();
}

export function setCountry(u: User, c: unknown) {
  if (c !== null && !(typeof c === 'string' && /^[A-Z]{2}$/.test(c))) fail('badCountry');
  u.country = c as string | null;
  db.touch();
}

export function updateSettings(u: User, patch: unknown) {
  if (!patch || typeof patch !== 'object') fail('badSettings');
  const p = patch as Record<string, unknown>;
  const s = u.settings;
  for (const k of ['showOnline', 'allowGifts', 'showInRanking'] as const) if (typeof p[k] === 'boolean') s[k] = p[k] as boolean;
  if (p.allowMessages === 'all' || p.allowMessages === 'none') s.allowMessages = p.allowMessages;
  if (p.notify && typeof p.notify === 'object') {
    const n = p.notify as Record<string, unknown>;
    for (const k of Object.keys(s.notify) as (keyof UserSettings['notify'])[]) if (typeof n[k] === 'boolean') s.notify[k] = n[k] as boolean;
  }
  db.touch();
}

export function block(u: User, other: User) {
  if (other.id === u.id) fail('badUser');
  if (!u.blocked.includes(other.id)) u.blocked.push(other.id);
  db.touch();
}

export function unblock(u: User, otherId: string) {
  u.blocked = u.blocked.filter((b) => b !== otherId);
  db.touch();
}

/** Either side blocked the other. */
export const blockedBetween = (a: User, b: User) => a.blocked.includes(b.id) || b.blocked.includes(a.id);

export function addPushToken(u: User, token: unknown) {
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) fail('badToken');
  // one phone belongs to one account: drop the token from whoever had it
  for (const other of Object.values(db.data.users)) if (other.id !== u.id) other.pushTokens = other.pushTokens.filter((t) => t !== token);
  if (!u.pushTokens.includes(token as string)) u.pushTokens = [...u.pushTokens.slice(-4), token as string];
  db.touch();
}

// ── playing ──────────────────────────────────────────────────────────────────

/** Starts the new day / week for the stats and the challenges. */
export function rollPeriods(u: User, now = Date.now()) {
  const day = dayKey(now);
  const week = weekKey(now);
  const ch = u.challenges;
  if (ch.day !== day) {
    for (const c of CHALLENGES) if (c.period === 'day') delete ch.progress[c.id];
    ch.claimed = ch.claimed.filter((id) => CHALLENGES.find((c) => c.id === id)?.period !== 'day');
    ch.dayGames = [];
    ch.day = day;
  }
  if (ch.week !== week) {
    for (const c of CHALLENGES) if (c.period === 'week') delete ch.progress[c.id];
    ch.claimed = ch.claimed.filter((id) => CHALLENGES.find((c) => c.id === id)?.period !== 'week');
    ch.weekGames = [];
    ch.week = week;
  }
  if (u.stats.week !== week) Object.assign(u.stats, { week, weekPlayed: 0, weekWon: 0, weekXp: 0 });
}

function addXp(u: User, xp: number) {
  if (isBoosted(u)) xp *= 2;
  const before = levelOf(u.xp);
  u.xp += xp;
  u.stats.weekXp += xp;
  const after = levelOf(u.xp);
  if (after > before) notify(u.id, 'system', `وصلت إلى المستوى ${after}`, 'أحسنت! استمر في اللعب لتصعد أكثر.');
}

/** Moves a challenge on (claimable ones send a notification once). */
function progressChallenge(u: User, c: ChallengeDef, by: number) {
  if (by <= 0) return;
  const before = u.challenges.progress[c.id] ?? 0;
  if (before >= c.goal) return;
  const now = Math.min(c.goal, before + by);
  u.challenges.progress[c.id] = now;
  if (now >= c.goal) notify(u.id, 'challenges', 'أنجزت تحدياً', `«${c.title}» — استلم ${c.reward} نجمة من صفحة التحديات.`);
}

/** A finished game, for one human player. */
export function recordMatch(u: User, e: MatchEvent) {
  rollPeriods(u);
  const s = u.stats;
  s.played++;
  s.weekPlayed++;
  const v = (s.byVariant[e.variant] ??= { played: 0, won: 0 });
  v.played++;
  if (e.won) {
    s.won++;
    s.weekWon++;
    v.won++;
  }
  addXp(u, XP_PLAYED + (e.won ? XP_WON : 0));
  const ch = u.challenges;
  for (const c of CHALLENGES) progressChallenge(u, c, c.count(e, c.period === 'day' ? ch.dayGames : ch.weekGames));
  if (!ch.dayGames.includes(e.variant)) ch.dayGames.push(e.variant);
  if (!ch.weekGames.includes(e.variant)) ch.weekGames.push(e.variant);
  if (u.clubId) addClubPoints(u, e.won ? 3 : 1);
  db.touch();
}

/** Joined a competition (the weekly task). */
export function recordCompetitionJoin(u: User) {
  rollPeriods(u);
  const c = CHALLENGES.find((x) => x.id === 'w-comp')!;
  progressChallenge(u, c, 1);
  db.touch();
}

export function claimChallenge(u: User, id: unknown) {
  const c = CHALLENGES.find((x) => x.id === id) ?? fail('badChallenge');
  if ((u.challenges.progress[c.id] ?? 0) < c.goal) fail('notDone');
  if (u.challenges.claimed.includes(c.id)) fail('claimed');
  u.challenges.claimed.push(c.id);
  credit(u, 'stars', c.reward, `challenge:${c.id}`);
}

// ── what the app sees ────────────────────────────────────────────────────────

const ONLINE_MS = 3 * 60 * 1000;
export const isOnline = (u: User) => u.settings.showOnline && Date.now() - u.lastSeen < ONLINE_MS;

export function levelInfo(u: User) {
  const level = levelOf(u.xp);
  const from = xpForLevel(level);
  const to = xpForLevel(level + 1);
  return { level, xp: u.xp, levelFrom: from, levelTo: to };
}

export function challengesView(u: User) {
  rollPeriods(u);
  return CHALLENGES.map((c) => ({
    id: c.id,
    period: c.period,
    title: c.title,
    icon: c.icon,
    goal: c.goal,
    reward: c.reward,
    game: c.game,
    progress: u.challenges.progress[c.id] ?? 0,
    claimed: u.challenges.claimed.includes(c.id),
  }));
}

/** The welcome offer while this player may still buy it (null once bought or past its days). */
export function offerView(u: User) {
  const until = u.createdAt + OFFER.days * 86400000;
  if (u.offerTaken || until <= Date.now()) return null;
  return { id: OFFER.id, until, units: OFFER.units, boostHours: OFFER.boostHours, item: OFFER.item };
}

/** The player's own account, as the app keeps it. */
export function meView(u: User) {
  return {
    id: u.id,
    no: u.no,
    name: u.name,
    country: u.country,
    renamedAt: u.renamedAt,
    email: u.email,
    hasPassword: !!u.passwordHash,
    phone: u.phone,
    google: !!u.googleId,
    units: u.units,
    stars: u.stars,
    vip: isVip(u),
    vipUntil: u.vipUntil,
    owned: ownedItems(u),
    backId: u.backId,
    tableId: u.tableId,
    look: lookOf(u),
    boostUntil: isBoosted(u) ? u.boostUntil : null,
    offer: offerView(u),
    giftTaken: u.giftDay === dayKey(),
    giftAmount: giftAmount(u),
    ...levelInfo(u),
    stats: u.stats,
    settings: u.settings,
    blocked: u.blocked.map((id) => db.data.users[id]).filter(Boolean).map((b) => ({ id: b!.id, no: b!.no, name: b!.name })),
    clubId: u.clubId,
    compBanned: u.compBanned,
    sessions: sessionCount(u),
    createdAt: u.createdAt,
  };
}

/** What other players may see. */
export function publicProfile(u: User, viewer?: User | null) {
  const club = u.clubId ? db.data.clubs[u.clubId] : undefined;
  return {
    id: u.id,
    no: u.no,
    name: u.name,
    country: u.country,
    level: levelOf(u.xp),
    vip: isVip(u),
    online: isOnline(u),
    played: u.stats.played,
    won: u.stats.won,
    byVariant: u.stats.byVariant,
    giftsReceived: u.stats.giftsReceived,
    club: club && club.status === 'active' ? { id: club.id, name: club.name } : null,
    since: u.createdAt,
    blockedByMe: viewer ? viewer.blocked.includes(u.id) : false,
    canMessage: viewer ? viewer.id !== u.id && !blockedBetween(viewer, u) && u.settings.allowMessages === 'all' : false,
  };
}
