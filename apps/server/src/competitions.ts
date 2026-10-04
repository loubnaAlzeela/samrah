// المسابقات — knockout competitions that players organise and play on real tables. The rules are the ones on the
// app's «شروط المسابقات» page, and every one of them is enforced here:
//
//   organising   gold members only, not banned from competitions, at most MAX_OPEN open at a time. On creation the
//                organiser pays the prize plus a commission of 10% of the prize or 300 per seat, whichever is larger.
//   joining      anyone (not blocked by the organiser, not banned); the entry fee is paid with the request and comes
//                back if the request is refused, withdrawn, or the competition is cancelled. In a partnership game
//                an entry is a team of two: the player names a partner by player number.
//   starting     when the seats are full, when the organiser starts it with at least 75% of the seats taken, or at
//                the deadline with 75% taken; below 75% at the deadline it is cancelled, the organiser loses 300
//                per seat and gets the rest back.
//   playing      each round's tables are real private rooms; only the seated entries may sit. Partnership tables
//                are team against team (the winners go through); solo tables have four players and the first two
//                go through, the final table's winner takes the prize. A player who does not come within
//                SHOW_UP_MS is replaced by the computer and is out (a team still plays if one partner came).
//   review       ten minutes for complaints after the final; it ends early when every entry says it has none.
//                Complaints still open freeze the competition until the organiser (or the team) settles it:
//                keep the result, name another winner, or refund every entry fee.
//   paying out   the winning seat gets the prize (half each in a partnership), the organiser 90% of the fees.
//   organiser    may kick an entry before the start (the fee stays in the pot; a kick the team finds unjust is
//                repaid by the organiser, who is then banned from competitions), may bar a player from their
//                competitions, and earns rating points per competition.
import { db } from './data/db.ts';
import { type User, credit, debit, findUser, isVip, recordCompetitionJoin, userById, blockedBetween } from './accounts.ts';
import { notify } from './social.ts';
import { cleanText, fail, newSecret, shuffle } from './util.ts';

export interface CompGame {
  variant: string;
  name: string;
  partnership: boolean;
  /** final scores a match may play to; empty = the game has its own */
  targets: number[];
}

export const COMP_GAMES: CompGame[] = [
  { variant: 'tarneeb', name: 'طرنيب', partnership: true, targets: [31, 41, 61] },
  { variant: 'syrian41', name: 'طرنيب سوري 41', partnership: true, targets: [41] },
  { variant: 'tarneeb400', name: '400', partnership: true, targets: [41] },
  { variant: 'trix', name: 'تركس', partnership: false, targets: [] },
  { variant: 'trixPartners', name: 'تركس شراكة', partnership: true, targets: [] },
  { variant: 'trixComplex', name: 'تركس كمبلكس', partnership: false, targets: [] },
  { variant: 'trixComplexPartners', name: 'تركس كمبلكس شراكة', partnership: true, targets: [] },
  { variant: 'baloot', name: 'بلوت', partnership: true, targets: [152] },
];

const num = (v: string | undefined, d: number) => (v && Number.isFinite(Number(v)) ? Number(v) : d);

export const COMP_RULES = {
  seatOptions: [2, 4, 8, 16, 32],
  perSeat: 300,
  reviewMs: num(process.env.LAMMA_COMP_REVIEW_MS, 10 * 60 * 1000),
  /** registration windows the organiser picks from (minutes) */
  registrationMinutes: [10, 30, 60, 180, 1440],
  fees: [0, 100, 250, 500, 1000],
  prizes: [500, 1000, 2000, 5000, 10000],
  maxOpen: 3,
  /** a seated player has this long to come to the table */
  showUpMs: num(process.env.LAMMA_COMP_SHOWUP_MS, 3 * 60 * 1000),
  /** a frozen competition the organiser leaves unsettled this long goes to the team */
  settleMs: 48 * 3600 * 1000,
  complaintTypes: ['غش', 'تخريب متعمّد', 'تواطؤ مع الخصم', 'إساءة في الدردشة', 'أخرى'],
};

export const minToStart = (seats: number) => Math.ceil((seats * 3) / 4);
export const commission = (prize: number, seats: number) => Math.max(Math.ceil(prize / 10), COMP_RULES.perSeat * seats);
export const creationCost = (prize: number, seats: number) => prize + commission(prize, seats);
export const cancelPenalty = (seats: number) => COMP_RULES.perSeat * seats;
export const organiserShare = (fee: number, entrants: number) => Math.floor(fee * entrants * 0.9);
export const prizePerPlayer = (prize: number, partnership: boolean) => (partnership ? Math.floor(prize / 2) : prize);

const gameOf = (variant: unknown) => COMP_GAMES.find((g) => g.variant === variant);
const tableSize = (g: CompGame) => (g.partnership ? 2 : 4);
const advance = (g: CompGame) => (g.partnership ? 1 : 2);
const seatOptions = (g: CompGame) => (g.partnership ? COMP_RULES.seatOptions : COMP_RULES.seatOptions.filter((s) => s >= 4));

export type CompPhase = 'registering' | 'running' | 'review' | 'frozen' | 'finished' | 'cancelled';

export interface CompEntry {
  id: string;
  userIds: string[];
  /** who paid the fee (the player who registered the team) */
  payer: string;
  paid: number;
  at: number;
}

export interface CompMatch {
  round: number;
  table: number;
  /** entry ids at this table (null = empty seat) */
  entries: (string | null)[];
  room: string | null;
  status: 'waiting' | 'playing' | 'done';
  /** the room proves it is this match's room with this secret (an app could create a room with any options) */
  key?: string;
  /** entries that went through */
  through: string[];
  createdAt: number;
}

export interface Complaint {
  id: string;
  from: string;
  fromUser: string;
  against: string;
  type: string;
  text: string;
  at: number;
}

export interface Competition {
  id: string;
  title: string;
  variant: string;
  seats: number;
  fee: number;
  prize: number;
  target: number;
  organiserId: string;
  createdAt: number;
  deadline: number;
  autoAccept: boolean;
  phase: CompPhase;
  entrants: CompEntry[];
  requests: CompEntry[];
  /** entries kicked by the organiser (kept for an appeal) */
  kicked: CompEntry[];
  /** players barred by the organiser */
  barred: string[];
  rounds: (string | null)[][];
  matches: CompMatch[];
  winner: string | null;
  reviewEndsAt: number | null;
  frozenAt: number | null;
  complaints: Complaint[];
  clear: string[];
  note: string | null;
  startedAt: number | null;
}

// ── rooms: app.ts plugs in the real match-maker, tests a fake ────────────────

export interface MatchRoomSpec {
  compId: string;
  match: number;
  key: string;
  variant: string;
  target: number;
  /** seat -> user id (null = a computer from the start) */
  seats: (string | null)[];
}
type RoomFactory = (spec: MatchRoomSpec) => Promise<string>;
let createMatchRoom: RoomFactory = async () => {
  throw new Error('no match room factory');
};
export const setMatchRoomFactory = (f: RoomFactory) => {
  createMatchRoom = f;
};
/** rooms alive in this process (after a restart the running matches are opened again) */
const liveRooms = new Set<string>();
/** A match room closed before its game ended (everyone left a finished table early is fine: it reported first). */
export const matchRoomClosed = (code: string) => liveRooms.delete(code);
/** True when [spec] is the match the competition is waiting for (a room made by an app with a guessed spec is not). */
export function isLiveMatch(spec: Pick<MatchRoomSpec, 'compId' | 'match' | 'key'>): boolean {
  const m = db.data.competitions[spec.compId]?.matches[spec.match];
  return !!m && m.status !== 'done' && !!m.key && m.key === spec.key;
}

// ── helpers ──────────────────────────────────────────────────────────────────

const compOf = (id: unknown): Competition => (typeof id === 'string' ? db.data.competitions[id] : undefined) ?? fail('badCompetition', 404);
const entryName = (e: CompEntry) => e.userIds.map((id) => userById(id)?.name ?? 'لاعب').join(' و ');
const entryById = (c: Competition, id: string | null) => (id ? (c.entrants.find((e) => e.id === id) ?? c.kicked.find((e) => e.id === id)) : undefined);
const entryOfUser = (c: Competition, userId: string) => c.entrants.find((e) => e.userIds.includes(userId));
const requestOfUser = (c: Competition, userId: string) => c.requests.find((e) => e.userIds.includes(userId));
const allUsers = (c: Competition) => [...new Set(c.entrants.flatMap((e) => e.userIds))];

function tell(userIds: string[], title: string, body: string, data?: Record<string, string>) {
  for (const id of new Set(userIds)) notify(id, 'competitions', title, body, data);
}

function rate(c: Competition, by: number) {
  const o = userById(c.organiserId);
  if (o) o.compRating = (o.compRating ?? 0) + by;
}

// ── reading ──────────────────────────────────────────────────────────────────

export function compView(c: Competition, viewer: User | null) {
  const g = gameOf(c.variant)!;
  const mine = viewer?.id === c.organiserId;
  const myEntry = viewer ? entryOfUser(c, viewer.id) : undefined;
  const myRequest = viewer ? requestOfUser(c, viewer.id) : undefined;
  const organiser = userById(c.organiserId);
  const named = (id: string | null) => (id ? (entryById(c, id) ? entryName(entryById(c, id)!) : '—') : null);
  const myMatch = myEntry ? c.matches.find((m) => m.status !== 'done' && m.entries.includes(myEntry.id)) : undefined;
  return {
    id: c.id,
    title: c.title,
    variant: c.variant,
    gameName: g.name,
    partnership: g.partnership,
    seats: c.seats,
    fee: c.fee,
    prize: c.prize,
    target: c.target,
    organiser: organiser ? { id: organiser.id, no: organiser.no, name: organiser.name, rating: organiser.compRating ?? 0 } : null,
    mine,
    createdAt: c.createdAt,
    deadline: c.deadline,
    autoAccept: c.autoAccept,
    phase: c.phase,
    entrants: c.entrants.map((e) => ({ id: e.id, name: entryName(e), userIds: e.userIds })),
    // the organiser sees the queue; everyone sees how long it is
    requests: mine ? c.requests.map((e) => ({ id: e.id, name: entryName(e), userIds: e.userIds })) : [],
    requestCount: c.requests.length,
    myEntry: myEntry ? { id: myEntry.id, name: entryName(myEntry) } : null,
    myRequest: myRequest ? { id: myRequest.id, name: entryName(myRequest) } : null,
    rounds: c.rounds.map((r) => r.map(named)),
    myMatch: myMatch ? { room: myMatch.room, status: myMatch.status, round: myMatch.round } : null,
    winner: named(c.winner),
    reviewEndsAt: c.reviewEndsAt,
    complaints: c.complaints.map((k) => ({ id: k.id, from: named(k.from), against: named(k.against), type: k.type, text: k.text, mine: k.fromUser === viewer?.id })),
    clear: c.clear.map(named),
    note: c.note,
    barred: mine ? c.barred.map((id) => ({ id, no: userById(id)?.no ?? 0, name: userById(id)?.name ?? 'لاعب' })) : [],
  };
}

/** Open and running competitions first, then the last finished ones. */
export function listCompetitions(viewer: User | null, variant?: unknown) {
  const all = Object.values(db.data.competitions).filter((c) => !variant || c.variant === variant);
  const live = all.filter((c) => c.phase !== 'finished' && c.phase !== 'cancelled').sort((a, b) => a.deadline - b.deadline);
  const done = all
    .filter((c) => c.phase === 'finished' || c.phase === 'cancelled')
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, 20);
  return [...live, ...done].map((c) => compView(c, viewer));
}

export const getCompetition = (id: unknown, viewer: User | null) => compView(compOf(id), viewer);

export function rulesView() {
  return { games: COMP_GAMES, ...COMP_RULES, minToStart: COMP_RULES.seatOptions.map(minToStart) };
}

// ── organising ───────────────────────────────────────────────────────────────

export function createCompetition(
  u: User,
  body: { title?: unknown; variant?: unknown; seats?: unknown; fee?: unknown; prize?: unknown; target?: unknown; minutes?: unknown; autoAccept?: unknown; agree?: unknown },
) {
  if (body.agree !== true) fail('mustAgree');
  if (!isVip(u)) fail('vipOnly', 403);
  if (u.compBanned) fail('compBanned', 403);
  const open = Object.values(db.data.competitions).filter((c) => c.organiserId === u.id && c.phase !== 'finished' && c.phase !== 'cancelled').length;
  if (open >= COMP_RULES.maxOpen) fail('tooManyOpen', 409, { max: COMP_RULES.maxOpen });
  const g = gameOf(body.variant) ?? fail('badGame');
  const seats = Number(body.seats);
  if (!seatOptions(g).includes(seats)) fail('badSeats');
  const fee = Number(body.fee);
  if (!COMP_RULES.fees.includes(fee)) fail('badFee');
  const prize = Number(body.prize);
  if (!COMP_RULES.prizes.includes(prize)) fail('badPrize');
  const minutes = Number(body.minutes ?? 30);
  if (!COMP_RULES.registrationMinutes.includes(minutes)) fail('badTime');
  let target = Number(body.target ?? g.targets[0] ?? 0);
  if (g.targets.length === 0) target = 0;
  else if (!g.targets.includes(target)) fail('badTarget');
  const title = cleanText(body.title, 40) ?? `مسابقة ${g.name}`;
  debit(u, 'units', creationCost(prize, seats), 'compCreate');
  const now = Date.now();
  const c: Competition = {
    id: db.id('c'),
    title,
    variant: g.variant,
    seats,
    fee,
    prize,
    target,
    organiserId: u.id,
    createdAt: now,
    deadline: now + minutes * 60000,
    autoAccept: body.autoAccept !== false,
    phase: 'registering',
    entrants: [],
    requests: [],
    kicked: [],
    barred: [],
    rounds: [],
    matches: [],
    winner: null,
    reviewEndsAt: null,
    frozenAt: null,
    complaints: [],
    clear: [],
    note: null,
    startedAt: null,
  };
  db.data.competitions[c.id] = c;
  db.touch();
  return compView(c, u);
}

/** The organiser takes [entry] off the queue into a seat. */
function seat(c: Competition, e: CompEntry) {
  c.requests = c.requests.filter((x) => x !== e);
  c.entrants.push(e);
  for (const id of e.userIds) {
    const p = userById(id);
    if (p) recordCompetitionJoin(p);
  }
  tell(e.userIds, `أنت في «${c.title}»`, 'تم تسجيلك في المسابقة. سنخبرك حين تبدأ مباراتك.', { screen: 'competition', id: c.id });
}

export function joinCompetition(u: User, id: unknown, partnerRef: unknown) {
  const c = compOf(id);
  const g = gameOf(c.variant)!;
  if (c.phase !== 'registering') fail('closed');
  if (entryOfUser(c, u.id) || requestOfUser(c, u.id)) fail('alreadyIn', 409);
  if (c.entrants.length >= c.seats) fail('full', 409);
  if (u.compBanned === 'all' || c.barred.includes(u.id)) fail('barred', 403);
  const organiser = userById(c.organiserId);
  if (organiser && organiser.id !== u.id && blockedBetween(u, organiser)) fail('barred', 403);
  const userIds = [u.id];
  if (g.partnership) {
    const p = findUser(partnerRef) ?? fail('badPartner', 404);
    if (p.id === u.id) fail('badPartner');
    if (entryOfUser(c, p.id) || requestOfUser(c, p.id)) fail('partnerIn', 409);
    if (c.barred.includes(p.id) || p.compBanned === 'all') fail('partnerBarred', 403);
    if (blockedBetween(u, p)) fail('blocked', 403);
    userIds.push(p.id);
  }
  debit(u, 'units', c.fee, `compFee:${c.id}`);
  const e: CompEntry = { id: db.id('e'), userIds, payer: u.id, paid: c.fee, at: Date.now() };
  if (g.partnership) notify(userIds[1], 'competitions', `سجّلك ${u.name} شريكاً`, `في مسابقة «${c.title}». يمكنك الانسحاب من صفحتها قبل البدء.`, { screen: 'competition', id: c.id });
  if (c.autoAccept || u.id === c.organiserId) {
    c.requests.push(e);
    seat(c, e);
  } else {
    c.requests.push(e);
    notify(c.organiserId, 'competitions', `طلب اشتراك في «${c.title}»`, `${entryName(e)} يريد الاشتراك.`, { screen: 'competition', id: c.id });
  }
  if (c.entrants.length >= c.seats) void start(c, 'full');
  db.touch();
  return compView(c, u);
}

/** A player (or their partner) withdraws before the start: the fee goes back to whoever paid it. */
export function leaveCompetition(u: User, id: unknown) {
  const c = compOf(id);
  if (c.phase !== 'registering') fail('started');
  const e = entryOfUser(c, u.id) ?? requestOfUser(c, u.id) ?? fail('notIn', 404);
  c.entrants = c.entrants.filter((x) => x !== e);
  c.requests = c.requests.filter((x) => x !== e);
  refundEntry(e, 'compLeave');
  const others = e.userIds.filter((x) => x !== u.id);
  if (others.length) tell(others, `انسحب فريقك من «${c.title}»`, `انسحب ${u.name} وأُعيدت الرسوم.`);
  db.touch();
}

function refundEntry(e: CompEntry, reason: string) {
  const payer = userById(e.payer);
  if (payer && e.paid > 0) credit(payer, 'units', e.paid, reason);
  e.paid = 0;
}

function requireOrganiser(c: Competition, u: User) {
  if (c.organiserId !== u.id) fail('notOrganiser', 403);
}

export function answerRequest(u: User, id: unknown, entryId: unknown, accept: boolean) {
  const c = compOf(id);
  requireOrganiser(c, u);
  if (c.phase !== 'registering') fail('closed');
  const e = c.requests.find((x) => x.id === entryId) ?? fail('badEntry', 404);
  if (accept) {
    if (c.entrants.length >= c.seats) fail('full', 409);
    seat(c, e);
    if (c.entrants.length >= c.seats) void start(c, 'full');
  } else {
    c.requests = c.requests.filter((x) => x !== e);
    refundEntry(e, 'compRefused');
    tell(e.userIds, 'لم يُقبل طلبك', `لم يقبل منظم «${c.title}» طلبك، وأُعيدت الرسوم.`);
  }
  db.touch();
}

export function acceptAll(u: User, id: unknown) {
  const c = compOf(id);
  requireOrganiser(c, u);
  if (c.phase !== 'registering') fail('closed');
  while (c.requests.length && c.entrants.length < c.seats) seat(c, c.requests[0]);
  if (c.entrants.length >= c.seats) void start(c, 'full');
  db.touch();
}

/** Before the start: the entry leaves; the fee stays in the pot (see the unjust-kick ruling in admin). */
export function kickEntry(u: User, id: unknown, entryId: unknown) {
  const c = compOf(id);
  requireOrganiser(c, u);
  if (c.phase !== 'registering') fail('started');
  const e = c.entrants.find((x) => x.id === entryId) ?? fail('badEntry', 404);
  c.entrants = c.entrants.filter((x) => x !== e);
  c.kicked.push(e);
  tell(e.userIds, `أُخرجت من «${c.title}»`, 'أخرجك المنظم من المسابقة. إن رأيته ظلماً فاعترض من صفحة المسابقة ليراجعه فريق سمرة.', { screen: 'competition', id: c.id });
  db.touch();
}

export function barPlayer(u: User, id: unknown, ref: unknown, bar: boolean) {
  const c = compOf(id);
  requireOrganiser(c, u);
  const p = findUser(ref) ?? fail('badUser', 404);
  // barring is per organiser: it applies to every competition this organiser runs
  for (const other of Object.values(db.data.competitions)) {
    if (other.organiserId !== u.id) continue;
    other.barred = other.barred.filter((x) => x !== p.id);
    if (bar) other.barred.push(p.id);
  }
  db.touch();
}

export function startNow(u: User, id: unknown) {
  const c = compOf(id);
  requireOrganiser(c, u);
  if (c.phase !== 'registering') fail('started');
  if (c.entrants.length < minToStart(c.seats)) fail('notEnough', 409, { need: minToStart(c.seats) });
  void start(c, 'organiser');
}

export function cancelByOrganiser(u: User, id: unknown) {
  const c = compOf(id);
  requireOrganiser(c, u);
  if (c.phase !== 'registering') fail('started');
  cancel(c, 'ألغاها المنظم قبل البدء');
}

// ── the life cycle ───────────────────────────────────────────────────────────

function cancel(c: Competition, why: string) {
  c.phase = 'cancelled';
  c.note = why;
  for (const e of [...c.entrants, ...c.requests]) refundEntry(e, 'compCancelled');
  const o = userById(c.organiserId);
  if (o) credit(o, 'units', creationCost(c.prize, c.seats) - cancelPenalty(c.seats), 'compCancelled');
  rate(c, -20);
  tell([...allUsers(c), ...c.requests.flatMap((e) => e.userIds), c.organiserId], `أُلغيت «${c.title}»`, `${why}. أُعيدت الرسوم.`, { screen: 'competition', id: c.id });
  c.requests = [];
  db.touch();
}

async function start(c: Competition, why: 'full' | 'organiser' | 'deadline') {
  if (c.phase !== 'registering') return;
  c.phase = 'running';
  c.startedAt = Date.now();
  // requests still waiting are turned away
  for (const e of c.requests) {
    refundEntry(e, 'compTurnedAway');
    tell(e.userIds, `بدأت «${c.title}»`, 'بدأت المسابقة قبل قبول طلبك، وأُعيدت الرسوم.');
  }
  c.requests = [];
  if (why !== 'deadline') rate(c, 5);
  const slots: (string | null)[] = shuffle(c.entrants.map((e) => e.id));
  // byes are spread out: one empty seat goes into every table that has room for it
  while (slots.length < c.seats) slots.splice(Math.floor(Math.random() * (slots.length + 1)), 0, null);
  c.rounds = [slots];
  tell(allUsers(c), `بدأت «${c.title}»`, 'ادخل صفحة المسابقة لترى طاولتك.', { screen: 'competition', id: c.id });
  db.touch();
  await openRound(c);
}

async function openRound(c: Competition) {
  const g = gameOf(c.variant)!;
  const round = c.rounds.length - 1;
  const slots = c.rounds[round];
  const size = tableSize(g);
  for (let t = 0; t * size < slots.length; t++) {
    const entries = slots.slice(t * size, t * size + size);
    const m: CompMatch = { round, table: t, entries, room: null, status: 'waiting', through: [], createdAt: Date.now() };
    c.matches.push(m);
    const present = entries.filter((x): x is string => x !== null);
    const keep = slots.length <= size ? 1 : advance(g);
    if (present.length <= keep) {
      // nobody to play against: the entries here go through as they are
      m.through = present;
      m.status = 'done';
      continue;
    }
    await openMatchRoom(c, m);
  }
  db.touch();
  maybeNextRound(c);
}

async function openMatchRoom(c: Competition, m: CompMatch) {
  const g = gameOf(c.variant)!;
  // partnership: team A on seats 0+2, team B on 1+3; solo: one entry per seat
  const seats: (string | null)[] = [null, null, null, null];
  if (g.partnership) {
    m.entries.forEach((eid, i) => {
      const e = entryById(c, eid);
      if (!e) return;
      seats[i] = e.userIds[0];
      seats[i + 2] = e.userIds[1] ?? null;
    });
  } else {
    m.entries.forEach((eid, i) => {
      seats[i] = entryById(c, eid)?.userIds[0] ?? null;
    });
  }
  try {
    m.key = newSecret();
    const code = await createMatchRoom({ compId: c.id, match: c.matches.indexOf(m), key: m.key, variant: c.variant, target: c.target, seats });
    m.room = code;
    m.status = 'playing';
    m.createdAt = Date.now();
    liveRooms.add(code);
    const users = m.entries.flatMap((eid) => entryById(c, eid)?.userIds ?? []);
    tell(users, `مباراتك في «${c.title}» جاهزة`, `ادخل الطاولة خلال ${Math.round(COMP_RULES.showUpMs / 60000)} دقائق وإلا لعب الكمبيوتر مكانك وخرجت من المسابقة.`, {
      screen: 'match',
      id: c.id,
      code,
    });
  } catch (e) {
    console.error('[competitions] could not open a match room', (e as Error).message);
  }
  db.touch();
}

/**
 * A match room reports its result: [ranking] is the seats from best to worst, [present] the seats whose player came.
 * Partnership: the first-ranked seat's team goes through. Solo: the best [keep] seats among the players who came.
 */
export function reportMatch(spec: Pick<MatchRoomSpec, 'compId' | 'match' | 'key'>, ranking: number[], present: number[]) {
  const c = db.data.competitions[spec.compId];
  const m = c?.matches[spec.match];
  if (!c || !m || m.status === 'done' || !m.key || m.key !== spec.key) return;
  const g = gameOf(c.variant)!;
  if (m.room) liveRooms.delete(m.room);
  const keep = c.rounds[m.round].length <= tableSize(g) ? 1 : advance(g);
  if (g.partnership) {
    // a team whose two players stayed away is out even if the computer won for it
    const teamCame = (t: number) => present.includes(t) || present.includes(t + 2);
    const order = ranking.map((s) => s % 2).filter((t, i, a) => a.indexOf(t) === i);
    const winner = order.find((t) => teamCame(t) && m.entries[t]);
    m.through = winner !== undefined ? [m.entries[winner]!] : [];
  } else {
    m.through = ranking
      .filter((s) => present.includes(s) && m.entries[s])
      .slice(0, keep)
      .map((s) => m.entries[s]!);
  }
  m.status = 'done';
  db.touch();
  maybeNextRound(c);
}

function maybeNextRound(c: Competition) {
  if (c.phase !== 'running') return;
  const g = gameOf(c.variant)!;
  const round = c.rounds.length - 1;
  const matches = c.matches.filter((m) => m.round === round);
  if (matches.some((m) => m.status !== 'done')) return;
  const keep = c.rounds[round].length <= tableSize(g) ? 1 : advance(g);
  if (c.rounds[round].length <= tableSize(g)) {
    // the final table is over
    const w = matches[0]?.through[0] ?? null;
    c.winner = w;
    if (!w) {
      // no one came to the final: nobody wins, the prize goes back to the organiser
      c.phase = 'finished';
      c.note = 'لم يحضر أحد إلى المباراة النهائية، فأُعيدت الجائزة إلى المنظم';
      const o = userById(c.organiserId);
      if (o) credit(o, 'units', c.prize, 'compNoWinner');
      payOrganiser(c);
      db.touch();
      return;
    }
    c.phase = 'review';
    c.reviewEndsAt = Date.now() + COMP_RULES.reviewMs;
    tell(allUsers(c), `انتهت مباريات «${c.title}»`, `الفائز: ${entryName(entryById(c, w)!)}. أمامكم 10 دقائق للشكاوى قبل توزيع الجائزة.`, { screen: 'competition', id: c.id });
    db.touch();
    return;
  }
  const next: (string | null)[] = [];
  for (const m of matches) for (let k = 0; k < keep; k++) next.push(m.through[k] ?? null);
  c.rounds.push(next);
  db.touch();
  void openRound(c);
}

function payOrganiser(c: Competition) {
  const o = userById(c.organiserId);
  const paidEntries = [...c.entrants, ...c.kicked].filter((e) => e.paid > 0).length;
  if (o) credit(o, 'units', organiserShare(c.fee, paidEntries), `compShare:${c.id}`);
}

function finish(c: Competition) {
  c.phase = 'finished';
  const g = gameOf(c.variant)!;
  const w = entryById(c, c.winner);
  if (w) {
    for (const id of w.userIds) {
      const p = userById(id);
      if (p) credit(p, 'units', prizePerPlayer(c.prize, g.partnership), `compPrize:${c.id}`);
    }
    tell(w.userIds, `مبروك! فزت في «${c.title}»`, `أُضيفت ${prizePerPlayer(c.prize, g.partnership)} وحدة إلى محفظتك.`, { screen: 'competition', id: c.id });
    rate(c, 10);
  }
  payOrganiser(c);
  tell([c.organiserId], `انتهت «${c.title}»`, 'وُزّعت الجائزة وأُضيفت حصتك من رسوم الاشتراك إلى محفظتك.', { screen: 'competition', id: c.id });
  db.touch();
}

// ── review ───────────────────────────────────────────────────────────────────

export function complain(u: User, id: unknown, body: { against?: unknown; type?: unknown; text?: unknown }) {
  const c = compOf(id);
  if (c.phase !== 'review') fail('reviewOver');
  const mine = entryOfUser(c, u.id) ?? fail('notIn', 403);
  const against = c.entrants.find((e) => e.id === body.against) ?? (body.against === 'organiser' ? null : fail('badEntry'));
  if (typeof body.type !== 'string' || !COMP_RULES.complaintTypes.includes(body.type)) fail('badType');
  const text = cleanText(body.text, 600) ?? fail('badText');
  // the explanation must say something: four real words at least
  if (text.split(/\s+/).filter((w) => w.length > 1).length < 4) fail('shortComplaint');
  c.complaints.push({ id: db.id('q'), from: mine.id, fromUser: u.id, against: against?.id ?? 'organiser', type: body.type as string, text, at: Date.now() });
  c.clear = c.clear.filter((x) => x !== mine.id);
  notify(c.organiserId, 'competitions', `شكوى في «${c.title}»`, `${u.name}: ${body.type}`, { screen: 'competition', id: c.id });
  db.touch();
}

/** «لا توجد لدي أي شكاوى» — also withdraws the player's own complaints. */
export function noComplaints(u: User, id: unknown) {
  const c = compOf(id);
  if (c.phase !== 'review') fail('reviewOver');
  const mine = entryOfUser(c, u.id) ?? fail('notIn', 403);
  c.complaints = c.complaints.filter((k) => k.from !== mine.id);
  if (!c.clear.includes(mine.id)) c.clear.push(mine.id);
  maybeCloseReview(c);
  db.touch();
}

function maybeCloseReview(c: Competition) {
  if (c.complaints.length === 0 && c.entrants.every((e) => c.clear.includes(e.id))) finish(c);
}

/** The organiser (or the team) settles a frozen competition. */
export function settle(u: User | 'admin', id: unknown, body: { action?: unknown; winner?: unknown }) {
  const c = compOf(id);
  if (u !== 'admin') requireOrganiser(c, u);
  if (c.phase !== 'frozen' && !(u === 'admin' && c.phase === 'review')) fail('notFrozen');
  if (body.action === 'confirm') {
    c.note = 'راجع المنظم الشكاوى واعتمد النتيجة';
    finish(c);
  } else if (body.action === 'winner') {
    const e = c.entrants.find((x) => x.id === body.winner) ?? fail('badEntry');
    c.winner = e.id;
    c.note = 'راجع المنظم الشكاوى وعيّن الفائز';
    finish(c);
  } else if (body.action === 'refund') {
    for (const e of [...c.entrants, ...c.kicked]) refundEntry(e, 'compRefundAll');
    const o = userById(c.organiserId);
    if (o) credit(o, 'units', c.prize, 'compRefundAll');
    c.winner = null;
    c.phase = 'finished';
    c.note = 'أعاد المنظم رسوم الاشتراك لكل اللاعبين وأُلغيت النتيجة';
    tell(allUsers(c), `أُلغيت نتيجة «${c.title}»`, 'أُعيدت رسوم الاشتراك إلى محفظتك.', { screen: 'competition', id: c.id });
  } else {
    fail('badAction');
  }
  if (u === 'admin') c.note = `${c.note} (بقرار فريق سمرة)`;
  db.touch();
}

/** A player appeals the organiser's decision (a kick, a ruling): it reaches the team as a report. */
export function appeal(u: User, id: unknown, textArg: unknown) {
  const c = compOf(id);
  const text = cleanText(textArg, 600) ?? fail('badText');
  db.data.reports.push({ id: db.id('r'), from: u.id, against: c.organiserId, reason: 'اعتراض على منظم مسابقة', text, at: Date.now(), where: `competition:${c.id}` });
  db.touch();
}

/** The team rules a kick unjust: the organiser repays the fee and is banned from competitions. */
export function unjustKick(id: unknown, entryId: unknown) {
  const c = compOf(id);
  const e = c.kicked.find((x) => x.id === entryId) ?? fail('badEntry', 404);
  const o = userById(c.organiserId);
  const payer = userById(e.payer);
  if (o && payer && e.paid > 0) {
    o.units -= e.paid; // may go below zero: the organiser owes it
    db.data.ledger.push({ userId: o.id, currency: 'units', amount: -e.paid, balance: o.units, reason: `compUnjustKick:${c.id}`, at: Date.now() });
    credit(payer, 'units', e.paid, `compUnjustKick:${c.id}`);
    e.paid = 0;
  }
  if (o) {
    o.compBanned = 'all';
    rate(c, -50);
    notify(o.id, 'competitions', 'حُظرت من المسابقات', `رأى فريق سمرة أن إخراج لاعب من «${c.title}» كان بلا مبرر.`);
  }
  tell(e.userIds, 'قُبل اعتراضك', `أُعيدت إليك رسوم «${c.title}».`);
  db.touch();
}

// ── the clock (every few seconds, from app.ts) ───────────────────────────────

export async function tickCompetitions(now = Date.now()) {
  for (const c of Object.values(db.data.competitions)) {
    if (c.phase === 'registering' && now >= c.deadline) {
      if (c.entrants.length >= minToStart(c.seats)) await start(c, 'deadline');
      else cancel(c, `لم يكتمل الحد الأدنى من اللاعبين (${minToStart(c.seats)} من ${c.seats}) قبل موعد البدء`);
    } else if (c.phase === 'running') {
      // a match whose room is gone (the server restarted) is played again
      for (const m of c.matches) if (m.status === 'playing' && m.room && !liveRooms.has(m.room)) await openMatchRoom(c, m);
    } else if (c.phase === 'review' && c.reviewEndsAt && now >= c.reviewEndsAt) {
      if (c.complaints.length === 0) finish(c);
      else {
        c.phase = 'frozen';
        c.frozenAt = now;
        tell([c.organiserId], `«${c.title}» مجمّدة`, 'بقيت شكاوى مفتوحة. راجعها واحسمها من صفحة المسابقة.', { screen: 'competition', id: c.id });
        db.touch();
      }
    }
  }
}

/** Frozen competitions the organiser left alone for two days (for the admin page). */
export function staleFrozen() {
  return Object.values(db.data.competitions).filter((c) => c.phase === 'frozen' && c.frozenAt && Date.now() - c.frozenAt > COMP_RULES.settleMs);
}
