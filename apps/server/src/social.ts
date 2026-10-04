// Between players: private messages, notifications (kept in the app's list and, when the player allows that kind,
// pushed to the phone), reports about a player, and feedback to the team.
import { db } from './data/db.ts';
import { type User, blockedBetween, userById } from './accounts.ts';
import { fail, cleanText } from './util.ts';
import { sendPush } from './push.ts';

export type NotificationKind = 'messages' | 'clubs' | 'competitions' | 'gifts' | 'challenges' | 'system';

export interface Notification {
  id: string;
  userId: string;
  kind: NotificationKind;
  title: string;
  body: string;
  at: number;
  read: boolean;
  /** where tapping it leads, e.g. {screen: 'club', id: 'k3'} */
  data?: Record<string, string>;
}

export interface DirectMessage {
  id: string;
  from: string;
  to: string;
  text: string;
  at: number;
  read: boolean;
  /** players who deleted the conversation on their side */
  hiddenFor?: string[];
}

export interface Report {
  id: string;
  from: string;
  against: string;
  reason: string;
  text: string;
  at: number;
  /** where it happened, e.g. a room code or a club */
  where: string | null;
}

export interface Feedback {
  id: string;
  from: string;
  kind: 'idea' | 'problem' | 'other';
  text: string;
  at: number;
}

const MAX_PER_USER = 200;

export function notify(userId: string, kind: NotificationKind, title: string, body: string, data?: Record<string, string>) {
  const n: Notification = { id: db.id('n'), userId, kind, title, body, at: Date.now(), read: false, ...(data ? { data } : {}) };
  const list = db.data.notifications;
  list.push(n);
  // keep each player's list short
  const mine = list.filter((x) => x.userId === userId);
  if (mine.length > MAX_PER_USER) {
    const drop = new Set(mine.slice(0, mine.length - MAX_PER_USER).map((x) => x.id));
    db.data.notifications = list.filter((x) => !drop.has(x.id));
  }
  db.touch();
  const u = userById(userId);
  if (u && u.settings.notify[kind] && u.pushTokens.length) void sendPush(u, title, body, { kind, ...(data ?? {}) });
}

export function notificationsOf(u: User) {
  return db.data.notifications.filter((n) => n.userId === u.id).sort((a, b) => b.at - a.at);
}

export function markNotificationsRead(u: User, ids?: unknown) {
  const only = Array.isArray(ids) ? new Set(ids.filter((x) => typeof x === 'string')) : null;
  for (const n of db.data.notifications) if (n.userId === u.id && (!only || only.has(n.id))) n.read = true;
  db.touch();
}

export function clearNotifications(u: User) {
  db.data.notifications = db.data.notifications.filter((n) => n.userId !== u.id);
  db.touch();
}

// ── private messages ─────────────────────────────────────────────────────────

const MSG_MAX = 500;
const MSG_GAP_MS = 700;
const lastSent = new Map<string, number>();

export function sendMessage(from: User, toId: unknown, textArg: unknown): DirectMessage {
  const to = userById(toId) ?? fail('badUser', 404);
  if (to.id === from.id) fail('badUser');
  if (blockedBetween(from, to)) fail('blocked', 403);
  if (to.settings.allowMessages === 'none') fail('messagesOff', 403);
  const text = cleanText(textArg, MSG_MAX) ?? fail('badText');
  const now = Date.now();
  if (now - (lastSent.get(from.id) ?? 0) < MSG_GAP_MS) fail('tooFast', 429);
  lastSent.set(from.id, now);
  const m: DirectMessage = { id: db.id('m'), from: from.id, to: to.id, text, at: now, read: false };
  db.data.messages.push(m);
  db.touch();
  // the list of notifications holds one line per sender, not one per message
  const unreadFromSender = db.data.notifications.find((n) => n.userId === to.id && n.kind === 'messages' && !n.read && n.data?.userId === from.id);
  if (unreadFromSender) {
    unreadFromSender.body = text;
    unreadFromSender.at = now;
    if (to.settings.notify.messages && to.pushTokens.length) void sendPush(to, from.name, text, { kind: 'messages', userId: from.id });
  } else {
    notify(to.id, 'messages', from.name, text, { screen: 'chat', userId: from.id });
  }
  return m;
}

/** One row per person the player talked with: the last message and how many are unread. */
export function conversations(u: User) {
  const rows = new Map<string, { last: DirectMessage; unread: number }>();
  for (const m of db.data.messages) {
    if ((m.from !== u.id && m.to !== u.id) || m.hiddenFor?.includes(u.id)) continue;
    const other = m.from === u.id ? m.to : m.from;
    const r = rows.get(other) ?? { last: m, unread: 0 };
    r.last = m;
    if (m.to === u.id && !m.read) r.unread++;
    rows.set(other, r);
  }
  return [...rows.entries()]
    .map(([id, r]) => {
      const o = userById(id);
      return o ? { user: { id: o.id, no: o.no, name: o.name }, last: r.last, unread: r.unread } : null;
    })
    .filter((x) => x !== null)
    .sort((a, b) => b!.last.at - a!.last.at);
}

export function thread(u: User, otherId: unknown, before?: number) {
  const other = userById(otherId) ?? fail('badUser', 404);
  const all = db.data.messages.filter((m) => ((m.from === u.id && m.to === other.id) || (m.from === other.id && m.to === u.id)) && !m.hiddenFor?.includes(u.id));
  const older = before ? all.filter((m) => m.at < before) : all;
  for (const m of all) if (m.to === u.id) m.read = true;
  // reading the thread also reads its notification
  for (const n of db.data.notifications) if (n.userId === u.id && n.kind === 'messages' && n.data?.userId === other.id) n.read = true;
  db.touch();
  return older.slice(-100);
}

export function deleteConversation(u: User, otherId: unknown) {
  if (typeof otherId !== 'string') fail('badUser');
  // hidden on this player's side only; a message both sides deleted is dropped
  for (const m of db.data.messages) {
    if ((m.from === u.id && m.to === otherId) || (m.from === otherId && m.to === u.id)) {
      m.read = m.read || m.to === u.id;
      m.hiddenFor = [...new Set([...(m.hiddenFor ?? []), u.id])];
    }
  }
  db.data.messages = db.data.messages.filter((m) => !(m.hiddenFor?.includes(m.from) && m.hiddenFor.includes(m.to)));
  db.touch();
}

export function unreadCounts(u: User) {
  let messages = 0;
  for (const m of db.data.messages) if (m.to === u.id && !m.read && !m.hiddenFor?.includes(u.id)) messages++;
  let notifications = 0;
  for (const n of db.data.notifications) if (n.userId === u.id && !n.read && n.kind !== 'messages') notifications++;
  return { messages, notifications };
}

// ── reports & feedback ───────────────────────────────────────────────────────

export const REPORT_REASONS = ['إساءة أو شتم', 'غش أو تلاعب', 'اسم غير لائق', 'إزعاج أو رسائل مزعجة', 'أخرى'];

export function report(from: User, againstId: unknown, reason: unknown, textArg: unknown, where: unknown) {
  const against = userById(againstId) ?? fail('badUser', 404);
  if (typeof reason !== 'string' || !REPORT_REASONS.includes(reason)) fail('badReason');
  const text = cleanText(textArg, 600) ?? '';
  db.data.reports.push({ id: db.id('r'), from: from.id, against: against.id, reason: reason as string, text, at: Date.now(), where: typeof where === 'string' ? where.slice(0, 40) : null });
  db.touch();
}

export function feedback(from: User, kind: unknown, textArg: unknown) {
  const k = kind === 'idea' || kind === 'problem' ? kind : 'other';
  const text = cleanText(textArg, 2000) ?? fail('badText');
  if (text.length < 5) fail('badText');
  db.data.feedback.push({ id: db.id('f'), from: from.id, kind: k, text, at: Date.now() });
  db.touch();
}
