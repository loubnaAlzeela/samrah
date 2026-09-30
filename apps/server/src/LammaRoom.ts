import { randomBytes, randomInt } from 'node:crypto';
import { type Client, type Delayed, Room, ServerError } from '@colyseus/core';
import {
  ACTING_PHASES,
  type AnyAction,
  type AnyGame,
  type AnyVariant,
  type ChatMessage,
  CLOSE_KICKED,
  CLOSE_REPLACED,
  CLOSE_ROOM_FULL,
  DEFAULT_SETTINGS,
  type RoomSettings,
  type RoomStatus,
  type RoomView,
  SPEED_SECONDS,
  type Seat,
  type Suit,
  TRIX_CONTRACTS,
  type TableListing,
  type TrixContract,
  actAny,
  advanceAny,
  autoActionAny,
  CHAT_RATE_MS,
  filterChat,
  gameProgress,
  hasTeams,
  seatCount,
  isCard,
  isHandCard,
  isVariant,
  mergeSettings,
  newAnyGame,
  viewForAny,
} from '@lamma/rules';

// Timings. The env overrides exist so tests can shorten them; production uses the defaults.
const num = (v: string | undefined, d: number) => (v !== undefined && v !== '' && Number.isFinite(Number(v)) ? Number(v) : d);
/** Seconds a disconnected player's seat is held before the autopilot takes it over. */
export const RECONNECT_SECONDS = num(process.env.LAMMA_RECONNECT_SECONDS, 90);
/** Test-only override of the per-move time (otherwise it comes from the room's speed setting). */
const TURN_SECONDS_OVERRIDE = process.env.LAMMA_TURN_SECONDS ? num(process.env.LAMMA_TURN_SECONDS, 30) : null;
/** Consecutive timeouts after which a connected player is treated as away (autopilot until they act again). */
export const MAX_TIMEOUTS = 3;
/** Delay before the autopilot / a computer player moves (so humans can follow the play). */
const AUTO_MOVE_MS = num(process.env.LAMMA_AUTO_MOVE_MS, 900);
const TRICK_PAUSE_MS = num(process.env.LAMMA_TRICK_PAUSE_MS, 1200);
const HAND_PAUSE_MS = num(process.env.LAMMA_HAND_PAUSE_MS, 5000);
const EMPTY_ROOM_DISPOSE_MS = RECONNECT_SECONDS * 1000;
const GUEST_LEVEL = 1;
/** «العب الآن»: a quick-match room waits this long for humans, then fills with computers and starts. */
export const QUICK_FILL_MS = num(process.env.LAMMA_QUICK_FILL_MS, 20000);

/** Simple Arabic names for computer players. */
const BOT_NAMES = ['سالم', 'نور', 'فارس', 'هدى', 'ليث', 'رنا', 'زياد', 'سما', 'كريم', 'دانة'];

/** 6-char room codes without look-alike characters (no 0/O, 1/I/L). */
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const activeCodes = new Set<string>();
function newCode(): string {
  for (;;) {
    let c = '';
    for (let i = 0; i < 6; i++) c += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
    if (!activeCodes.has(c)) return c;
  }
}
const newToken = () => randomBytes(18).toString('base64url');

interface SeatInfo {
  name: string;
  token: string;
  sessionId: string | null;
  /** epoch ms until which a disconnected seat is held */
  heldUntil: number | null;
  timer: Delayed | null;
  /** autopilot controls this seat */
  auto: boolean;
  /** consecutive turn timeouts */
  timeouts: number;
  /** computer player (no human behind it) */
  bot: boolean;
  level: number;
  lastChatAt: number;
}

interface Member {
  name: string;
  token: string;
}

export function cleanName(x: unknown): string | null {
  if (typeof x !== 'string') return null;
  // strip control + bidi-override characters, collapse spaces, max 16 chars
  const n = x.replace(/[\u0000-\u001f\u007f‎‏‪-‮⁦-⁩]/g, '').replace(/\s+/g, ' ').trim().slice(0, 16);
  return n.length > 0 ? n : null;
}

export interface CreateOptions {
  variant?: unknown;
  /** legacy top-level target (slice 1/2 clients) */
  target?: unknown;
  settings?: unknown;
  /** created by «العب الآن» (quick match): public, starts by itself */
  quick?: unknown;
}

export class LammaRoom extends Room {
  maxClients = 8;
  autoDispose = false;
  maxMessagesPerSecond = 20;

  variant: AnyVariant = 'tarneeb';
  settings: RoomSettings = { ...DEFAULT_SETTINGS };
  status: RoomStatus = 'waiting';
  seats: (SeatInfo | null)[] = [null, null, null, null];
  /** connected clients by sessionId (seated or not) */
  members = new Map<string, Member>();
  /** sessionIds that joined a running game and wait for a computer seat (FIFO) */
  pending: string[] = [];
  /** tokens of players the host removed: they cannot rejoin with them */
  banned = new Set<string>();
  ownerToken: string | null = null;
  /** tokens the host asked to remove during a game (applied when the hand ends) */
  kickQueue = new Set<string>();
  game: AnyGame | null = null;
  advanceTimer: Delayed | null = null;
  disposeTimer: Delayed | null = null;
  turnTimer: Delayed | null = null;
  turnDeadline: number | null = null;
  quick = false;
  quickTimer: Delayed | null = null;

  get target() {
    return this.settings.target;
  }

  onCreate(options: CreateOptions) {
    if (!isVariant(options.variant)) throw new ServerError(400, 'badVariant');
    this.variant = options.variant;
    let s = mergeSettings(DEFAULT_SETTINGS, options.settings ?? {}, this.variant);
    if (s && options.target !== undefined) s = mergeSettings(s, { target: Number(options.target) }, this.variant);
    if (!s) throw new ServerError(400, 'badSettings');
    this.settings = s;
    this.seats = Array(seatCount(this.variant, s.players)).fill(null);
    if (options.quick === true) {
      this.quick = true;
      this.settings = { ...this.settings, visibility: 'public' };
      this.quickTimer = this.clock.setTimeout(() => this.quickStart(), QUICK_FILL_MS);
    }
    const code = newCode();
    activeCodes.add(code);
    this.roomId = code;
    void this.setPrivate(this.settings.visibility === 'private', false);
    void this.setMetadata(this.listing(), false);

    this.onMessage('sit', (client, msg: { seat?: unknown }) => this.handleSit(client, msg?.seat));
    this.onMessage('stand', (client) => this.handleStand(client));
    this.onMessage('start', (client) => this.handleStart(client));
    this.onMessage('settings', (client, msg: unknown) => this.handleSettings(client, msg));
    this.onMessage('kick', (client, msg: { seat?: unknown }) => this.handleKick(client, msg?.seat));
    this.onMessage('partner', (client, msg: { seat?: unknown }) => this.handlePartner(client, msg?.seat));
    this.onMessage('bid', (client, msg: { value?: unknown }) => {
      const v = msg?.value;
      if (v !== 'pass' && !(typeof v === 'number' && Number.isInteger(v))) return this.reject(client, 'badBid');
      this.handleAction(client, { type: 'bid', value: v });
    });
    this.onMessage('trump', (client, msg: { suit?: unknown }) => {
      const s = msg?.suit;
      if (s !== 'S' && s !== 'H' && s !== 'D' && s !== 'C') return this.reject(client, 'badSuit');
      this.handleAction(client, { type: 'trump', suit: s as Suit });
    });
    // trix: the kingdom owner picks the next contract; K♥ / Queen holders double (a possibly empty list of cards)
    this.onMessage('contract', (client, msg: { contract?: unknown }) => {
      const c = msg?.contract;
      if (!(TRIX_CONTRACTS as readonly unknown[]).includes(c)) return this.reject(client, 'badContract');
      this.handleAction(client, { type: 'contract', contract: c as TrixContract });
    });
    this.onMessage('double', (client, msg: { cards?: unknown }) => {
      const cards = msg?.cards;
      if (!Array.isArray(cards) || cards.length > 4 || !cards.every(isCard)) return this.reject(client, 'badDouble');
      this.handleAction(client, { type: 'double', cards });
    });
    // 187: the buyer hands one card back to each opponent, and after a lost hand picks −bid or −187
    this.onMessage('give', (client, msg: { cards?: unknown }) => {
      const cards = msg?.cards;
      if (!Array.isArray(cards) || cards.length > 4 || !cards.every(isCard)) return this.reject(client, 'badGive');
      this.handleAction(client, { type: 'give', cards });
    });
    this.onMessage('loss', (client, msg: { choice?: unknown }) => {
      const choice = msg?.choice;
      if (choice !== 'bid' && choice !== 'full') return this.reject(client, 'badChoice');
      this.handleAction(client, { type: 'loss', choice });
    });
    // hand: draw (stock / discard pile), lay down melds, add a card to a meld, discard
    this.onMessage('draw', (client, msg: { from?: unknown }) => {
      const from = msg?.from;
      if (from !== 'stock' && from !== 'fire') return this.reject(client, 'badDraw');
      this.handleAction(client, { type: 'draw', from });
    });
    this.onMessage('undoFire', (client) => this.handleAction(client, { type: 'undoFire' }));
    this.onMessage('meld', (client, msg: { groups?: unknown }) => {
      const g = msg?.groups;
      if (!Array.isArray(g) || g.length > 10 || !g.every((x) => Array.isArray(x) && x.length <= 14 && x.every(isHandCard))) return this.reject(client, 'badMeld');
      this.handleAction(client, { type: 'meld', groups: g as string[][] });
    });
    this.onMessage('layoff', (client, msg: { card?: unknown; meld?: unknown }) => {
      if (!isHandCard(msg?.card) || !Number.isInteger(msg?.meld)) return this.reject(client, 'badMeld');
      this.handleAction(client, { type: 'layoff', card: msg.card, meld: msg.meld as number });
    });
    this.onMessage('discard', (client, msg: { card?: unknown }) => {
      if (!isHandCard(msg?.card)) return this.reject(client, 'badCard');
      this.handleAction(client, { type: 'discard', card: msg.card });
    });
    // baloot: auction calls (sun / hokm with its suit / ashkal / pass), then raising the stakes (دبل … قهوة)
    this.onMessage('call', (client, msg: { call?: unknown; suit?: unknown }) => {
      const c = msg?.call;
      const s = msg?.suit;
      if (c !== 'pass' && c !== 'sun' && c !== 'hokm' && c !== 'ashkal') return this.reject(client, 'badCall');
      if (s !== undefined && s !== 'S' && s !== 'H' && s !== 'D' && s !== 'C') return this.reject(client, 'badSuit');
      this.handleAction(client, { type: 'call', call: c, ...(s !== undefined ? { suit: s as Suit } : {}) });
    });
    this.onMessage('raise', (client, msg: { raise?: unknown; closed?: unknown }) => {
      if (typeof msg?.raise !== 'boolean' || (msg.closed !== undefined && typeof msg.closed !== 'boolean')) return this.reject(client, 'badRaise');
      this.handleAction(client, { type: 'raise', raise: msg.raise, ...(msg.closed !== undefined ? { closed: msg.closed } : {}) });
    });
    this.onMessage('play', (client, msg: { card?: unknown }) => {
      if (!isCard(msg?.card)) return this.reject(client, 'badCard');
      this.handleAction(client, { type: 'play', card: msg.card });
    });
    // "I'm back": a player the autopilot took over (3 timeouts) touches the screen
    this.onMessage('back', (client) => this.handleBack(client));
    this.onMessage('chat', (client, msg: { text?: unknown }) => this.handleChat(client, msg?.text));
    this.onMessage('rematch', (client) => this.handleRematch(client));
    this.onMessage('*', (client) => this.reject(client, 'unknownMessage'));
    this.scheduleDisposeIfEmpty();
  }

  onJoin(client: Client, options: { name?: unknown; token?: unknown }) {
    const token = typeof options?.token === 'string' ? options.token : null;
    if (token && this.banned.has(token)) throw new ServerError(403, 'kicked');
    const seatIdx = token ? this.seats.findIndex((s) => s && !s.bot && s.token === token) : -1;

    if (seatIdx >= 0) {
      // Rejoin into a held seat (page refresh, network drop, second tab takes over). The player takes the seat
      // back from the autopilot immediately.
      const seat = this.seats[seatIdx]!;
      const old = seat.sessionId ? this.clients.find((c) => c.sessionId === seat.sessionId) : undefined;
      seat.sessionId = client.sessionId;
      seat.heldUntil = null;
      seat.timer?.clear();
      seat.timer = null;
      this.members.set(client.sessionId, { name: seat.name, token: seat.token });
      if (old) {
        this.members.delete(old.sessionId);
        old.leave(CLOSE_REPLACED, 'replaced');
      }
      if (seat.auto || seat.timeouts) {
        seat.auto = false;
        seat.timeouts = 0;
        this.scheduleTurn(); // the turn may be this seat's: give the human a full timer again
      }
    } else {
      const name = cleanName(options?.name);
      if (!name) throw new ServerError(400, 'badName');
      if (this.status === 'waiting') {
        const tok = newToken();
        this.members.set(client.sessionId, { name, token: tok });
        // take the first empty seat automatically (the player can still move before the start)
        const free = this.seats.findIndex((s) => s === null);
        if (free >= 0) this.seats[free] = this.newSeat(name, tok, client.sessionId);
      } else {
        // running / finished game: only a computer seat can be taken (at the end of the current trick)
        const bots = this.seats.filter((s) => s?.bot).length;
        if (this.pending.length >= bots) throw new ServerError(403, 'gameFull');
        this.members.set(client.sessionId, { name, token: newToken() });
        this.pending.push(client.sessionId);
      }
    }
    if (!this.ownerToken) this.ownerToken = this.members.get(client.sessionId)!.token;
    this.disposeTimer?.clear();
    this.disposeTimer = null;
    client.send('welcome', { token: this.members.get(client.sessionId)!.token, code: this.roomId });
    this.assignPending();
    // quick match: 4 humans -> start at once
    if (this.quick && this.status === 'waiting' && this.seats.every((x) => x && !x.bot && x.sessionId)) this.quickStart();
    this.changed();
  }

  onLeave(client: Client) {
    const sid = client.sessionId;
    this.members.delete(sid);
    this.pending = this.pending.filter((p) => p !== sid);
    const idx = this.seats.findIndex((s) => s?.sessionId === sid);
    if (idx >= 0) {
      const seat = this.seats[idx]!;
      seat.sessionId = null;
      if (this.status === 'waiting' || this.status === 'playing') {
        seat.heldUntil = Date.now() + RECONNECT_SECONDS * 1000;
        seat.timer = this.clock.setTimeout(() => this.seatExpired(idx), RECONNECT_SECONDS * 1000);
      }
    }
    this.changed();
    this.scheduleDisposeIfEmpty();
  }

  onDispose() {
    activeCodes.delete(this.roomId);
  }

  // ---------------------------------------------------------------------------

  private newSeat(name: string, token: string, sessionId: string | null, bot = false): SeatInfo {
    return { name, token, sessionId, heldUntil: null, timer: null, auto: bot, timeouts: 0, bot, level: GUEST_LEVEL, lastChatAt: 0 };
  }

  private botSeat(): SeatInfo {
    const used = new Set(this.seats.map((s) => s?.name));
    const name = BOT_NAMES.find((n) => !used.has(n)) ?? `كمبيوتر`;
    return this.newSeat(name, newToken(), null, true);
  }

  private seatExpired(idx: number) {
    const seat = this.seats[idx];
    if (!seat || seat.sessionId) return;
    seat.timer = null;
    seat.heldUntil = null;
    if (this.status === 'waiting') {
      this.seats[idx] = null;
    } else if (this.status === 'playing') {
      // away too long: the autopilot keeps playing for them until they come back with their token
      seat.auto = true;
      this.scheduleTurn();
    }
    this.changed();
  }

  private scheduleDisposeIfEmpty() {
    if (this.clients.length > 0 || this.disposeTimer) return;
    this.disposeTimer = this.clock.setTimeout(() => {
      if (this.clients.length === 0) this.disconnect();
      this.disposeTimer = null;
    }, EMPTY_ROOM_DISPOSE_MS);
  }

  private reject(client: Client, error: string) {
    client.send('error', { error });
  }

  private seatOf(client: Client): Seat | null {
    const i = this.seats.findIndex((s) => s?.sessionId === client.sessionId);
    return i >= 0 ? (i as Seat) : null;
  }

  /** The host: the holder of ownerToken if still present, else the first connected member. */
  private resolveOwner(): string | null {
    const present = new Set([...this.members.values()].map((m) => m.token));
    const heldSeat = this.seats.some((s) => s && !s.bot && s.token === this.ownerToken);
    if (!this.ownerToken || (!present.has(this.ownerToken) && !heldSeat)) {
      const first = [...this.members.values()][0];
      this.ownerToken = first ? first.token : null;
    }
    return this.ownerToken;
  }

  private isOwner(client: Client) {
    const m = this.members.get(client.sessionId);
    return !!m && m.token === this.resolveOwner();
  }

  private ownerSeat(): Seat | null {
    const tok = this.resolveOwner();
    const i = this.seats.findIndex((s) => s && !s.bot && s.token === tok);
    return i >= 0 ? (i as Seat) : null;
  }

  /** Partner picker before the start: the host if seated, else the first seated player. */
  private partnerChooser(): Seat | null {
    const o = this.ownerSeat();
    if (o !== null) return o;
    const i = this.seats.findIndex((s) => s && !s.bot);
    return i >= 0 ? (i as Seat) : null;
  }

  private handleSit(client: Client, seatArg: unknown) {
    if (this.status !== 'waiting') return this.reject(client, 'gameStarted');
    const seat = Number(seatArg);
    if (!Number.isInteger(seat) || seat < 0 || seat >= this.seats.length) return this.reject(client, 'badSeat');
    const cur = this.seatOf(client);
    if (cur === seat) return; // already there
    if (this.seats[seat]) return this.reject(client, 'seatTaken');
    const m = this.members.get(client.sessionId);
    if (!m) return this.reject(client, 'notMember');
    if (cur !== null) this.seats[cur] = null; // move seats
    this.seats[seat] = this.newSeat(m.name, m.token, client.sessionId);
    this.changed();
  }

  private handleStand(client: Client) {
    if (this.status !== 'waiting') return this.reject(client, 'gameStarted');
    const cur = this.seatOf(client);
    if (cur !== null) this.seats[cur] = null;
    this.changed();
  }

  /** Quick match: fill empty seats with computers and start (no host action needed). */
  private quickStart() {
    this.quickTimer?.clear();
    this.quickTimer = null;
    if (this.status !== 'waiting' || !this.seats.some((s) => s && !s.bot)) return;
    for (let i = 0; i < this.seats.length; i++) if (!this.seats[i]) this.seats[i] = this.botSeat();
    this.startGame();
    this.changed();
  }

  /** Host starts now: empty seats are filled with computer players. */
  private handleStart(client: Client) {
    if (this.status !== 'waiting') return this.reject(client, 'gameStarted');
    if (!this.isOwner(client)) return this.reject(client, 'notOwner');
    if (!this.seats.some((s) => s && !s.bot)) return this.reject(client, 'noPlayers');
    for (let i = 0; i < this.seats.length; i++) if (!this.seats[i]) this.seats[i] = this.botSeat();
    this.startGame();
    this.changed();
  }

  private handleSettings(client: Client, patch: unknown) {
    if (this.status !== 'waiting') return this.reject(client, 'gameStarted');
    if (!this.isOwner(client)) return this.reject(client, 'notOwner');
    const next = mergeSettings(this.settings, patch, this.variant);
    if (!next) return this.reject(client, 'badSettings');
    // Hand: the table grows or shrinks with the player count; seats being removed must be empty
    const size = seatCount(this.variant, next.players);
    if (size < this.seats.length && this.seats.slice(size).some((x) => x)) return this.reject(client, 'seatTaken');
    this.seats = size < this.seats.length ? this.seats.slice(0, size) : [...this.seats, ...Array(size - this.seats.length).fill(null)];
    const visibilityChanged = next.visibility !== this.settings.visibility;
    this.settings = next;
    if (visibilityChanged) void this.setPrivate(next.visibility === 'private');
    this.changed();
  }

  /**
   * Host removes a player. Before the start: the seat is freed at once. During a game: queued and applied when
   * the current hand ends (the seat goes to a computer). A second request for the same seat cancels it.
   */
  private handleKick(client: Client, seatArg: unknown) {
    if (!this.settings.kick) return this.reject(client, 'kickDisabled');
    if (!this.isOwner(client)) return this.reject(client, 'notOwner');
    const seat = Number(seatArg);
    if (!Number.isInteger(seat) || seat < 0 || seat >= this.seats.length) return this.reject(client, 'badSeat');
    const info = this.seats[seat];
    if (!info || info.bot) return this.reject(client, 'badSeat');
    if (info.token === this.resolveOwner()) return this.reject(client, 'badSeat');
    const betweenHands = this.status === 'finished' || (this.status === 'playing' && this.game?.phase === 'handOver');
    if (this.status === 'playing' && !betweenHands) {
      if (this.kickQueue.has(info.token)) this.kickQueue.delete(info.token);
      else this.kickQueue.add(info.token);
      return this.changed();
    }
    this.removeSeat(seat);
    this.changed();
  }

  private removeSeat(seat: number) {
    const info = this.seats[seat]!;
    this.banned.add(info.token);
    this.kickQueue.delete(info.token);
    info.timer?.clear();
    const victim = info.sessionId ? this.clients.find((c) => c.sessionId === info.sessionId) : undefined;
    this.seats[seat] = this.status === 'waiting' ? null : this.botSeat();
    if (victim) {
      this.members.delete(victim.sessionId);
      victim.send('error', { error: 'kicked' });
      victim.leave(CLOSE_KICKED, 'kicked');
    }
    if (this.status === 'playing') this.scheduleTurn();
  }

  /** Apply queued kicks once the hand is over. */
  private applyKickQueue() {
    if (this.kickQueue.size === 0) return;
    const between = this.status === 'finished' || (this.status === 'playing' && this.game?.phase === 'handOver');
    if (!between) return;
    for (let i = 0; i < this.seats.length; i++) {
      const s = this.seats[i];
      if (s && !s.bot && this.kickQueue.has(s.token)) this.removeSeat(i);
    }
    this.kickQueue.clear();
  }

  /** Before the start the chooser picks a partner among seated players; that player moves opposite the chooser. */
  private handlePartner(client: Client, seatArg: unknown) {
    if (this.status !== 'waiting') return this.reject(client, 'gameStarted');
    if (!hasTeams(this.variant)) return this.reject(client, 'noTeams');
    const chooser = this.partnerChooser();
    if (chooser === null || this.seatOf(client) !== chooser) return this.reject(client, 'notChooser');
    const target = Number(seatArg);
    if (!Number.isInteger(target) || target < 0 || target >= this.seats.length || target === chooser || !this.seats[target]) return this.reject(client, 'badSeat');
    const slot = (chooser + 2) % 4;
    if (target !== slot) [this.seats[target], this.seats[slot]] = [this.seats[slot], this.seats[target]];
    this.changed();
  }

  private handleChat(client: Client, raw: unknown) {
    if (!this.settings.chat) return this.reject(client, 'chatOff');
    const seat = this.seatOf(client);
    if (seat === null) return;
    const info = this.seats[seat]!;
    const now = Date.now();
    if (now - info.lastChatAt < CHAT_RATE_MS) return this.reject(client, 'chatTooFast');
    if (typeof raw !== 'string') return this.reject(client, 'badChat');
    const text = filterChat(raw);
    if (!text) return this.reject(client, 'badChat');
    info.lastChatAt = now;
    const msg: ChatMessage = { seat, text, at: now };
    for (const c of this.clients) c.send('chat', msg);
  }

  private handleBack(client: Client) {
    const seat = this.seatOf(client);
    if (seat === null) return;
    const info = this.seats[seat]!;
    if (!info.auto && !info.timeouts) return;
    info.auto = false;
    info.timeouts = 0;
    if (this.game?.turn === seat) this.scheduleTurn();
    this.changed();
  }

  private startGame() {
    this.game = newAnyGame({ variant: this.variant, target: this.target, players: this.seats.length }, randomInt);
    this.status = 'playing';
    for (const s of this.seats) if (s) Object.assign(s, { auto: s.bot, timeouts: 0 });
    // anyone connected without a seat cannot watch (no spectators)
    for (const c of this.clients) {
      if (this.seatOf(c) === null && !this.pending.includes(c.sessionId)) {
        c.send('error', { error: 'roomFull' });
        c.leave(CLOSE_ROOM_FULL, 'roomFull');
      }
    }
    this.scheduleTurn();
  }

  private handleRematch(client: Client) {
    if (this.status !== 'finished' || this.seatOf(client) === null) return this.reject(client, 'noRematch');
    if (!this.seats.every((s) => s && (s.bot || s.sessionId))) return this.reject(client, 'playersMissing');
    this.startGame();
    this.changed();
  }

  /** Humans waiting for a computer seat take one when no trick is on the table ("between tricks"). */
  private assignPending() {
    if (this.pending.length === 0) return;
    const g = this.game;
    const between = this.status === 'finished' || (this.status === 'playing' && !!g && g.trick.length === 0 && g.phase !== 'trickDone');
    if (!between) return;
    while (this.pending.length) {
      const idx = this.seats.findIndex((s) => s?.bot);
      if (idx < 0) break;
      const sid = this.pending.shift()!;
      const m = this.members.get(sid);
      if (!m) continue;
      this.seats[idx] = this.newSeat(m.name, m.token, sid);
      if (g && g.turn === idx) this.scheduleTurn(); // full time for the human
    }
  }

  private handleAction(client: Client, a: AnyAction) {
    const seat = this.seatOf(client);
    if (seat === null || !this.game || this.status !== 'playing') return this.reject(client, 'notPlaying');
    const r = actAny(this.game, seat, a);
    if (!r.ok) return this.reject(client, r.error);
    const info = this.seats[seat]!;
    info.timeouts = 0;
    info.auto = false; // acting yourself always takes the seat back from the autopilot
    this.game = r.state;
    this.afterChange();
  }

  /** Autopilot move for whoever is to act (turn timer ran out, or the seat is on autopilot / a computer). */
  private autoMove(timedOut: boolean) {
    this.turnTimer = null;
    this.turnDeadline = null;
    const g = this.game;
    if (!g || this.status !== 'playing' || !ACTING_PHASES.includes(g.phase)) return;
    const seat = g.turn;
    const info = this.seats[seat]!;
    if (timedOut && !info.auto) {
      info.timeouts++;
      if (info.timeouts >= MAX_TIMEOUTS) info.auto = true;
    }
    const r = actAny(g, seat, autoActionAny(g, seat));
    if (!r.ok) throw new Error(`autopilot produced an illegal move: ${r.error}`); // cannot happen: autoAction is legal by construction (tested)
    this.game = r.state;
    this.afterChange();
  }

  private turnMs(): number {
    return (TURN_SECONDS_OVERRIDE ?? SPEED_SECONDS[this.settings.speed]) * 1000;
  }

  /** (Re)start the timer for whoever is to act now. */
  private scheduleTurn() {
    this.turnTimer?.clear();
    this.turnTimer = null;
    this.turnDeadline = null;
    const g = this.game;
    if (!g || this.status !== 'playing' || !ACTING_PHASES.includes(g.phase)) return;
    const info = this.seats[g.turn]!;
    const ms = info.auto ? AUTO_MOVE_MS : this.turnMs();
    this.turnDeadline = Date.now() + ms;
    this.turnTimer = this.clock.setTimeout(() => this.autoMove(!info.auto), ms);
  }

  /** Schedule server-driven transitions (collect trick, next hand), restart the turn timer, push views. */
  private afterChange() {
    const g = this.game!;
    if (g.phase === 'gameOver') this.status = 'finished';
    if ((g.phase === 'trickDone' || g.phase === 'handOver') && !this.advanceTimer) {
      const delay = g.phase === 'trickDone' ? TRICK_PAUSE_MS : HAND_PAUSE_MS;
      this.advanceTimer = this.clock.setTimeout(() => {
        this.advanceTimer = null;
        if (this.status !== 'playing' || !this.game) return;
        this.game = advanceAny(this.game, randomInt);
        this.afterChange();
      }, delay);
    }
    this.scheduleTurn();
    this.applyKickQueue();
    this.assignPending();
    this.changed();
  }

  /** Public listing for the tables list. */
  listing(): TableListing & { quick: boolean; progress: number } {
    const joinable = this.status === 'waiting' ? this.seats.some((s) => !s) : this.seats.some((s) => s?.bot) && this.pending.length < this.seats.filter((s) => s?.bot).length;
    return {
      code: this.roomId,
      variant: this.variant,
      status: this.status,
      settings: this.settings,
      seats: this.seats.map((s) => (s ? { name: s.name, bot: s.bot } : null)),
      joinable,
      quick: this.quick,
      // how far the game is (for the "full table" progress bar): best team score vs target, 0..100
      progress: this.game ? gameProgress(this.game, this.target) : 0,
    };
  }

  /** Push per-seat views and refresh the public listing. */
  private changed() {
    this.broadcastViews();
    if (this.settings.visibility === 'public') void this.setMetadata(this.listing());
  }

  private broadcastViews() {
    const now = Date.now();
    const seatsPublic = this.seats.map((s) =>
      s
        ? {
            name: s.name,
            connected: s.bot || !!s.sessionId,
            heldMsLeft: s.heldUntil ? Math.max(0, s.heldUntil - now) : null,
            auto: s.auto,
            bot: s.bot,
            level: s.level,
          }
        : null,
    );
    const ownerTok = this.resolveOwner();
    const ownerSeat = this.ownerSeat();
    const chooser = this.partnerChooser();
    for (const c of this.clients) {
      const mySeat = this.seatOf(c);
      const view: RoomView = {
        code: this.roomId,
        variant: this.variant,
        target: this.target,
        status: this.status,
        seats: seatsPublic,
        mySeat,
        game: this.game && mySeat !== null ? viewForAny(this.game, mySeat) : null,
        settings: this.settings,
        isOwner: this.members.get(c.sessionId)?.token === ownerTok,
        ownerSeat,
        partnerChooser: chooser,
        pending: this.pending.includes(c.sessionId),
        kickQueued: this.seats.flatMap((s, i) => (s && this.kickQueue.has(s.token) ? [i as Seat] : [])),
        turnDeadline: this.turnDeadline,
        serverNow: now,
      };
      c.send('state', view);
    }
  }
}
