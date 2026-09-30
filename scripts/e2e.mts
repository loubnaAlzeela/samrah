/**
 * End-to-end check: 4 real WebSocket clients play a full game of regular Tarneeb against the running server.
 *
 * Verifies:
 *  - room create -> 6-char code, 3 joins by code, seat selection, auto start at 4
 *  - a complete game until a team reaches the target
 *  - RAW network frames received by each client never contain an opponent's (or partner's) hidden card
 *  - reconnect: a player drops mid-game and rejoins with its token into the same seat
 *  - a stranger cannot join a running game
 *  - (phase 2) a player away longer than the hold window -> autopilot takes the seat and the game is played
 *    to the end; the player then returns with the token and gets the seat back
 *  - (phase 3) turn timer: a connected player who does nothing -> one autopilot move per timeout, the seat stays
 *    human after 1 timeout, goes to autopilot after 3 in a row, comes back with 'back' or a token rejoin
 *
 * Run the server first with short timings (test-only env overrides), e.g.:
 *   LAMMA_TRICK_PAUSE_MS=30 LAMMA_HAND_PAUSE_MS=60 LAMMA_RECONNECT_SECONDS=2 LAMMA_TURN_SECONDS=3 LAMMA_AUTO_MOVE_MS=40 npm run dev:server
 * (hold 2s < 3 timeouts x 3s, so phase 2 exercises the hold-window path, not the timeout path)
 * then: npm run e2e
 */

// --- capture raw frames BEFORE the SDK picks up globalThis.WebSocket -------------------------
type Sink = (bytes: Uint8Array) => void;
const NativeWS = globalThis.WebSocket;
let nextSink: Sink | null = null;
class RecordingWS extends NativeWS {
  constructor(url: string | URL, protocols?: string | string[]) {
    super(url, protocols);
    const sink = nextSink;
    this.addEventListener('message', (e: MessageEvent) => {
      if (!sink) return;
      const d = e.data;
      if (d instanceof ArrayBuffer) sink(new Uint8Array(d));
      else if (ArrayBuffer.isView(d)) sink(new Uint8Array(d.buffer, d.byteOffset, d.byteLength));
      else if (typeof d === 'string') sink(new TextEncoder().encode(d));
    });
  }
}
globalThis.WebSocket = RecordingWS as unknown as typeof WebSocket;

const { Client } = await import('@colyseus/sdk');
type SdkRoom = Awaited<ReturnType<InstanceType<typeof Client>['joinById']>>;

const ENDPOINT = process.env.LAMMA_WS ?? 'ws://localhost:2567';
const TARGET = Number(process.env.LAMMA_E2E_TARGET ?? 31);
const VARIANT = process.env.LAMMA_E2E_VARIANT === 'syrian41' ? 'syrian41' : 'tarneeb';

interface View {
  code: string;
  status: string;
  seats: ({ name: string; connected: boolean; heldMsLeft: number | null; auto: boolean } | null)[];
  mySeat: number | null;
  turnDeadline: number | null;
  game: null | {
    phase: string;
    handNo: number;
    turn: number;
    myHand: string[];
    legal: string[];
    minBid: number | null;
    trick: { seat: number; card: string }[];
    bidLog?: unknown[];
    lastTrick: { plays: { seat: number; card: string }[]; winner: number } | null;
    revealed: string | null;
    teamScores: [number, number];
    seatScores: number[];
    winner: number | null;
    lastResult: { kind: string; note: string; teamDelta: [number, number]; bid?: number; bidderTricks?: number } | null;
  };
}

const CARD_RE = /\xA2([SHDC][2-9])|\xA3([SHDC]1[0-4])/g; // msgpack fixstr(2|3) + card
function cardsInFrame(bytes: Uint8Array): Set<string> {
  const s = Buffer.from(bytes).toString('latin1');
  const out = new Set<string>();
  for (const m of s.matchAll(CARD_RE)) out.add(m[1] ?? m[2]);
  return out;
}

let framesChecked = 0;
let cardsSeen = 0;
const failures: string[] = [];
function fail(msg: string) {
  failures.push(msg);
  console.error('FAIL:', msg);
}

class Player {
  room!: SdkRoom;
  view: View | null = null;
  token = '';
  pendingFrames: Uint8Array[] = [];
  handsLog = new Set<number>();
  /** server errors that are expected for this player (e.g. racing the autopilot) */
  tolerated = new Set<string>();
  errors: string[] = [];
  onView: ((prev: View | null, next: View) => void) | null = null;
  constructor(public name: string, public others: () => Player[]) {}

  private attach(room: SdkRoom) {
    this.room = room;
    room.onMessage('welcome', (m: { token: string }) => {
      this.token = m.token;
    });
    room.onMessage('error', (m: { error: string }) => {
      this.errors.push(m.error);
      if (m.error !== 'roomFull' && !this.tolerated.has(m.error)) fail(`${this.name} got server error ${m.error}`);
    });
    room.onMessage('state', (v: View) => {
      this.checkFrames(v);
      const prev = this.view;
      this.view = v;
      this.onView?.(prev, v);
      if (v.game) this.handsLog.add(v.game.handNo);
      this.maybeAct();
    });
  }

  private sink(): Sink {
    return (b) => this.pendingFrames.push(b);
  }

  async create(client: InstanceType<typeof Client>, opts: object) {
    nextSink = this.sink();
    const r = await client.create('lamma', { ...opts, name: this.name });
    nextSink = null;
    this.attach(r);
  }
  async join(client: InstanceType<typeof Client>, code: string, extra: object = {}) {
    nextSink = this.sink();
    const r = await client.joinById(code, { name: this.name, ...extra });
    nextSink = null;
    this.attach(r);
  }

  /** Every raw frame since the last state must only contain cards this player may legally see. */
  private checkFrames(v: View) {
    const frames = this.pendingFrames;
    this.pendingFrames = [];
    const g = v.game;
    const allowed = new Set<string>();
    if (g) {
      g.myHand.forEach((c) => allowed.add(c));
      g.trick.forEach((p) => allowed.add(p.card));
      g.lastTrick?.plays.forEach((p) => allowed.add(p.card));
      if (g.revealed) allowed.add(g.revealed);
    }
    const othersHidden = new Set<string>();
    for (const o of this.others()) o.view?.game?.myHand.forEach((c) => !allowed.has(c) && othersHidden.add(c));
    for (const f of frames) {
      framesChecked++;
      const seen = cardsInFrame(f);
      cardsSeen += seen.size;
      for (const c of seen) {
        if (!allowed.has(c)) fail(`${this.name} received card ${c} that is not its own nor public`);
        if (othersHidden.has(c)) fail(`${this.name} received hidden card ${c} held by another player`);
      }
    }
  }

  paused = false;
  private acting = false;
  /** a state key we already acted on: extra broadcasts (e.g. someone reconnecting) must not trigger a second action */
  private actedKey = '';
  maybeAct() {
    const v = this.view;
    const g = v?.game;
    if (this.paused || !v || v.status !== 'playing' || !g || g.turn !== v.mySeat || this.acting) return;
    if (!['bidding', 'trump', 'playing'].includes(g.phase)) return;
    this.acting = true;
    setTimeout(() => {
      this.acting = false;
      const cur = this.view?.game;
      if (this.paused || !cur || cur.turn !== this.view?.mySeat) return;
      const key = `${cur.handNo}|${cur.phase}|${cur.bidLog?.length ?? 0}|${cur.myHand.length}|${cur.trick.length}`;
      if (key === this.actedKey) return;
      this.actedKey = key;
      if (cur.phase === 'bidding') {
        if (VARIANT === 'syrian41') this.room.send('bid', { value: 2 + Math.floor(Math.random() * 3) });
        else {
          const min = cur.minBid ?? 7;
          this.room.send('bid', { value: min <= 8 && Math.random() < 0.6 ? min : 'pass' });
        }
      } else if (cur.phase === 'trump') {
        const counts: Record<string, number> = {};
        for (const c of cur.myHand) counts[c[0]] = (counts[c[0]] ?? 0) + 1;
        const suit = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
        this.room.send('trump', { suit });
      } else if (cur.phase === 'playing') {
        const legal = cur.legal;
        if (legal.length === 0) return fail(`${this.name} has no legal cards on its turn`);
        // prefer the highest legal card (keeps games shorter and exercises cuts)
        const card = legal.slice().sort((a, b) => Number(b.slice(1)) - Number(a.slice(1)))[0];
        this.room.send('play', { card });
      }
    }, 5);
  }
}

function waitFor(pred: () => boolean, ms: number, what: string): Promise<void> {
  return new Promise((res, rej) => {
    const t0 = Date.now();
    const iv = setInterval(() => {
      if (pred()) {
        clearInterval(iv);
        res();
      } else if (Date.now() - t0 > ms) {
        clearInterval(iv);
        rej(new Error('timeout waiting for ' + what));
      }
    }, 20);
  });
}

async function setupTable(target: number, variant: string = VARIANT, pausedIdx: number | null = null) {
  const players: Player[] = [];
  const names = ['سعاد', 'Omar', 'ليلى', 'Karim'];
  for (const n of names) players.push(new Player(n, () => players.filter((p) => p.name !== n)));
  if (pausedIdx !== null) players[pausedIdx].paused = true; // must never act, not even its first move
  const clients = names.map(() => new Client(ENDPOINT));
  await players[0].create(clients[0], { variant, target });
  await waitFor(() => !!players[0].view, 3000, 'first view');
  const code = players[0].view!.code;
  if (!/^[A-HJ-KM-NP-Z2-9]{6}$/.test(code)) fail(`bad room code ${code}`);
  for (let i = 1; i < 4; i++) await players[i].join(clients[i], code);
  // joiners are auto-seated in join order (0..3); the host starts the game
  await waitFor(() => players[0].view!.seats.every((s) => !!s), 3000, 'all seated');
  players[0].room.send('start');
  await waitFor(() => players.every((p) => p.view?.status === 'playing' && p.view.game), 5000, 'game start');
  return { players, clients, code };
}

// ---------------------------------------------------------------- phase 1: full game + reconnect
console.log(`[e2e] endpoint ${ENDPOINT}, variant ${VARIANT}, target ${TARGET}`);
const t1 = setupTable(TARGET);
const { players, code } = await t1;
console.log(`[e2e] room ${code} started; seats:`, players.map((p) => `${p.view!.mySeat}=${p.name}`).join(' '));

// a stranger may not join a running game
try {
  const intruder = new Client(ENDPOINT);
  await intruder.joinById(code, { name: 'intruder' });
  fail('stranger was able to join a running game');
} catch (e) {
  console.log('[e2e] stranger rejected as expected:', (e as Error).message);
}

// drop player 1 once the second hand is under way, then rejoin with its token
await waitFor(() => players[0].view!.game!.handNo >= 2 && players[0].view!.game!.phase === 'playing', 60000, 'hand 2');
const dropper = players[1];
const seatBefore = dropper.view!.mySeat;
const token = dropper.token;
dropper.paused = true;
await dropper.room.leave(false).catch(() => {});
await waitFor(() => players[0].view!.seats[seatBefore!]?.connected === false, 3000, 'seat marked disconnected');
const held = players[0].view!.seats[seatBefore!];
console.log(`[e2e] ${dropper.name} dropped; others see connected=${held?.connected}, held for ${Math.round(held!.heldMsLeft! / 1000)}s`);
await new Promise((r) => setTimeout(r, 1200));
dropper.view = null;
await dropper.join(new Client(ENDPOINT), code, { token });
dropper.paused = false;
await waitFor(() => !!dropper.view?.game, 3000, 'rejoin view');
if (dropper.view!.mySeat !== seatBefore) fail(`rejoined into seat ${dropper.view!.mySeat}, expected ${seatBefore}`);
if (dropper.view!.game!.myHand.length === 0 && dropper.view!.game!.phase === 'playing') fail('rejoined with empty hand');
console.log(`[e2e] ${dropper.name} rejoined seat ${dropper.view!.mySeat} with ${dropper.view!.game!.myHand.length} cards`);
dropper.maybeAct();

await waitFor(() => players.every((p) => p.view?.status === 'finished'), 240000, 'game over');
const g = players[0].view!.game!;
console.log(`[e2e] GAME OVER after ${g.handNo} hands: scores ${g.teamScores.join(' - ')}, winner team ${g.winner}`);
if (VARIANT === 'tarneeb') {
  if (g.winner === null || g.teamScores[g.winner] < TARGET) fail('winner did not reach target');
} else {
  console.log(`[e2e] seat scores ${g.seatScores.join(' / ')}`);
  const ok = [0, 1, 2, 3].some((s) => s % 2 === g.winner && g.seatScores[s] >= 41 && g.seatScores[(s + 2) % 4] > 0);
  if (!ok) fail('syrian winner does not satisfy 41 + partner > 0');
}
for (const p of players) if (p.view!.game!.winner !== g.winner) fail('clients disagree on winner');

// ---------------------------------------------------------------- phase 2: away > hold window -> autopilot to the end
const t2 = await setupTable(31);
const quitter = t2.players[2];
const qSeat = quitter.view!.mySeat!;
const qToken = quitter.token;
quitter.paused = true;
await quitter.room.leave(true).catch(() => {});
const obs = t2.players[0];
await waitFor(() => obs.view?.seats[qSeat]?.connected === false, 3000, 'quitter marked disconnected');
const holdMs = obs.view!.seats[qSeat]!.heldMsLeft!;
console.log(`[e2e] phase 2: ${quitter.name} left; hold window ${Math.round(holdMs / 1000)}s`);
await waitFor(() => obs.view?.seats[qSeat]?.auto === true, holdMs + 3000, 'autopilot takes the seat');
if (obs.view!.status !== 'playing') fail('game did not continue after the hold window');
console.log(`[e2e] phase 2: autopilot took seat ${qSeat} (connected=${obs.view!.seats[qSeat]!.connected}); game continues`);
await waitFor(() => obs.view?.status === 'finished', 240000, 'phase 2 game over with autopilot');
const g2 = obs.view!.game!;
console.log(`[e2e] phase 2: GAME OVER with autopilot after ${g2.handNo} hands, scores ${g2.teamScores.join(' - ')}`);
quitter.view = null;
await quitter.join(new Client(ENDPOINT), t2.code, { token: qToken });
await waitFor(() => !!quitter.view?.game, 3000, 'quitter rejoin view');
if (quitter.view!.mySeat !== qSeat) fail(`quitter got seat ${quitter.view!.mySeat}, expected ${qSeat}`);
if (quitter.view!.seats[qSeat]!.auto) fail('seat still on autopilot after the player came back');
console.log(`[e2e] phase 2: ${quitter.name} came back with the token -> seat ${quitter.view!.mySeat}, auto=${quitter.view!.seats[qSeat]!.auto}`);

// ---------------------------------------------------------------- phase 3: turn timer
const t3 = await setupTable(31, VARIANT, 1);
const idle = t3.players[1];
const iSeat = idle.view!.mySeat!;
idle.paused = true; // connected but never acts
idle.tolerated.add('notYourTurn').add('wrongPhase'); // may race the autopilot after un-pausing
let timeoutMoves = 0;
let autoAfterFirst: boolean | null = null;
let autoAtThird: boolean | null = null;
const acting = (v: View | null) => !!v?.game && ['bidding', 'trump', 'playing'].includes(v.game.phase) && v.status === 'playing';
let prevAt: number | null = null;
idle.onView = (prev, next) => {
  if (acting(next) && next.game!.turn === iSeat && !(acting(prev) && prev!.game!.turn === iSeat)) prevAt = Date.now();
  // a move made for the idle seat: its turn ended without it acting
  if (idle.paused && acting(prev) && prev!.game!.turn === iSeat && prev!.seats[iSeat]!.auto === false) {
    const moved =
      next.game!.turn !== iSeat || next.game!.phase !== prev!.game!.phase || next.game!.myHand.length !== prev!.game!.myHand.length;
    if (moved) {
      timeoutMoves++;
      if (process.env.E2E_DEBUG) console.log('  timeout-move', timeoutMoves, prev!.game!.phase, '->', next.game!.phase, 'auto', next.seats[iSeat]!.auto, 'dt', Date.now() - (prevAt ?? 0));
      if (timeoutMoves === 1) autoAfterFirst = next.seats[iSeat]!.auto;
      if (timeoutMoves === 3) autoAtThird = next.seats[iSeat]!.auto;
    }
  }
};
const firstDeadline = (() => {
  const v = t3.players[0].view!;
  return v.turnDeadline !== null ? v.turnDeadline - (v as unknown as { serverNow: number }).serverNow : null;
})();
console.log(`[e2e] phase 3: turn deadline sent to clients (ms left at start): ${firstDeadline}`);
if (firstDeadline === null) fail('no turn deadline in view');
await waitFor(() => autoAtThird !== null, 120000, '3 consecutive timeouts');
console.log(`[e2e] phase 3: after 1 timeout auto=${autoAfterFirst}; after 3 timeouts auto=${autoAtThird}`);
if (autoAfterFirst !== false) fail('seat went to autopilot after a single timeout');
if (autoAtThird !== true) fail('seat not on autopilot after 3 consecutive timeouts');
idle.room.send('back');
await waitFor(() => idle.view?.seats[iSeat]?.auto === false, 3000, "'back' returns the seat");
console.log(`[e2e] phase 3: 'back' -> auto=${idle.view!.seats[iSeat]!.auto}`);
// idle again until autopilot, then a token rejoin must also take the seat back
timeoutMoves = 0;
autoAtThird = null;
await waitFor(() => idle.view?.seats[iSeat]?.auto === true, 120000, 'autopilot again');
const iToken = idle.token;
await idle.room.leave(false).catch(() => {});
idle.view = null;
await idle.join(new Client(ENDPOINT), t3.code, { token: iToken });
await waitFor(() => !!idle.view?.game, 3000, 'idle rejoin');
if (idle.view!.seats[iSeat]!.auto) fail('token rejoin did not take the seat back from the autopilot');
console.log(`[e2e] phase 3: token rejoin mid-game -> seat ${idle.view!.mySeat}, auto=${idle.view!.seats[iSeat]!.auto}`);
idle.onView = null;
idle.paused = false;
idle.maybeAct();
await waitFor(() => t3.players.every((p) => p.view?.status === 'finished'), 240000, 'phase 3 game over');
console.log(`[e2e] phase 3: GAME OVER, scores ${t3.players[0].view!.game!.teamScores.join(' - ')}`);

// ---------------------------------------------------------------- phase 4: host starts with computers, public list, a human takes a computer seat
const lobby = await new Client(ENDPOINT).joinOrCreate('lobby');
let listed: { roomId: string; metadata: { seats: ({ name: string; bot: boolean } | null)[]; status: string } }[] = [];
lobby.onMessage('rooms', (r: typeof listed) => (listed = r));
lobby.onMessage('+', ([id, r]: [string, (typeof listed)[0]]) => (listed = listed.filter((x) => x.roomId !== id).concat(r)));
lobby.onMessage('-', (id: string) => (listed = listed.filter((x) => x.roomId !== id)));
const p4: Player[] = [];
const hostP = new Player('مضيف', () => p4.filter((p) => p !== hostP));
p4.push(hostP);
await hostP.create(new Client(ENDPOINT), { variant: VARIANT, settings: { visibility: 'public', target: 31 } });
await waitFor(() => !!hostP.view, 3000, 'host view');
const code4 = hostP.view!.code;
await waitFor(() => listed.some((r) => r.roomId === code4), 5000, 'public room in lobby list');
hostP.room.send('start');
await waitFor(() => hostP.view?.status === 'playing', 5000, 'phase 4 start');
const bots4 = hostP.view!.seats.filter((s) => (s as { bot?: boolean })?.bot).length;
console.log(`[e2e] phase 4: public room ${code4} listed; host started with ${bots4} computer players`);
if (bots4 !== 3) fail(`expected 3 computer seats, got ${bots4}`);
await waitFor(() => listed.find((r) => r.roomId === code4)?.metadata.status === 'playing', 5000, 'listing shows playing');
const late = new Player('متأخر', () => p4.filter((p) => p !== late));
p4.push(late);
await late.join(new Client(ENDPOINT), code4);
await waitFor(() => late.view?.mySeat !== null && late.view?.mySeat !== undefined, 20000, 'late player takes a computer seat');
const lateSeat = late.view!.mySeat!;
if ((late.view!.seats[lateSeat] as { bot?: boolean }).bot) fail('late player seat still marked as computer');
if (late.view!.game!.trick.length !== 0) fail('late player seated in the middle of a trick');
console.log(`[e2e] phase 4: ${late.name} took computer seat ${lateSeat} between tricks with ${late.view!.game!.myHand.length} cards`);
await waitFor(() => listed.find((r) => r.roomId === code4)?.metadata.seats[lateSeat]?.name === 'متأخر', 5000, 'listing shows the human');
late.maybeAct();
hostP.maybeAct();
await waitFor(() => p4.every((p) => p.view?.status === 'finished'), 240000, 'phase 4 game over');
console.log(`[e2e] phase 4: GAME OVER, scores ${hostP.view!.game!.teamScores.join(' - ')}`);
await Promise.race([lobby.leave(true), new Promise((r) => setTimeout(r, 300))]);

// ---------------------------------------------------------------- phase 5: chat (rate limit + filter, no leak of hidden state via chat)
const chatChecks: string[] = [];
hostP.room.onMessage('chat', (m: { seat: number; text: string }) => chatChecks.push(`${m.seat}:${m.text}`));
late.room.onMessage('chat', (m: { seat: number; text: string }) => chatChecks.push(`late:${m.seat}:${m.text}`));
hostP.room.send('chat', { text: 'يلا شدّ حيلك!' });
await waitFor(() => chatChecks.some((c) => c.includes('يلا شدّ حيلك!')), 3000, 'chat delivered to sender');
await waitFor(() => chatChecks.some((c) => c.startsWith('late:') && c.includes('يلا شدّ حيلك!')), 3000, 'chat delivered to other seat');
hostP.tolerated.add('chatTooFast');
hostP.room.send('chat', { text: 'رسالة فورية تانية' });
await waitFor(() => hostP.errors.includes('chatTooFast'), 3000, 'chat rate-limited');
console.log('[e2e] phase 5: chat delivered + rate-limited as expected');

for (const p of [...players, ...t2.players, ...t3.players, ...p4]) await Promise.race([p.room.leave(true).catch(() => {}), new Promise((r) => setTimeout(r, 300))]);
console.log(`[e2e] raw frames checked: ${framesChecked}, card strings inspected: ${cardsSeen}`);
if (failures.length) {
  console.error(`[e2e] ${failures.length} FAILURE(S)`);
  process.exit(1);
}
console.log('[e2e] PASS');
process.exit(0);
