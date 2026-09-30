import { Client } from '@colyseus/sdk';
import { type ChatMessage, CLOSE_KICKED, CLOSE_REPLACED, CLOSE_ROOM_FULL, type RoomSettings, type RoomView, type Variant } from '@lamma/rules';

type SdkRoom = Awaited<ReturnType<Client['joinById']>>;

/** Game server endpoint comes from the environment; the web page and the game server may live on different hosts. */
export const GAME_SERVER: string =
  (import.meta.env.VITE_GAME_SERVER as string | undefined) ||
  `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.hostname}:2567`;

export const client = new Client(GAME_SERVER);

// ---- persistence (seat token per room, player name). Storage may be unavailable: never throw. ----
function lsGet(k: string): string | null {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
}
function lsSet(k: string, v: string) {
  try {
    localStorage.setItem(k, v);
  } catch {
    /* private mode */
  }
}
export const savedName = () => lsGet('lamma:name') ?? '';
/** Guest profile shown in the header (display only until accounts exist). */
export function guestProfile() {
  return { name: savedName(), level: 1, progress: 0, coins: 0, stars: 0 };
}
export const lastGame = () => (lsGet('lamma:game') === 'syrian41' ? 'syrian41' : 'tarneeb') as Variant;
export const saveLastGame = (v: Variant) => lsSet('lamma:game', v);
/** Local per-device preference: mute sounds (there are no sounds yet; stored for later). */
export const soundOn = () => lsGet('lamma:sound') !== 'off';
export const setSoundOn = (on: boolean) => lsSet('lamma:sound', on ? 'on' : 'off');

/** Local mute list (per device, never sent to the server): muted player names for chat bubbles/log. */
function mutedSet(): Set<string> {
  try {
    return new Set(JSON.parse(lsGet('lamma:muted') || '[]'));
  } catch {
    return new Set();
  }
}
export const isMuted = (name: string) => mutedSet().has(name);
export function toggleMuted(name: string) {
  const s = mutedSet();
  if (s.has(name)) s.delete(name);
  else s.add(name);
  lsSet('lamma:muted', JSON.stringify([...s]));
}
export const saveName = (n: string) => lsSet('lamma:name', n);
const tokenKey = (code: string) => `lamma:seat:${code}`;

export type ConnStatus = 'connecting' | 'connected' | 'reconnecting' | 'closed';

function errCode(e: unknown): string {
  const m = (e as { message?: string })?.message ?? '';
  if (/not found/i.test(m)) return 'notFound';
  const known = m.match(/gameStarted|gameFull|roomFull|kicked|badName|badVariant|badSettings/);
  if (known) return known[0];
  return 'network';
}

/**
 * One live connection to a room. Handlers are attached the moment the room object exists,
 * so the first 'welcome'/'state' messages are never missed. Reconnects with the seat token on drops.
 */
export class RoomConn {
  view: RoomView | null = null;
  chat: ChatMessage[] = [];
  status: ConnStatus = 'connecting';
  fatal: string | null = null;
  lastError: { code: string; at: number } | null = null;
  private room: SdkRoom | null = null;
  private listeners = new Set<() => void>();
  private closedByUs = false;

  constructor(public code: string, private name: string) {}

  subscribe(fn: () => void) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }
  private emit() {
    for (const l of this.listeners) l();
  }

  /** Wrap a room that was joined elsewhere (quick match). */
  static adopt(room: SdkRoom, name: string): RoomConn {
    const conn = new RoomConn(room.roomId, name);
    conn.attach(room);
    return conn;
  }

  static async create(variant: Variant, settings: Partial<RoomSettings>, name: string): Promise<RoomConn> {
    const room = await client.create('lamma', { variant, settings, name });
    const conn = new RoomConn(room.roomId, name);
    conn.attach(room);
    return conn;
  }

  async connect(): Promise<void> {
    try {
      const room = await client.joinById(this.code, { name: this.name, token: lsGet(tokenKey(this.code)) ?? undefined });
      this.attach(room);
    } catch (e) {
      this.fatal = errCode(e);
      this.status = 'closed';
      this.emit();
    }
  }

  private attach(room: SdkRoom) {
    this.room = room;
    room.reconnection.enabled = false; // the server holds seats by token; we rejoin ourselves
    room.onMessage('welcome', (m: { token: string; code: string }) => lsSet(tokenKey(m.code), m.token));
    room.onMessage('state', (v: RoomView) => {
      this.view = v;
      this.status = 'connected';
      this.emit();
    });
    room.onMessage('error', (m: { error: string }) => {
      this.lastError = { code: m.error, at: Date.now() };
      this.emit();
    });
    room.onMessage('chat', (m: ChatMessage) => {
      this.chat = [...this.chat.slice(-49), m];
      this.emit();
    });
    room.onLeave((code: number) => {
      this.room = null;
      if (this.closedByUs) return;
      if (code === CLOSE_REPLACED) return this.die('replaced');
      if (code === CLOSE_ROOM_FULL) return this.die('roomFull');
      if (code === CLOSE_KICKED) return this.die('kicked');
      void this.reconnectLoop();
    });
    this.status = 'connected';
    this.emit();
  }

  private die(reason: string) {
    this.fatal = reason;
    this.status = 'closed';
    this.emit();
  }

  private async reconnectLoop() {
    this.status = 'reconnecting';
    this.emit();
    const deadline = Date.now() + 100_000;
    while (!this.closedByUs && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 2000));
      try {
        const room = await client.joinById(this.code, { name: this.name, token: lsGet(tokenKey(this.code)) ?? undefined });
        this.attach(room);
        return;
      } catch (e) {
        const c = errCode(e);
        if (c !== 'network') return this.die(c);
      }
    }
    if (!this.closedByUs) this.die('network');
  }

  send(type: string, payload?: unknown) {
    this.room?.send(type, payload);
  }

  close() {
    this.closedByUs = true;
    void this.room?.leave(true);
    this.room = null;
  }
}

/** Hand-off of a freshly created room from the lobby to the room screen (same page, no reconnect). */
let pending: RoomConn | null = null;
export function handOff(c: RoomConn) {
  pending = c;
}
export function takeHandOff(code: string): RoomConn | null {
  if (pending && pending.code === code) {
    const c = pending;
    pending = null;
    return c;
  }
  return null;
}
