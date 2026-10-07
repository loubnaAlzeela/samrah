// The app's HTTP API (JSON under /api), next to the game rooms on the same port. Every call but the sign-in ones
// carries `Authorization: Bearer <session token>`. A refusal answers {error: code} with a 4xx status; the app turns
// the code into Arabic (lib/services/error_text.dart).
import express, { type NextFunction, type Request, type Response, Router } from 'express';
import { matchMaker } from '@colyseus/core';
import * as A from './accounts.ts';
import * as S from './social.ts';
import * as K from './clubs.ts';
import * as C from './competitions.ts';
import { GIFTS } from './gifts.ts';
import { paymentsStatus, verifyPurchase } from './payments.ts';
import { pushReady } from './push.ts';
import { appleReady, googleReady, phoneReady, sendPhoneCode, signInWithApple, signInWithGoogle, verifyPhoneCode } from './auth-providers.ts';
import { db } from './data/db.ts';
import { ApiError, fail } from './util.ts';
import { adminRouter } from './admin.ts';
import { LEGAL } from './legal.ts';

type Handler = (req: Request, res: Response) => unknown;

const tokenOf = (req: Request) => {
  const h = req.headers.authorization;
  return h && h.startsWith('Bearer ') ? h.slice(7) : null;
};

/** Wraps a handler: sync or async, its return value is sent as JSON, an ApiError becomes {error}. */
const route =
  (h: Handler) =>
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const out = await h(req, res);
      if (!res.headersSent) res.json(out ?? { ok: true });
    } catch (e) {
      next(e);
    }
  };

const me = (req: Request) => A.requireUser(tokenOf(req));
const maybeMe = (req: Request) => A.userByToken(tokenOf(req));

/** A few sign-ups per address per hour (a guest account is one tap). */
const SIGNUPS_PER_HOUR = Number(process.env.LAMMA_SIGNUPS_PER_HOUR) || 20;
const signups = new Map<string, number[]>();
function limitSignups(req: Request) {
  const ip = (req.headers['x-forwarded-for'] as string | undefined)?.split(',')[0]?.trim() || req.socket.remoteAddress || '?';
  const now = Date.now();
  const recent = (signups.get(ip) ?? []).filter((t) => now - t < 3600000);
  if (recent.length >= SIGNUPS_PER_HOUR) fail('tooMany', 429);
  recent.push(now);
  signups.set(ip, recent);
}

export function apiRouter(): Router {
  const r = Router();
  r.use(express.json({ limit: '32kb' }));

  // ── public ────────────────────────────────────────────────────────────────
  r.get('/health', route(() => ({ ok: true, at: Date.now() })));
  r.get('/legal', route(() => LEGAL));
  r.get(
    '/config',
    route(() => ({
      economy: A.ECONOMY,
      items: A.ITEMS,
      gifts: GIFTS,
      clubs: { unlockLevel: K.clubsUnlockLevel(), createCost: K.CLUB_RULES.createCost, maxMembers: K.CLUB_RULES.maxMembers, maxModerators: K.CLUB_RULES.maxModerators },
      competitions: C.rulesView(),
      payments: (({ android, ios, test }) => ({ android, ios, test }))(paymentsStatus()),
      products: paymentsStatus().products,
      push: pushReady(),
      auth: { phone: phoneReady(), google: googleReady(), apple: appleReady() },
      reportReasons: S.REPORT_REASONS,
    })),
  );

  // ── signing in ────────────────────────────────────────────────────────────
  r.post(
    '/auth/guest',
    route((req) => {
      limitSignups(req);
      const { user, token } = A.createGuest(req.body?.name, req.body?.country);
      return { token, me: A.meView(user) };
    }),
  );
  r.post(
    '/auth/login',
    route((req) => {
      const { user, token } = A.loginWithEmail(req.body?.email, req.body?.password);
      return { token, me: A.meView(user) };
    }),
  );
  r.post(
    '/auth/logout',
    route((req) => {
      const t = tokenOf(req);
      if (t) A.signOut(t);
    }),
  );
  r.post('/auth/phone/send', route((req) => sendPhoneCode(req.body?.phone)));
  r.post(
    '/auth/phone/verify',
    route(async (req) => {
      const out = await verifyPhoneCode(maybeMe(req), req.body?.phone, req.body?.code, req.body?.name);
      return { token: out.token, linked: out.linked, me: A.meView(out.user) };
    }),
  );
  r.post(
    '/auth/google',
    route(async (req) => {
      const out = await signInWithGoogle(maybeMe(req), req.body?.idToken, req.body?.name);
      return { token: out.token, linked: out.linked, me: A.meView(out.user) };
    }),
  );

  r.post(
    '/auth/apple',
    route(async (req) => {
      const out = await signInWithApple(maybeMe(req), req.body?.idToken, req.body?.name);
      return { token: out.token, linked: out.linked, me: A.meView(out.user) };
    }),
  );

  // ── my account ────────────────────────────────────────────────────────────
  r.get('/me', route((req) => A.meView(me(req))));
  r.patch(
    '/me',
    route((req) => {
      const u = me(req);
      const b = req.body ?? {};
      if (b.name !== undefined) A.rename(u, b.name);
      if (b.country !== undefined) A.setCountry(u, b.country);
      if (b.settings !== undefined) A.updateSettings(u, b.settings);
      return A.meView(u);
    }),
  );
  r.post(
    '/me/email',
    route((req) => {
      const u = me(req);
      A.setEmailPassword(u, req.body?.email, req.body?.password, req.body?.current);
      return A.meView(u);
    }),
  );
  r.post(
    '/me/signout-others',
    route((req) => {
      const u = me(req);
      A.signOutOthers(u, tokenOf(req)!);
      return A.meView(u);
    }),
  );
  r.delete(
    '/me',
    route((req) => {
      const u = me(req);
      if (u.clubId) K.leaveClub(u);
      A.deleteAccount(u);
    }),
  );
  r.post('/me/push', route((req) => A.addPushToken(me(req), req.body?.token)));
  r.get('/unread', route((req) => S.unreadCounts(me(req))));

  // ── other players ─────────────────────────────────────────────────────────
  r.get(
    '/users/:ref',
    route((req) => {
      const viewer = me(req);
      const u = A.findUser(req.params.ref) ?? fail('badUser', 404);
      return A.publicProfile(u, viewer);
    }),
  );
  r.post(
    '/users/:id/block',
    route((req) => {
      const u = me(req);
      A.block(u, A.userById(req.params.id) ?? fail('badUser', 404));
      return A.meView(u);
    }),
  );
  r.delete(
    '/users/:id/block',
    route((req) => {
      const u = me(req);
      A.unblock(u, String(req.params.id));
      return A.meView(u);
    }),
  );
  r.post('/users/:id/report', route((req) => S.report(me(req), req.params.id, req.body?.reason, req.body?.text, req.body?.where)));
  r.post('/feedback', route((req) => S.feedback(me(req), req.body?.kind, req.body?.text)));

  // ── store & wallet ────────────────────────────────────────────────────────
  const wallet = (u: A.User) => A.meView(u);
  r.post('/store/buy', route((req) => (A.buyItem(me(req), req.body?.id), wallet(me(req)))));
  r.post('/store/use', route((req) => (A.useItem(me(req), req.body?.id), wallet(me(req)))));
  r.post('/store/vip', route((req) => (A.buyVip(me(req)), wallet(me(req)))));
  r.post(
    '/store/gift',
    route((req) => {
      const u = me(req);
      const added = A.claimGift(u);
      return { added, me: A.meView(u) };
    }),
  );
  r.post(
    '/purchases',
    route(async (req) => {
      const u = me(req);
      const out = await verifyPurchase(u, req.body ?? {});
      return { ...out, me: A.meView(u) };
    }),
  );

  // ── challenges ────────────────────────────────────────────────────────────
  r.get('/challenges', route((req) => A.challengesView(me(req))));
  r.post(
    '/challenges/:id/claim',
    route((req) => {
      const u = me(req);
      A.claimChallenge(u, req.params.id);
      return { challenges: A.challengesView(u), me: A.meView(u) };
    }),
  );

  // ── notifications & messages ──────────────────────────────────────────────
  r.get('/notifications', route((req) => S.notificationsOf(me(req))));
  r.post('/notifications/read', route((req) => S.markNotificationsRead(me(req), req.body?.ids)));
  r.delete('/notifications', route((req) => S.clearNotifications(me(req))));
  r.get('/conversations', route((req) => S.conversations(me(req))));
  r.delete('/conversations/:id', route((req) => S.deleteConversation(me(req), req.params.id)));
  r.get(
    '/messages/:id',
    route((req) => {
      const u = me(req);
      const other = A.userById(req.params.id) ?? fail('badUser', 404);
      return { user: A.publicProfile(other, u), messages: S.thread(u, other.id, Number(req.query.before) || undefined) };
    }),
  );
  r.post('/messages/:id', route((req) => S.sendMessage(me(req), req.params.id, req.body?.text)));

  // ── ranking & tables ──────────────────────────────────────────────────────
  r.get(
    '/leaderboard',
    route((req) => {
      const u = me(req);
      const scope = req.query.scope === 'all' ? 'all' : 'week';
      const variant = typeof req.query.variant === 'string' && req.query.variant ? req.query.variant : null;
      const week = (x: A.User) => (A.rollPeriods(x), x.stats.weekXp);
      const score = (x: A.User) => (variant ? (x.stats.byVariant[variant]?.won ?? 0) : scope === 'all' ? x.xp : week(x));
      const rows = Object.values(db.data.users)
        .filter((x) => x.settings.showInRanking && !x.banned && score(x) > 0)
        .sort((a, b) => score(b) - score(a));
      const line = (x: A.User, i: number) => ({ rank: i + 1, id: x.id, no: x.no, name: x.name, level: A.levelOf(x.xp), country: x.country, score: score(x), online: A.isOnline(x) });
      const mine = rows.findIndex((x) => x.id === u.id);
      return { scope, variant, top: rows.slice(0, 100).map(line), me: mine >= 0 ? line(u, mine) : { ...line(u, rows.length), rank: null } };
    }),
  );
  r.get('/clubs-ranking', route(() => K.clubRanking()));
  r.get(
    '/tables',
    route(async (req) => {
      const rooms = await matchMaker.query({ name: 'lamma' });
      const variant = typeof req.query.variant === 'string' ? req.query.variant : null;
      return rooms
        .filter((x) => !x.private && x.metadata && (!variant || x.metadata.variant === variant))
        .map((x) => x.metadata)
        .sort((a, b) => Number(b.joinable) - Number(a.joinable) || Number(a.status === 'playing') - Number(b.status === 'playing'));
    }),
  );

  // ── clubs ─────────────────────────────────────────────────────────────────
  r.get('/clubs', route((req) => (me(req), K.listClubs(req.query.q))));
  r.get(
    '/clubs/mine',
    route((req) => {
      const u = me(req);
      const pending = Object.values(db.data.clubs).find((c) => c.requests.some((q) => q.userId === u.id));
      return {
        club: u.clubId ? K.clubDetail(u.clubId, u) : null,
        invites: K.myInvites(u),
        requestedId: pending?.id ?? null,
        unlockLevel: K.clubsUnlockLevel(),
        level: A.levelOf(u.xp),
      };
    }),
  );
  r.post(
    '/clubs',
    route((req) => {
      const u = me(req);
      const c = K.createClub(u, req.body ?? {});
      return { club: K.clubDetail(c.id, u), me: A.meView(u) };
    }),
  );
  r.post(
    '/clubs/leave',
    route((req) => {
      const u = me(req);
      K.leaveClub(u);
      return A.meView(u);
    }),
  );
  r.get('/clubs/:id', route((req) => K.clubDetail(req.params.id, me(req))));
  r.patch('/clubs/:id', route((req) => (K.updateClub(me(req), req.params.id, req.body ?? {}), K.clubDetail(req.params.id, me(req)))));
  r.post('/clubs/:id/join', route((req) => ({ result: K.joinClub(me(req), req.params.id) })));
  r.post('/clubs/:id/cancel-request', route((req) => K.cancelRequest(me(req), req.params.id)));
  r.post('/clubs/:id/decline', route((req) => K.declineInvite(me(req), req.params.id)));
  r.post('/clubs/:id/requests/:uid', route((req) => K.answerRequest(me(req), req.params.id, req.params.uid, req.body?.accept === true)));
  r.post('/clubs/:id/invite', route((req) => K.invite(me(req), req.params.id, req.body?.ref)));
  r.delete('/clubs/:id/invite/:uid', route((req) => K.cancelInvite(me(req), req.params.id, req.params.uid)));
  r.delete('/clubs/:id/members/:uid', route((req) => K.removeMember(me(req), req.params.id, req.params.uid)));
  r.post('/clubs/:id/members/:uid/role', route((req) => K.setRole(me(req), req.params.id, req.params.uid, req.body?.role)));
  r.get('/clubs/:id/chat', route((req) => K.clubChat(req.params.id, me(req), Number(req.query.after) || undefined)));
  r.post('/clubs/:id/chat', route((req) => K.sendClubMessage(me(req), req.params.id, req.body?.text)));

  // ── competitions ──────────────────────────────────────────────────────────
  r.get('/competitions', route((req) => C.listCompetitions(me(req), req.query.variant || undefined)));
  r.get('/competitions/rules', route(() => C.rulesView()));
  r.post('/competitions', route((req) => C.createCompetition(me(req), req.body ?? {})));
  r.get('/competitions/:id', route((req) => C.getCompetition(req.params.id, me(req))));
  const act = (f: (u: A.User, id: string, req: Request) => unknown) =>
    route(async (req) => {
      const u = me(req);
      await f(u, String(req.params.id), req);
      return { competition: C.getCompetition(req.params.id, u), me: A.meView(u) };
    });
  r.post('/competitions/:id/join', act((u, id, req) => C.joinCompetition(u, id, req.body?.partner)));
  r.post('/competitions/:id/leave', act((u, id) => C.leaveCompetition(u, id)));
  r.post('/competitions/:id/requests/:eid', act((u, id, req) => C.answerRequest(u, id, req.params.eid, req.body?.accept === true)));
  r.post('/competitions/:id/accept-all', act((u, id) => C.acceptAll(u, id)));
  r.post('/competitions/:id/kick/:eid', act((u, id, req) => C.kickEntry(u, id, req.params.eid)));
  r.post('/competitions/:id/bar', act((u, id, req) => C.barPlayer(u, id, req.body?.ref, req.body?.bar !== false)));
  r.post('/competitions/:id/start', act((u, id) => C.startNow(u, id)));
  r.post('/competitions/:id/cancel', act((u, id) => C.cancelByOrganiser(u, id)));
  r.post('/competitions/:id/complain', act((u, id, req) => C.complain(u, id, req.body ?? {})));
  r.post('/competitions/:id/no-complaints', act((u, id) => C.noComplaints(u, id)));
  r.post('/competitions/:id/settle', act((u, id, req) => C.settle(u, id, req.body ?? {})));
  r.post('/competitions/:id/appeal', act((u, id, req) => C.appeal(u, id, req.body?.text)));

  // ── the team ──────────────────────────────────────────────────────────────
  r.use('/admin', adminRouter());

  r.use((_req, _res, next) => next(new ApiError(404, 'notFound')));
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  r.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof ApiError) {
      res.status(err.status).json({ error: err.code, ...(err.extra ?? {}) });
      return;
    }
    if (err && typeof err === 'object' && 'type' in err && (err as { type: string }).type === 'entity.parse.failed') {
      res.status(400).json({ error: 'badJson' });
      return;
    }
    console.error('[api]', err);
    res.status(500).json({ error: 'server' });
  });
  return r;
}
