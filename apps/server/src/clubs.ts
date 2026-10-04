// الأندية — permanent groups of players with a president, moderators, a chat, and weekly points the members earn
// by playing (3 for a win, 1 for any other finished game), ranked against the other clubs.
//
// A club is founded for CREATE_COST «وحدات» and opens once the team approves it (the admin page; or at once with
// CLUBS_AUTO_APPROVE=1); a refused club gives the money back. Three kinds:
//   open    — anyone may join at once
//   closed  — listed; joining is a request a moderator accepts
//   private — not listed; joining is by invitation only
//
// Who may use clubs: for now everyone (every player is level 1 at the start). Once the game has
// CLUBS_OPEN_UNTIL_USERS players, clubs ask for level CLUBS_LEVEL_AFTER (2 at first, up to 5 later).
import { db } from './data/db.ts';
import { type User, credit, debit, isOnline, levelOf, userById, findUser, blockedBetween } from './accounts.ts';
import { notify } from './social.ts';
import { cleanText, fail, weekKey } from './util.ts';

export type ClubRole = 'president' | 'moderator' | 'member';
export type ClubType = 'open' | 'closed' | 'private';

export interface ClubMember {
  userId: string;
  role: ClubRole;
  joinedAt: number;
  weekPoints: number;
  totalPoints: number;
}

export interface ClubMessage {
  id: string;
  /** null = a notice from the club itself (joined, left…) */
  from: string | null;
  name: string;
  text: string;
  at: number;
}

export interface Club {
  id: string;
  name: string;
  motto: string;
  emblem: number;
  color: number;
  type: ClubType;
  status: 'pending' | 'active' | 'rejected';
  /** lowest player level that may join */
  minLevel: number;
  createdAt: number;
  createdBy: string;
  paid: number;
  members: ClubMember[];
  requests: { userId: string; at: number }[];
  invites: { userId: string; by: string; at: number }[];
  chat: ClubMessage[];
  week: string;
  note?: string;
}

const num = (v: string | undefined, d: number) => (v && Number.isFinite(Number(v)) ? Number(v) : d);

export const CLUB_RULES = {
  createCost: 5000,
  maxMembers: 30,
  /** moderators besides the president */
  maxModerators: 4,
  emblems: 8,
  colors: 6,
  chatKeep: 300,
  openUntilUsers: num(process.env.CLUBS_OPEN_UNTIL_USERS, 1000),
  levelAfter: num(process.env.CLUBS_LEVEL_AFTER, 2),
  autoApprove: process.env.CLUBS_AUTO_APPROVE === '1',
};

/** The level a player needs to found or join a club right now. */
export function clubsUnlockLevel(): number {
  return Object.keys(db.data.users).length < CLUB_RULES.openUntilUsers ? 1 : CLUB_RULES.levelAfter;
}

const clubOf = (id: unknown): Club => (typeof id === 'string' ? db.data.clubs[id] : undefined) ?? fail('badClub', 404);
const memberOf = (c: Club, userId: string) => c.members.find((m) => m.userId === userId);
const nameOf = (id: string) => userById(id)?.name ?? 'لاعب';

function rollWeek(c: Club) {
  const w = weekKey();
  if (c.week === w) return;
  c.week = w;
  for (const m of c.members) m.weekPoints = 0;
}

function say(c: Club, text: string, from: User | null = null) {
  c.chat.push({ id: db.id('cm'), from: from?.id ?? null, name: from?.name ?? 'النادي', text, at: Date.now() });
  if (c.chat.length > CLUB_RULES.chatKeep) c.chat.splice(0, c.chat.length - CLUB_RULES.chatKeep);
}

function requireLevel(u: User, c?: Club) {
  const need = Math.max(clubsUnlockLevel(), c?.minLevel ?? 1);
  if (levelOf(u.xp) < need) fail('lowLevel', 403, { need });
}

function myRole(c: Club, u: User): ClubRole | null {
  return memberOf(c, u.id)?.role ?? null;
}

function requireManager(c: Club, u: User) {
  const r = myRole(c, u);
  if (r !== 'president' && r !== 'moderator') fail('notAllowed', 403);
  if (c.status !== 'active') fail('clubPending', 403);
}

function addMember(c: Club, u: User, role: ClubRole = 'member') {
  c.members.push({ userId: u.id, role, joinedAt: Date.now(), weekPoints: 0, totalPoints: 0 });
  c.requests = c.requests.filter((r) => r.userId !== u.id);
  c.invites = c.invites.filter((r) => r.userId !== u.id);
  u.clubId = c.id;
  // other clubs forget this player's requests
  for (const other of Object.values(db.data.clubs)) if (other.id !== c.id) other.requests = other.requests.filter((r) => r.userId !== u.id);
}

const managers = (c: Club) => c.members.filter((m) => m.role !== 'member').map((m) => m.userId);

// ── reading ──────────────────────────────────────────────────────────────────

export function clubCard(c: Club) {
  rollWeek(c);
  return {
    id: c.id,
    name: c.name,
    motto: c.motto,
    emblem: c.emblem,
    color: c.color,
    type: c.type,
    status: c.status,
    minLevel: c.minLevel,
    members: c.members.length,
    maxMembers: CLUB_RULES.maxMembers,
    weekPoints: c.members.reduce((s, m) => s + m.weekPoints, 0),
    president: nameOf(c.members.find((m) => m.role === 'president')?.userId ?? c.createdBy),
  };
}

/** Clubs anyone can find (private ones never), best this week first; [q] filters by name. */
export function listClubs(q?: unknown) {
  const query = typeof q === 'string' ? q.trim() : '';
  return Object.values(db.data.clubs)
    .filter((c) => c.status === 'active' && c.type !== 'private' && (!query || c.name.includes(query)))
    .map(clubCard)
    .sort((a, b) => b.weekPoints - a.weekPoints);
}

/** The ranking of every active club this week (private ones included: they play too). */
export function clubRanking() {
  return Object.values(db.data.clubs)
    .filter((c) => c.status === 'active')
    .map(clubCard)
    .sort((a, b) => b.weekPoints - a.weekPoints)
    .slice(0, 100);
}

/** A club's page. Members see the chat, the requests and the invitations; others see the card and members. */
export function clubDetail(id: unknown, viewer: User) {
  const c = clubOf(id);
  rollWeek(c);
  const me = memberOf(c, viewer.id);
  const invited = c.invites.some((i) => i.userId === viewer.id);
  if (c.type === 'private' && !me && !invited) fail('badClub', 404);
  if (c.status !== 'active' && !me) fail('badClub', 404);
  const people = (ids: string[]) =>
    ids
      .map((uid) => userById(uid))
      .filter((u): u is User => !!u)
      .map((u) => ({ id: u.id, no: u.no, name: u.name, level: levelOf(u.xp), online: isOnline(u) }));
  return {
    ...clubCard(c),
    myRole: me?.role ?? null,
    requested: c.requests.some((r) => r.userId === viewer.id),
    invited,
    note: me ? (c.note ?? null) : null,
    members: c.members
      .map((m) => {
        const u = userById(m.userId);
        return u ? { id: u.id, no: u.no, name: u.name, level: levelOf(u.xp), online: isOnline(u), role: m.role, weekPoints: m.weekPoints, totalPoints: m.totalPoints, joinedAt: m.joinedAt } : null;
      })
      .filter(Boolean),
    requests: me && me.role !== 'member' ? people(c.requests.map((r) => r.userId)) : [],
    invites: me && me.role !== 'member' ? people(c.invites.map((r) => r.userId)) : [],
  };
}

export function clubChat(id: unknown, viewer: User, after?: number) {
  const c = clubOf(id);
  if (!memberOf(c, viewer.id)) fail('notMember', 403);
  const list = after ? c.chat.filter((m) => m.at > after) : c.chat.slice(-100);
  // messages from players the viewer blocked are left out
  return list.filter((m) => !m.from || !viewer.blocked.includes(m.from));
}

/** Invitations waiting for the player (private and other clubs). */
export function myInvites(u: User) {
  return Object.values(db.data.clubs)
    .filter((c) => c.status === 'active' && c.invites.some((i) => i.userId === u.id))
    .map(clubCard);
}

// ── founding ─────────────────────────────────────────────────────────────────

export function createClub(u: User, body: { name?: unknown; motto?: unknown; emblem?: unknown; color?: unknown; type?: unknown; minLevel?: unknown; agree?: unknown }) {
  if (body.agree !== true) fail('mustAgree');
  if (u.clubId) fail('inClub', 409);
  requireLevel(u);
  const name = cleanText(body.name, 24) ?? fail('badName');
  if (name.length < 3) fail('nameShort');
  const taken = Object.values(db.data.clubs).some((c) => c.status !== 'rejected' && c.name === name);
  if (taken) fail('nameTaken', 409);
  const type: ClubType = body.type === 'open' || body.type === 'private' ? body.type : body.type === 'closed' ? 'closed' : fail('badType');
  const emblem = Number(body.emblem ?? 0);
  const color = Number(body.color ?? 0);
  if (!Number.isInteger(emblem) || emblem < 0 || emblem >= CLUB_RULES.emblems) fail('badEmblem');
  if (!Number.isInteger(color) || color < 0 || color >= CLUB_RULES.colors) fail('badColor');
  const minLevel = Number(body.minLevel ?? 1);
  if (!Number.isInteger(minLevel) || minLevel < 1 || minLevel > 100) fail('badLevel');
  debit(u, 'units', CLUB_RULES.createCost, 'clubCreate');
  const c: Club = {
    id: db.id('k'),
    name,
    motto: cleanText(body.motto, 60) ?? '',
    emblem,
    color,
    type,
    status: 'pending',
    minLevel,
    createdAt: Date.now(),
    createdBy: u.id,
    paid: CLUB_RULES.createCost,
    members: [],
    requests: [],
    invites: [],
    chat: [],
    week: weekKey(),
  };
  db.data.clubs[c.id] = c;
  addMember(c, u, 'president');
  say(c, `أسّس ${u.name} النادي`);
  if (CLUB_RULES.autoApprove) approveClub(c.id);
  db.touch();
  return c;
}

export function approveClub(id: unknown) {
  const c = clubOf(id);
  if (c.status !== 'pending') fail('notPending');
  c.status = 'active';
  c.note = undefined;
  say(c, 'تمت الموافقة على النادي، أهلاً بكم!');
  notify(c.createdBy, 'clubs', 'تم تفعيل ناديك', `وافق فريق سمرة على نادي «${c.name}». ادعُ أصدقاءك الآن!`, { screen: 'club', id: c.id });
  db.touch();
}

export function rejectClub(id: unknown, reasonArg: unknown) {
  const c = clubOf(id);
  if (c.status !== 'pending') fail('notPending');
  const reason = cleanText(reasonArg, 200) ?? 'لم يوافق الفريق على النادي';
  c.status = 'rejected';
  c.note = reason;
  const founder = userById(c.createdBy);
  if (founder) {
    credit(founder, 'units', c.paid, 'clubRefund');
    notify(founder.id, 'clubs', 'لم تتم الموافقة على النادي', `${reason}. أُعيدت ${c.paid} وحدة إلى محفظتك.`);
  }
  for (const m of c.members) {
    const u = userById(m.userId);
    if (u && u.clubId === c.id) u.clubId = null;
  }
  c.members = [];
  db.touch();
}

export function pendingClubs() {
  return Object.values(db.data.clubs)
    .filter((c) => c.status === 'pending')
    .map((c) => ({ ...clubCard(c), createdAt: c.createdAt, founder: userById(c.createdBy) ? { no: userById(c.createdBy)!.no, name: userById(c.createdBy)!.name } : null }));
}

// ── joining & leaving ────────────────────────────────────────────────────────

export function joinClub(u: User, id: unknown): 'joined' | 'requested' {
  const c = clubOf(id);
  if (c.status !== 'active') fail('badClub', 404);
  if (u.clubId) fail('inClub', 409);
  requireLevel(u, c);
  if (c.members.length >= CLUB_RULES.maxMembers) fail('clubFull', 409);
  const invited = c.invites.some((i) => i.userId === u.id);
  if (c.type === 'open' || invited) {
    addMember(c, u);
    say(c, `${u.name} انضم إلى النادي`);
    db.touch();
    return 'joined';
  }
  if (c.type === 'private') fail('inviteOnly', 403);
  if (c.requests.some((r) => r.userId === u.id)) fail('requested', 409);
  if (c.requests.length >= 100) fail('tooManyRequests', 409);
  c.requests.push({ userId: u.id, at: Date.now() });
  for (const m of managers(c)) notify(m, 'clubs', `طلب انضمام إلى «${c.name}»`, `${u.name} يريد الانضمام إلى النادي.`, { screen: 'club', id: c.id });
  db.touch();
  return 'requested';
}

export function cancelRequest(u: User, id: unknown) {
  const c = clubOf(id);
  c.requests = c.requests.filter((r) => r.userId !== u.id);
  db.touch();
}

export function declineInvite(u: User, id: unknown) {
  const c = clubOf(id);
  c.invites = c.invites.filter((r) => r.userId !== u.id);
  db.touch();
}

export function leaveClub(u: User) {
  const c = u.clubId ? db.data.clubs[u.clubId] : undefined;
  u.clubId = null;
  if (!c) return;
  const me = memberOf(c, u.id);
  c.members = c.members.filter((m) => m.userId !== u.id);
  if (c.members.length === 0) {
    // the last one out closes the club (a pending one is withdrawn: the money comes back, as with a refusal)
    if (c.status === 'pending') {
      credit(u, 'units', c.paid, 'clubRefund');
    }
    delete db.data.clubs[c.id];
  } else {
    if (me?.role === 'president') {
      const next = c.members.find((m) => m.role === 'moderator') ?? [...c.members].sort((a, b) => a.joinedAt - b.joinedAt)[0];
      next.role = 'president';
      say(c, `أصبح ${nameOf(next.userId)} رئيس النادي`);
      notify(next.userId, 'clubs', 'أصبحت رئيس النادي', `غادر ${u.name} نادي «${c.name}» وانتقلت الرئاسة إليك.`, { screen: 'club', id: c.id });
    }
    say(c, `${u.name} غادر النادي`);
  }
  db.touch();
}

// ── managing ─────────────────────────────────────────────────────────────────

export function answerRequest(u: User, id: unknown, who: unknown, accept: boolean) {
  const c = clubOf(id);
  requireManager(c, u);
  const req = c.requests.find((r) => r.userId === who) ?? fail('badUser', 404);
  c.requests = c.requests.filter((r) => r !== req);
  const p = userById(req.userId);
  if (accept && p) {
    if (p.clubId) fail('inOtherClub', 409);
    if (c.members.length >= CLUB_RULES.maxMembers) fail('clubFull', 409);
    addMember(c, p);
    say(c, `${p.name} انضم إلى النادي`);
    notify(p.id, 'clubs', 'قُبل طلبك', `أصبحت عضواً في نادي «${c.name}».`, { screen: 'club', id: c.id });
  } else if (p) {
    notify(p.id, 'clubs', 'لم يُقبل طلبك', `لم يقبل نادي «${c.name}» طلب انضمامك.`);
  }
  db.touch();
}

export function invite(u: User, id: unknown, ref: unknown) {
  const c = clubOf(id);
  requireManager(c, u);
  const p = findUser(ref) ?? fail('badUser', 404);
  if (memberOf(c, p.id)) fail('alreadyMember', 409);
  if (blockedBetween(u, p)) fail('blocked', 403);
  if (c.invites.some((i) => i.userId === p.id)) fail('alreadyInvited', 409);
  c.invites.push({ userId: p.id, by: u.id, at: Date.now() });
  notify(p.id, 'clubs', `دعوة إلى نادي «${c.name}»`, `يدعوك ${u.name} للانضمام إلى النادي.`, { screen: 'club', id: c.id });
  db.touch();
  return { id: p.id, no: p.no, name: p.name };
}

export function cancelInvite(u: User, id: unknown, who: unknown) {
  const c = clubOf(id);
  requireManager(c, u);
  c.invites = c.invites.filter((i) => i.userId !== who);
  db.touch();
}

/** Moderators may remove members; only the president removes moderators. */
export function removeMember(u: User, id: unknown, who: unknown) {
  const c = clubOf(id);
  requireManager(c, u);
  const target = c.members.find((m) => m.userId === who) ?? fail('badUser', 404);
  const mine = myRole(c, u);
  if (target.role === 'president' || target.userId === u.id) fail('notAllowed', 403);
  if (target.role === 'moderator' && mine !== 'president') fail('notAllowed', 403);
  c.members = c.members.filter((m) => m !== target);
  const p = userById(target.userId);
  if (p) {
    p.clubId = null;
    notify(p.id, 'clubs', 'خرجت من النادي', `أخرجك ${u.name} من نادي «${c.name}».`);
  }
  say(c, `أُخرج ${nameOf(target.userId)} من النادي`);
  db.touch();
}

export function setRole(u: User, id: unknown, who: unknown, role: unknown) {
  const c = clubOf(id);
  if (myRole(c, u) !== 'president') fail('notAllowed', 403);
  const target = c.members.find((m) => m.userId === who) ?? fail('badUser', 404);
  if (target.userId === u.id) fail('notAllowed', 403);
  if (role === 'president') {
    // hand over the presidency: the old president becomes a moderator
    memberOf(c, u.id)!.role = 'moderator';
    target.role = 'president';
    say(c, `أصبح ${nameOf(target.userId)} رئيس النادي`);
    notify(target.userId, 'clubs', 'أصبحت رئيس النادي', `سلّمك ${u.name} رئاسة نادي «${c.name}».`, { screen: 'club', id: c.id });
  } else if (role === 'moderator' || role === 'member') {
    if (role === 'moderator' && target.role !== 'moderator' && c.members.filter((m) => m.role === 'moderator').length >= CLUB_RULES.maxModerators) fail('tooManyModerators', 409);
    target.role = role;
    if (role === 'moderator') say(c, `أصبح ${nameOf(target.userId)} مشرفاً`);
  } else {
    fail('badRole');
  }
  db.touch();
}

export function updateClub(u: User, id: unknown, body: { motto?: unknown; type?: unknown; minLevel?: unknown; emblem?: unknown; color?: unknown }) {
  const c = clubOf(id);
  if (myRole(c, u) !== 'president') fail('notAllowed', 403);
  if (body.motto !== undefined) c.motto = cleanText(body.motto, 60) ?? '';
  if (body.type === 'open' || body.type === 'closed' || body.type === 'private') c.type = body.type;
  if (body.minLevel !== undefined) {
    const l = Number(body.minLevel);
    if (!Number.isInteger(l) || l < 1 || l > 100) fail('badLevel');
    c.minLevel = l;
  }
  if (body.emblem !== undefined) {
    const e = Number(body.emblem);
    if (!Number.isInteger(e) || e < 0 || e >= CLUB_RULES.emblems) fail('badEmblem');
    c.emblem = e;
  }
  if (body.color !== undefined) {
    const k = Number(body.color);
    if (!Number.isInteger(k) || k < 0 || k >= CLUB_RULES.colors) fail('badColor');
    c.color = k;
  }
  db.touch();
}

const lastChat = new Map<string, number>();

export function sendClubMessage(u: User, id: unknown, textArg: unknown) {
  const c = clubOf(id);
  if (!memberOf(c, u.id)) fail('notMember', 403);
  const text = cleanText(textArg, 300) ?? fail('badText');
  const now = Date.now();
  if (now - (lastChat.get(u.id) ?? 0) < 1000) fail('tooFast', 429);
  lastChat.set(u.id, now);
  say(c, text, u);
  db.touch();
  return c.chat[c.chat.length - 1];
}

/** Weekly points for a finished game (called by accounts.recordMatch). */
export function addClubPoints(u: User, points: number) {
  const c = u.clubId ? db.data.clubs[u.clubId] : undefined;
  if (!c || c.status !== 'active') return;
  rollWeek(c);
  const m = memberOf(c, u.id);
  if (!m) return;
  m.weekPoints += points;
  m.totalPoints += points;
}
