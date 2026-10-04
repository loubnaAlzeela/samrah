import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { TestPlayer, sleep, waitFor } from './helpers.ts';

// short timings and the admin key (must be set before the server modules load)
process.env.LAMMA_TURN_SECONDS = '0.2';
process.env.LAMMA_AUTO_MOVE_MS = '5';
process.env.LAMMA_AUTO_BID_MS = '5';
process.env.LAMMA_REVEAL_PAUSE_MS = '5';
process.env.LAMMA_TRICK_PAUSE_MS = '5';
process.env.LAMMA_HAND_PAUSE_MS = '50';
process.env.LAMMA_RECONNECT_SECONDS = '1';
process.env.LAMMA_COMP_SHOWUP_MS = '1500';
process.env.LAMMA_COMP_REVIEW_MS = '1500';
process.env.ADMIN_KEY = 'test-admin-key-123';
process.env.IAP_TEST_MODE = '1';
process.env.LAMMA_SIGNUPS_PER_HOUR = '1000';

const PORT = 2612;
const HTTP = `http://localhost:${PORT}/api`;
const WS = `ws://localhost:${PORT}`;
let server: { gracefullyShutdown: (exit?: boolean) => Promise<void> };
const players: TestPlayer[] = [];

beforeAll(async () => {
  const { startGameServer } = await import('../src/app.ts');
  server = await startGameServer(PORT);
});
afterAll(async () => {
  for (const p of players) await p.leave();
  await server.gracefullyShutdown(false);
});

type Json = Record<string, any>;

async function call(method: string, path: string, token?: string | null, body?: unknown, headers: Record<string, string> = {}): Promise<{ status: number; body: Json }> {
  const res = await fetch(HTTP + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: (await res.json()) as Json };
}
const ok = async (method: string, path: string, token?: string | null, body?: unknown) => {
  const r = await call(method, path, token, body);
  if (r.status !== 200) throw new Error(`${method} ${path} -> ${r.status} ${JSON.stringify(r.body)}`);
  return r.body;
};
const admin = (path: string, body?: unknown) => call(body === undefined ? 'GET' : 'POST', `/admin${path}`, null, body, { 'x-admin-key': 'test-admin-key-123' });

async function guest(name: string): Promise<{ token: string; me: Json }> {
  return (await ok('POST', '/auth/guest', null, { name })) as { token: string; me: Json };
}

describe('accounts', () => {
  it('a guest starts with the welcome balance, a number and level 1', async () => {
    const { token, me } = await guest('سامي');
    expect(me).toMatchObject({ name: 'سامي', units: 2000, stars: 20, level: 1, xp: 0, vip: false, giftTaken: false });
    expect(me.no).toBeGreaterThanOrEqual(100001);
    expect((await ok('GET', '/me', token)).id).toBe(me.id);
    expect((await call('GET', '/me', 'nope-not-a-token')).status).toBe(401);
    const notes = await ok('GET', '/notifications', token);
    expect(notes[0].title).toContain('أهلاً');
  });

  it('renames once a day, sets the country and the settings', async () => {
    const { token } = await guest('اسم');
    expect((await ok('PATCH', '/me', token, { name: 'اسم جديد', country: 'SA', settings: { showOnline: false, notify: { gifts: false } } })).name).toBe('اسم جديد');
    const again = await call('PATCH', '/me', token, { name: 'ثالث' });
    expect(again.body.error).toBe('renameTooSoon');
    const me = await ok('GET', '/me', token);
    expect(me).toMatchObject({ country: 'SA', settings: { showOnline: false, notify: { gifts: false, messages: true } } });
  });

  it('links an email + password and signs in with it on another phone', async () => {
    const { token, me } = await guest('بريد');
    expect((await call('POST', '/me/email', token, { email: 'a@b.co', password: 'short' })).body.error).toBe('weakPassword');
    await ok('POST', '/me/email', token, { email: 'Player@Example.com', password: 'secret-pass-1' });
    expect((await call('POST', '/auth/login', null, { email: 'player@example.com', password: 'wrong-pass-1' })).status).toBe(401);
    const login = await ok('POST', '/auth/login', null, { email: 'player@example.com', password: 'secret-pass-1' });
    expect(login.me.id).toBe(me.id);
    // changing the password needs the current one
    expect((await call('POST', '/me/email', login.token, { email: 'player@example.com', password: 'another-pass-2' })).body.error).toBe('wrongPassword');
    await ok('POST', '/me/signout-others', login.token);
    expect((await call('GET', '/me', token)).status).toBe(401);
  });

  it('deletes the account', async () => {
    const { token } = await guest('مؤقت');
    await ok('DELETE', '/me', token);
    expect((await call('GET', '/me', token)).status).toBe(401);
  });
});

describe('store & wallet', () => {
  it('buys and uses items, the gold membership, and the daily gift once a day', async () => {
    const { token } = await guest('متسوق');
    let me = await ok('POST', '/store/buy', token, { id: 'navy' });
    expect(me.units).toBe(1700);
    expect(me.owned).toContain('navy');
    expect((await call('POST', '/store/buy', token, { id: 'navy' })).body.error).toBe('owned');
    expect((await call('POST', '/store/use', token, { id: 'wine' })).body.error).toBe('notOwned');
    me = await ok('POST', '/store/use', token, { id: 'navy' });
    expect(me.backId).toBe('navy');
    expect((await call('POST', '/store/vip', token)).body.error).toBe('noStars');
    const gift = await ok('POST', '/store/gift', token);
    expect(gift.added).toBe(100);
    expect((await call('POST', '/store/gift', token)).body.error).toBe('giftTaken');
  });

  it('credits a purchase once (test store), and refuses unknown products', async () => {
    const { token } = await guest('مشتري');
    expect((await call('POST', '/purchases', token, { platform: 'test', productId: 'nope', token: 'x' })).body.error).toBe('badProduct');
    const first = await ok('POST', '/purchases', token, { platform: 'test', productId: 'stars_350', token: 'order-1' });
    expect(first).toMatchObject({ added: 400, currency: 'stars', already: false });
    expect(first.me.stars).toBe(420);
    const again = await ok('POST', '/purchases', token, { platform: 'test', productId: 'stars_350', token: 'order-1' });
    expect(again).toMatchObject({ added: 0, already: true });
    const other = await guest('آخر');
    expect((await call('POST', '/purchases', other.token, { platform: 'test', productId: 'stars_350', token: 'order-1' })).body.error).toBe('purchaseUsed');
    // the real stores are not configured in tests
    expect((await call('POST', '/purchases', token, { platform: 'android', productId: 'stars_50', token: 'tok' })).body.error).toBe('paymentsOff');
    const vip = await ok('POST', '/store/vip', token);
    expect(vip).toMatchObject({ vip: true, stars: 120 });
    expect(vip.owned).toContain('gold');
  });
});

describe('messages, blocking, reports', () => {
  it('sends private messages with unread counts; blocking stops them', async () => {
    const a = await guest('علي');
    const b = await guest('بدر');
    await ok('POST', `/messages/${b.me.id}`, a.token, { text: 'مرحبا يا بدر' });
    expect(await ok('GET', '/unread', b.token)).toMatchObject({ messages: 1 });
    const convs = await ok('GET', '/conversations', b.token);
    expect(convs[0]).toMatchObject({ user: { name: 'علي' }, unread: 1, last: { text: 'مرحبا يا بدر' } });
    const t = await ok('GET', `/messages/${a.me.id}`, b.token);
    expect(t.messages).toHaveLength(1);
    expect(await ok('GET', '/unread', b.token)).toMatchObject({ messages: 0 });
    await ok('POST', `/users/${a.me.id}/block`, b.token);
    expect((await call('POST', `/messages/${b.me.id}`, a.token, { text: 'هل وصلت؟' })).body.error).toBe('blocked');
    expect((await ok('GET', `/users/${b.me.no}`, a.token)).canMessage).toBe(false);
    await ok('DELETE', `/users/${a.me.id}/block`, b.token);
    await sleep(800);
    await ok('POST', `/messages/${b.me.id}`, a.token, { text: 'هل وصلت الآن؟' });
    await ok('POST', `/users/${a.me.id}/report`, b.token, { reason: 'إزعاج أو رسائل مزعجة', text: 'يرسل كثيراً' });
    await ok('POST', '/feedback', b.token, { kind: 'idea', text: 'أضيفوا لعبة الشدة' });
    const o = await admin('/overview');
    expect(o.body.reports[0]).toMatchObject({ reason: 'إزعاج أو رسائل مزعجة' });
    expect(o.body.feedback[0].text).toContain('الشدة');
  });

  it('the admin tools need the key', async () => {
    expect((await call('GET', '/admin/overview')).status).toBe(403);
    expect((await call('GET', '/admin/overview', null, undefined, { 'x-admin-key': 'wrong-key-wrong-1' })).status).toBe(403);
  });
});

describe('clubs', () => {
  it('a new club waits for approval, then players join by its type', async () => {
    const pres = await guest('رئيس');
    // not enough units at the start (2000 < 5000)
    expect((await call('POST', '/clubs', pres.token, { name: 'نادي الصقور', type: 'closed', agree: true })).body.error).toBe('noUnits');
    await admin(`/users/${pres.me.no}/credit`, { amount: 5000, currency: 'units' });
    expect((await call('POST', '/clubs', pres.token, { name: 'نادي الصقور', type: 'closed' })).body.error).toBe('mustAgree');
    const made = await ok('POST', '/clubs', pres.token, { name: 'نادي الصقور', motto: 'معاً', type: 'closed', agree: true, emblem: 2, color: 1 });
    expect(made.club).toMatchObject({ status: 'pending', myRole: 'president', type: 'closed' });
    expect(made.me.units).toBe(2000);
    // not listed and not joinable while pending
    const m = await guest('عضو');
    expect((await ok('GET', '/clubs', m.token)).map((c: Json) => c.name)).not.toContain('نادي الصقور');
    expect((await admin('/overview')).body.pendingClubs.map((c: Json) => c.name)).toContain('نادي الصقور');
    expect((await admin(`/clubs/${made.club.id}/approve`, {})).status).toBe(200);
    // closed: a request the president accepts
    expect((await ok('POST', `/clubs/${made.club.id}/join`, m.token)).result).toBe('requested');
    const detail = await ok('GET', `/clubs/${made.club.id}`, pres.token);
    expect(detail.requests.map((x: Json) => x.name)).toContain('عضو');
    await ok('POST', `/clubs/${made.club.id}/requests/${m.me.id}`, pres.token, { accept: true });
    expect((await ok('GET', '/clubs/mine', m.token)).club.myRole).toBe('member');
    await ok('POST', `/clubs/${made.club.id}/chat`, m.token, { text: 'السلام عليكم' });
    const chat = await ok('GET', `/clubs/${made.club.id}/chat`, pres.token);
    expect(chat.at(-1)).toMatchObject({ name: 'عضو', text: 'السلام عليكم' });
    // the member cannot manage, the president can promote
    expect((await call('POST', `/clubs/${made.club.id}/members/${pres.me.id}/role`, m.token, { role: 'member' })).status).toBe(403);
    await ok('POST', `/clubs/${made.club.id}/members/${m.me.id}/role`, pres.token, { role: 'moderator' });
    // private: invitation only
    await ok('PATCH', `/clubs/${made.club.id}`, pres.token, { type: 'private' });
    const x = await guest('مدعو');
    expect((await ok('GET', '/clubs', x.token)).map((c: Json) => c.name)).not.toContain('نادي الصقور');
    expect((await call('POST', `/clubs/${made.club.id}/join`, x.token)).body.error).toBe('inviteOnly');
    await ok('POST', `/clubs/${made.club.id}/invite`, m.token, { ref: x.me.no });
    expect((await ok('GET', '/clubs/mine', x.token)).invites[0].name).toBe('نادي الصقور');
    expect((await ok('POST', `/clubs/${made.club.id}/join`, x.token)).result).toBe('joined');
    // the president leaves: the moderator takes over
    await ok('POST', '/clubs/leave', pres.token);
    expect((await ok('GET', '/clubs/mine', m.token)).club.myRole).toBe('president');
  });

  it('a refused club gives the money back', async () => {
    const f = await guest('مؤسس');
    await admin(`/users/${f.me.no}/credit`, { amount: 5000, currency: 'units' });
    const made = await ok('POST', '/clubs', f.token, { name: 'نادي مرفوض', type: 'open', agree: true });
    await admin(`/clubs/${made.club.id}/reject`, { reason: 'الاسم غير مناسب' });
    const me = await ok('GET', '/me', f.token);
    expect(me).toMatchObject({ units: 7000, clubId: null });
  });
});

describe('competitions', () => {
  it('enforces the organiser rules: gold members only, the cost, the options', async () => {
    const o = await guest('منظم');
    const body = { variant: 'tarneeb', seats: 2, fee: 100, prize: 500, target: 31, minutes: 10, agree: true };
    expect((await call('POST', '/competitions', o.token, body)).body.error).toBe('vipOnly');
    await admin(`/users/${o.me.no}/credit`, { amount: 300, currency: 'stars' });
    await ok('POST', '/store/vip', o.token);
    expect((await call('POST', '/competitions', o.token, { ...body, seats: 3 })).body.error).toBe('badSeats');
    expect((await call('POST', '/competitions', o.token, { ...body, target: 99 })).body.error).toBe('badTarget');
    expect((await call('POST', '/competitions', o.token, { ...body, variant: 'trix', seats: 2, target: 0 })).body.error).toBe('badSeats');
    const c = await ok('POST', '/competitions', o.token, body);
    // prize 500 + commission max(50, 300*2=600) = 1100
    expect((await ok('GET', '/me', o.token)).units).toBe(2000 - 1100);
    expect(c).toMatchObject({ phase: 'registering', seats: 2, mine: true });
  });

  it('two teams play a real final; the winners are paid after the review', { timeout: 60_000 }, async () => {
    const o = await guest('منظم2');
    await admin(`/users/${o.me.no}/credit`, { amount: 300, currency: 'stars' });
    await ok('POST', '/store/vip', o.token);
    const c = await ok('POST', '/competitions', o.token, { variant: 'tarneeb', seats: 2, fee: 100, prize: 500, target: 31, minutes: 10, agree: true });
    const [a1, a2, b1, b2] = await Promise.all(['أ١', 'أ٢', 'ب١', 'ب٢'].map((n) => guest(n)));
    expect((await call('POST', `/competitions/${c.id}/join`, a1.token, {})).body.error).toBe('badPartner');
    await ok('POST', `/competitions/${c.id}/join`, a1.token, { partner: a2.me.no });
    expect((await call('POST', `/competitions/${c.id}/join`, a2.token, { partner: b1.me.no })).body.error).toBe('alreadyIn');
    // the second team fills the seats: the competition starts and a match room opens
    const joined = await ok('POST', `/competitions/${c.id}/join`, b1.token, { partner: b2.me.no });
    expect(joined.me.units).toBe(1900);
    let view: Json = {};
    for (let i = 0; i < 50 && !view.myMatch?.room; i++) {
      view = await ok('GET', `/competitions/${c.id}`, a1.token);
      await sleep(100);
    }
    expect(view.phase).toBe('running');
    const code = view.myMatch.room as string;
    // only the seated players may come in
    const stranger = new TestPlayer(WS, 'غريب');
    players.push(stranger);
    await expect(stranger.join(code, { auth: o.token })).rejects.toThrow();
    const tps = [a1, a2, b1, b2].map((p, i) => {
      const t = new TestPlayer(WS, `p${i}`);
      players.push(t);
      return { t, p };
    });
    for (const { t, p } of tps) await t.join(code, { auth: p.token });
    // partners sit opposite each other
    const seats = tps[0].t.view!.seats.map((s) => s?.uid);
    expect(seats[(seats.indexOf(a1.me.id) + 2) % 4]).toBe(a2.me.id);
    // nobody touches the screen: three timeouts each, then the computer plays for them to the end
    await waitFor(() => tps[0].t.view?.status === 'finished', 'final over', 50_000);
    for (let i = 0; i < 50 && view.phase !== 'review'; i++) {
      view = await ok('GET', `/competitions/${c.id}`, a1.token);
      await sleep(100);
    }
    expect(view.phase).toBe('review');
    expect(view.winner).toBeTruthy();
    // a complaint needs a real explanation
    expect((await call('POST', `/competitions/${c.id}/complain`, a1.token, { against: view.entrants[1].id, type: 'غش', text: 'غش' })).body.error).toBe('shortComplaint');
    // everyone says they have no complaints: paid at once
    await ok('POST', `/competitions/${c.id}/no-complaints`, a1.token);
    await ok('POST', `/competitions/${c.id}/no-complaints`, b1.token);
    view = await ok('GET', `/competitions/${c.id}`, a1.token);
    expect(view.phase).toBe('finished');
    const winners = view.entrants.find((e: Json) => e.name === view.winner).userIds as string[];
    for (const p of [a1, a2, b1, b2]) {
      const me = await ok('GET', '/me', p.token);
      const paid = p === a1 || p === b1 ? 100 : 0;
      expect(me.units).toBe(2000 - paid + (winners.includes(p.me.id) ? 250 : 0));
      // the finished game counted for everyone
      expect(me.stats.played).toBe(1);
    }
    // the organiser: 90% of the two fees
    expect((await ok('GET', '/me', o.token)).units).toBe(2000 - 1100 + 180);
  });

  it('cancelled below 75% at the deadline: fees back, the organiser pays 300 per seat', async () => {
    const { db } = await import('../src/data/db.ts');
    const { tickCompetitions } = await import('../src/competitions.ts');
    const o = await guest('منظم3');
    await admin(`/users/${o.me.no}/credit`, { amount: 300, currency: 'stars' });
    await ok('POST', '/store/vip', o.token);
    await admin(`/users/${o.me.no}/credit`, { amount: 1000, currency: 'units' });
    const c = await ok('POST', '/competitions', o.token, { variant: 'tarneeb', seats: 4, fee: 250, prize: 1000, target: 41, minutes: 10, agree: true });
    const [p1, p2] = await Promise.all(['ج١', 'ج٢'].map((n) => guest(n)));
    await ok('POST', `/competitions/${c.id}/join`, p1.token, { partner: p2.me.no });
    db.data.competitions[c.id].deadline = Date.now() - 1;
    await tickCompetitions();
    const view = await ok('GET', `/competitions/${c.id}`, p1.token);
    expect(view.phase).toBe('cancelled');
    expect((await ok('GET', '/me', p1.token)).units).toBe(2000);
    // paid 1000 + max(100, 4 × 300) = 2200, got back 2200 − 4 × 300
    expect((await ok('GET', '/me', o.token)).units).toBe(3000 - 2200 + 2200 - 1200);
  });
});
