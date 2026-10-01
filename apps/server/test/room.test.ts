import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Client } from '@colyseus/sdk';
import { TestPlayer, sleep, waitFor } from './helpers.ts';

// short test timings (must be set before the room module is loaded)
process.env.LAMMA_TURN_SECONDS = '0.25';
process.env.LAMMA_AUTO_MOVE_MS = '10';
process.env.LAMMA_AUTO_BID_MS = '10';
process.env.LAMMA_REVEAL_PAUSE_MS = '10';
process.env.LAMMA_TRICK_PAUSE_MS = '10';
process.env.LAMMA_HAND_PAUSE_MS = '400';
process.env.LAMMA_RECONNECT_SECONDS = '2';
process.env.LAMMA_QUICK_FILL_MS = '300';

const PORT = 2611;
const EP = `ws://localhost:${PORT}`;
let server: { gracefullyShutdown: (exit?: boolean) => Promise<void> };
const players: TestPlayer[] = [];
const P = (name: string) => {
  const p = new TestPlayer(EP, name);
  players.push(p);
  return p;
};

beforeAll(async () => {
  const { startGameServer } = await import('../src/app.ts');
  server = await startGameServer(PORT);
});
afterAll(async () => {
  for (const p of players) await p.leave();
  await server.gracefullyShutdown(false);
});

describe('room creation + settings', () => {
  it('creates with settings; host is the creator; joiners are auto-seated', async () => {
    const host = P('مضيف');
    const code = await host.create('tarneeb', { speed: 'fast', target: 31, chat: false, kick: true, noLeave: true, minLevel: 3, voice: true });
    expect(code).toMatch(/^[A-Z2-9]{6}$/);
    expect(host.view!.settings).toMatchObject({ speed: 'fast', target: 31, chat: false, kick: true, noLeave: true, minLevel: 3, voice: true, visibility: 'private' });
    expect(host.view!.isOwner).toBe(true);
    expect(host.view!.mySeat).toBe(0);
    const b = P('ب');
    await b.join(code);
    expect(b.view!.isOwner).toBe(false);
    expect(b.view!.mySeat).toBe(1);
    expect(b.view!.seats[1]).toMatchObject({ name: 'ب', bot: false, level: 1 });
  });

  it('rejects invalid settings at creation', async () => {
    await expect(new Client(EP).create('lamma', { variant: 'tarneeb', settings: { speed: 'warp' }, name: 'x' })).rejects.toThrow();
    await expect(new Client(EP).create('lamma', { variant: 'tarneeb', settings: { minLevel: 0 }, name: 'x' })).rejects.toThrow();
    await expect(new Client(EP).create('lamma', { variant: 'tarneeb', settings: { evil: 1 }, name: 'x' })).rejects.toThrow();
  });

  it('only the host changes settings, only before the start', async () => {
    const host = P('h');
    const code = await host.create('tarneeb');
    const other = P('o');
    await other.join(code);
    other.send('settings', { speed: 'slow' });
    await waitFor(() => other.errors.includes('notOwner'), 'notOwner');
    host.send('settings', { speed: 'slow', target: 61, visibility: 'public' });
    await waitFor(() => other.view!.settings.speed === 'slow', 'settings applied');
    expect(other.view!.settings).toMatchObject({ target: 61, visibility: 'public' });
    host.send('settings', { target: 50 });
    await waitFor(() => host.errors.includes('badSettings'), 'badSettings');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'start');
    host.send('settings', { speed: 'fast' });
    await waitFor(() => host.errors.includes('gameStarted'), 'gameStarted');
  });

  it('syrian41 always keeps target 41', async () => {
    const host = P('s');
    await host.create('syrian41', { target: 61 });
    expect(host.view!.settings.target).toBe(41);
    expect(host.view!.target).toBe(41);
  });
});

describe('start with computer players', () => {
  it('host starts early: empty seats become computer players and the game runs', async () => {
    const host = P('أنا');
    const code = await host.create('tarneeb');
    const friend = P('صاحبي');
    await friend.join(code);
    friend.send('start');
    await waitFor(() => friend.errors.includes('notOwner'), 'non-host cannot start');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const seats = host.view!.seats;
    expect(seats.filter((s) => s?.bot)).toHaveLength(2);
    for (const s of seats.filter((s) => s?.bot)) expect(s!.name).toMatch(/[؀-ۿ]/);
    expect(seats.filter((s) => s && !s.bot).map((s) => s!.name).sort()).toEqual(['أنا', 'صاحبي'].sort());
    // the game advances with computers + autopilot for the idle humans
    await waitFor(() => (host.view!.game?.handNo ?? 0) >= 2 || host.view!.status === 'finished', 'a full hand', 20000);
    // views never carry other players' hands
    for (const v of host.views) expect(JSON.stringify(v)).not.toContain('"hands"');
  });
});

describe('a human takes a computer seat', () => {
  it('joins as pending, gets a computer seat between tricks; gameFull when no computer seat is left', async () => {
    const host = P('h2');
    const code = await host.create('tarneeb');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const late = P('متأخر');
    await late.join(code);
    await waitFor(() => late.view!.mySeat !== null, 'seated', 10000);
    const firstSeated = late.views.find((v) => v.mySeat !== null)!;
    expect(firstSeated.pending).toBe(false);
    expect(firstSeated.seats[firstSeated.mySeat!]).toMatchObject({ name: 'متأخر', bot: false });
    // assigned between tricks: no card on the table at that moment
    expect(firstSeated.game!.trick.length).toBe(0);
    expect(firstSeated.game!.myHand.length).toBeGreaterThan(0);
    // two more take the remaining computer seats, then the table is full of humans
    const a = P('أ');
    const b = P('ب');
    await a.join(code);
    await b.join(code);
    await waitFor(() => a.view!.mySeat !== null && b.view!.mySeat !== null, 'both seated', 10000);
    expect(host.view!.seats.every((s) => s && !s.bot)).toBe(true);
    await expect(new Client(EP).joinById(code, { name: 'زائد' })).rejects.toThrow(/gameFull/);
  });
});

describe('kick', () => {
  it('disabled unless the setting is on', async () => {
    const host = P('k0');
    const code = await host.create('tarneeb');
    const x = P('x');
    await x.join(code);
    host.send('kick', { seat: 1 });
    await waitFor(() => host.errors.includes('kickDisabled'), 'kickDisabled');
  });

  it('before the start: seat freed, player removed and cannot rejoin with the token', async () => {
    const host = P('k1');
    const code = await host.create('tarneeb', { kick: true });
    const victim = P('ضيف');
    await victim.join(code);
    const tok = victim.token;
    victim.send('kick', { seat: 0 });
    await waitFor(() => victim.errors.includes('notOwner'), 'only host kicks');
    host.send('kick', { seat: 1 });
    await waitFor(() => victim.leftCode === 4003, 'victim removed');
    await waitFor(() => host.view!.seats[1] === null, 'seat freed');
    await expect(new Client(EP).joinById(code, { name: 'ضيف', token: tok })).rejects.toThrow(/kicked/);
  });

  it('during a game: queued, applied when the hand ends; the seat goes to a computer', async () => {
    const host = P('k2');
    const code = await host.create('tarneeb', { kick: true });
    const victim = P('v');
    await victim.join(code);
    host.send('start');
    await waitFor(() => host.view!.status === 'playing' && host.view!.game!.phase === 'bidding', 'playing');
    const hand = host.view!.game!.handNo;
    host.send('kick', { seat: 1 });
    await waitFor(() => host.view!.kickQueued.includes(1), 'queued');
    expect(victim.leftCode).toBeNull(); // still playing this hand
    expect(host.view!.seats[1]?.bot).toBe(false);
    await waitFor(() => victim.leftCode === 4003, 'removed at hand end', 20000);
    const removedAt = host.views.find((v) => v.seats[1]?.bot)!;
    expect(['handOver', 'gameOver']).toContain(removedAt.game!.phase);
    expect(removedAt.game!.handNo).toBe(hand);
    expect(host.view!.kickQueued).toEqual([]);
    expect(host.view!.status).toBe('playing');
  });

  it('a second request cancels a queued kick', async () => {
    const host = P('k3');
    const code = await host.create('tarneeb', { kick: true });
    const v2 = P('v2');
    await v2.join(code);
    host.send('start');
    await waitFor(() => host.view!.status === 'playing' && host.view!.game!.phase === 'bidding', 'playing');
    host.send('kick', { seat: 1 });
    await waitFor(() => host.view!.kickQueued.includes(1), 'queued');
    host.send('kick', { seat: 1 });
    await waitFor(() => host.view!.kickQueued.length === 0, 'cancelled');
  });
});

describe('choose partner', () => {
  it('the host picks a seated player who moves opposite the host', async () => {
    const host = P('ح');
    const code = await host.create('tarneeb');
    const a = P('a');
    const b = P('b');
    await a.join(code); // seat 1
    await b.join(code); // seat 2
    expect(host.view!.partnerChooser).toBe(0);
    a.send('partner', { seat: 2 });
    await waitFor(() => a.errors.includes('notChooser'), 'notChooser');
    host.send('partner', { seat: 1 }); // pick "a" as partner
    await waitFor(() => host.view!.seats[2]?.name === 'a', 'a moved opposite');
    expect(host.view!.seats[1]?.name).toBe('b');
    expect(a.view!.mySeat).toBe(2);
    expect(b.view!.mySeat).toBe(1);
    host.send('partner', { seat: 3 });
    await waitFor(() => host.errors.includes('badSeat'), 'empty seat rejected');
  });
});

describe('public tables list (Colyseus lobby)', () => {
  it('lists public rooms live with seats + settings; private rooms never appear', async () => {
    const lobby = await new Client(EP).joinOrCreate('lobby');
    let rooms: { roomId: string; metadata: any }[] = [];
    lobby.onMessage('rooms', (r: typeof rooms) => (rooms = r));
    lobby.onMessage('+', ([id, r]: [string, (typeof rooms)[0]]) => {
      rooms = rooms.filter((x) => x.roomId !== id).concat(r);
    });
    lobby.onMessage('-', (id: string) => (rooms = rooms.filter((x) => x.roomId !== id)));
    await sleep(200);
    const pub = P('عام');
    const pubCode = await pub.create('tarneeb', { visibility: 'public', speed: 'fast' });
    const priv = P('خاص');
    const privCode = await priv.create('tarneeb');
    await waitFor(() => rooms.some((r) => r.roomId === pubCode), 'public room listed');
    const listed = rooms.find((r) => r.roomId === pubCode)!;
    expect(listed.metadata).toMatchObject({ code: pubCode, variant: 'tarneeb', status: 'waiting', joinable: true });
    expect(listed.metadata.settings.speed).toBe('fast');
    expect(listed.metadata.seats[0]).toMatchObject({ name: 'عام', bot: false });
    // live update: a second player shows up in the listing
    const j = P('جديد');
    await j.join(pubCode);
    await waitFor(() => rooms.find((r) => r.roomId === pubCode)?.metadata.seats[1]?.name === 'جديد', 'listing updated');
    // private room never listed; switching to public lists it
    await sleep(200);
    expect(rooms.some((r) => r.roomId === privCode)).toBe(false);
    priv.send('settings', { visibility: 'public' });
    await waitFor(() => rooms.some((r) => r.roomId === privCode), 'now listed');
    await Promise.race([lobby.leave(true), sleep(300)]);
  });
});

describe('chat', () => {
  it('broadcasts to every seat, filters bad words, rate-limits, and respects the chat toggle', { timeout: 20000 }, async () => {
    const a = P('c1');
    const code = await a.create('tarneeb', { chat: true });
    const b = P('c2');
    await b.join(code);
    a.send('chat', { text: 'يلا شدّ حيلك يا كلب' });
    await waitFor(() => a.messages.some((m) => m.type === 'chat'), 'message received');
    const msgA = a.messages.find((m) => m.type === 'chat')!.payload as { seat: number; text: string };
    expect(msgA.text).toBe('يلا شدّ حيلك يا ***');
    expect(msgA.seat).toBe(0);
    await waitFor(() => b.messages.some((m) => m.type === 'chat'), 'other seat received it too');

    // rate limit: immediate second message rejected
    a.send('chat', { text: 'ثانية بسرعة' });
    await waitFor(() => a.errors.includes('chatTooFast'), 'rate limited');

    // too long is rejected (wait out the rate limit first so this hits the length check, not chatTooFast)
    await sleep(1600);
    a.errors.length = 0;
    a.send('chat', { text: 'a'.repeat(200) });
    await waitFor(() => a.errors.includes('badChat'), 'too long rejected');

    // chat disabled
    const host2 = P('c3');
    const code2 = await host2.create('tarneeb', { chat: false });
    host2.send('chat', { text: 'hi' });
    await waitFor(() => host2.errors.includes('chatOff'), 'chat disabled');
  });
});

describe('trix', () => {
  // A full 20-hand game is covered by the rules tests (packages/rules/test/trix.test.ts); over the network each
  // hand takes a few seconds, so here we play the whole first kingdom and check the hand-over to the next owner.
  it('trix with computers: the first kingdom plays all 5 contracts, then the next owner takes over', { timeout: 60_000 }, async () => {
    const host = P('تركس');
    await host.create('trix');
    host.send('contract', { contract: 'slam' });
    await waitFor(() => host.errors.includes('badContract'), 'unknown contract rejected');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    // the first view of the game (a computer owner may pick its contract before we look at the latest one)
    const g0 = host.views.find((v) => v.status === 'playing')!.game as any;
    expect(g0.variant).toBe('trix');
    expect(g0.phase).toBe('contract');
    const owner0 = g0.kingdomOwner;
    await waitFor(() => (host.view!.game as any).kingdom === 1, 'second kingdom', 50_000);
    const g = host.view!.game as any;
    expect(g.kingdomOwner).toBe((owner0 + 1) % 4);
    const results = host.views.map((v) => (v.game as any)?.lastResult).filter(Boolean);
    const played = new Set(results.filter((r: any) => r.kingdomOwner === owner0).map((r: any) => r.contract));
    expect([...played].sort()).toEqual(['diamonds', 'king', 'queens', 'tricks', 'trix']);
    // views never carry other players' hands or the raw taken piles
    for (const v of host.views) expect(JSON.stringify(v)).not.toMatch(/"hands"|"taken"/);
  });

  it('partners: opposite seats score together', { timeout: 20_000 }, async () => {
    const host = P('شريك');
    await host.create('trixPartners');
    host.send('start');
    await waitFor(() => ((host.view!.game as any)?.handNo ?? 0) >= 3, 'two hands scored', 15_000);
    const g = host.view!.game as any;
    expect(g.variant).toBe('trixPartners');
    expect(g.teamScores).toEqual([g.seatScores[0] + g.seatScores[2], g.seatScores[1] + g.seatScores[3]]);
  });

  it('trix complex: the kingdom is complex + trix, then the next owner takes over', { timeout: 60_000 }, async () => {
    const host = P('كمبلكس');
    await host.create('trixComplex');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const g0 = host.views.find((v) => v.status === 'playing')!.game as any;
    expect(g0.variant).toBe('trixComplex');
    expect(g0.contractsLeft).toEqual(['complex', 'trix']);
    const owner0 = g0.kingdomOwner;
    await waitFor(() => (host.view!.game as any).kingdom === 1, 'second kingdom', 50_000);
    const results = host.views.map((v) => (v.game as any)?.lastResult).filter(Boolean);
    const played = new Set(results.filter((r: any) => r.kingdomOwner === owner0).map((r: any) => r.contract));
    expect([...played].sort()).toEqual(['complex', 'trix']);
  });
});

describe('baloot', () => {
  it('baloot with computers: auction, deal to 8 cards, rounds scored for the two teams', { timeout: 40_000 }, async () => {
    const host = P('بلوت');
    await host.create('baloot');
    host.send('call', { call: 'kaboot' });
    await waitFor(() => host.errors.includes('badCall'), 'unknown call rejected');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const g0 = host.view!.game as any;
    expect(g0.variant).toBe('baloot');
    expect(g0.phase).toBe('bidding');
    expect(g0.myHand).toHaveLength(5);
    await waitFor(() => host.views.some((v) => (v.game as any)?.lastResult?.kind === 'scored'), 'a round scored', 35_000);
    const played = host.views.map((v) => v.game as any).find((g) => g?.phase === 'playing' && g.trickNo === 0 && g.trick.length === 0);
    if (played) expect(played.handCounts).toEqual([8, 8, 8, 8]);
    const r = host.views.map((v) => (v.game as any)?.lastResult).find((x) => x?.kind === 'scored');
    expect(r.teamDelta).toHaveLength(2);
    // views never carry other players' hands or the undealt cards
    for (const v of host.views) expect(JSON.stringify(v)).not.toMatch(/"hands"|"stock"/);
  });
});

describe('400', () => {
  it('400 with computers: hearts trump, target 41, each seat bids and hands are scored per seat', { timeout: 40_000 }, async () => {
    const host = P('٤٠٠');
    await host.create('tarneeb400', { target: 61 });
    expect(host.view!.settings.target).toBe(41);
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const g0 = host.view!.game as any;
    expect(g0.variant).toBe('tarneeb400');
    expect(g0.trump).toBe('H');
    expect(g0.revealed).toBeNull();
    expect(g0.myHand).toHaveLength(13);
    await waitFor(() => host.views.some((v) => (v.game as any)?.lastResult?.note === 'syrian'), 'a hand scored per seat', 35_000);
    const r = host.views.map((v) => (v.game as any)?.lastResult).find((x) => x?.note === 'syrian');
    expect(r.seatDelta).toHaveLength(4);
    for (const v of host.views) expect(JSON.stringify(v)).not.toMatch(/"hands"/);
  });
});

describe('hand', () => {
  it('the player count comes from the room settings; computers play rounds to the end', { timeout: 60_000 }, async () => {
    const host = P('هاند');
    await host.create('hand', { players: 3 });
    expect(host.view!.seats).toHaveLength(3);
    host.send('settings', { players: 5 });
    await waitFor(() => host.view!.seats.length === 5, 'table grows to 5');
    host.send('settings', { players: 2 });
    await waitFor(() => host.view!.seats.length === 2, 'table shrinks to 2');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    const g0 = host.view!.game as any;
    expect(g0.variant).toBe('hand');
    expect(g0.players).toBe(2);
    await waitFor(() => host.views.some((v) => (v.game as any)?.lastResult), 'a round scored', 55_000);
    const r = host.views.map((v) => (v.game as any)?.lastResult).find(Boolean);
    expect(r.delta).toHaveLength(2);
    // views never carry other players' hands or the undealt cards (keys only: "stock" is also a value of `drew`)
    for (const v of host.views) expect(JSON.stringify(v)).not.toMatch(/"hands":|"stock":/);
  });
});

describe('187', () => {
  it('5 players: a 5-seat room fills with computers and plays hands to the end', { timeout: 30_000 }, async () => {
    const host = P('مشتري');
    const code = await host.create('b187', { players: 5 });
    expect(host.view!.seats).toHaveLength(5);
    const friend = P('صديق');
    await friend.join(code);
    host.send('sit', { seat: 4 });
    await waitFor(() => (host.view!.mySeat as number) === 4, 'the fifth seat can be taken');
    host.send('partner', { seat: 1 });
    await waitFor(() => host.errors.includes('noTeams'), 'no partner picker in 187');
    host.send('start');
    await waitFor(() => host.view!.status === 'playing', 'playing');
    expect(host.view!.seats.filter((s) => s?.bot)).toHaveLength(3);
    const g0 = host.view!.game as any;
    expect(g0.players).toBe(5);
    expect(g0.myHand).toHaveLength(7);
    expect(g0.fieldCount).toBe(5);
    // a whole hand is scored (the 187 points are all handed out)
    await waitFor(() => !!(host.view!.game as any).lastResult, 'a hand scored', 25_000);
    const r = (host.view!.game as any).lastResult;
    expect(r.collected.reduce((a: number, b: number) => a + b, 0)).toBe(187);
    for (const v of host.views) expect(JSON.stringify(v)).not.toMatch(/"hands"|"taken"/);
  });

  it('4 players: bad give / loss messages are rejected', async () => {
    const host = P('ب4');
    await host.create('b187');
    expect(host.view!.seats).toHaveLength(4);
    host.send('give', { cards: 'x' });
    await waitFor(() => host.errors.includes('badGive'), 'badGive');
    host.send('loss', { choice: 'maybe' });
    await waitFor(() => host.errors.includes('badChoice'), 'badChoice');
  });
});

describe('quick match ("العب الآن")', () => {
  it('an empty table: create({ quick: true }) opens a public table that auto-fills with computers after the fill window', async () => {
    const p = P('q1');
    const room = await new Client(EP).create('lamma', { variant: 'tarneeb', name: 'q1', quick: true });
    (p as any).attachForTest(room);
    await waitFor(() => !!p.view, 'first view');
    expect(p.view!.settings.visibility).toBe('public');
    expect(p.view!.status).toBe('waiting');
    await waitFor(() => p.view!.status === 'playing', 'auto-started', 5000);
    expect(p.view!.seats.filter((s: any) => s.bot)).toHaveLength(3);
    players.push(p);
  });

  it('joining an existing joinable public table takes a seat instead of opening a new one', async () => {
    const host = P('q2');
    const code = await host.create('tarneeb', { visibility: 'public' });
    const second = P('q3');
    await second.join(code); // simulates quickMatch() finding & joining this table directly
    expect(second.view!.mySeat).toBe(1);
    expect(second.view!.code).toBe(code);
  });
});
