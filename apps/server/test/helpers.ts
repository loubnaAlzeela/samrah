import { Client } from '@colyseus/sdk';
import type { RoomView } from '@lamma/rules';

type SdkRoom = Awaited<ReturnType<Client['joinById']>>;

/** A test player: a real WebSocket client that records every view, error and chat message it receives. */
export class TestPlayer {
  room!: SdkRoom;
  view: RoomView | null = null;
  views: RoomView[] = [];
  errors: string[] = [];
  token = '';
  leftCode: number | null = null;
  messages: { type: string; payload: unknown }[] = [];

  constructor(public endpoint: string, public name: string) {}

  attachForTest(r: SdkRoom) { this.attach(r); }
  private attach(r: SdkRoom) {
    this.room = r;
    r.reconnection.enabled = false;
    r.onMessage('welcome', (m: { token: string }) => (this.token = m.token));
    r.onMessage('state', (v: RoomView) => {
      this.view = v;
      this.views.push(v);
    });
    r.onMessage('error', (m: { error: string }) => this.errors.push(m.error));
    r.onMessage('*', (type: string | number, payload: unknown) => this.messages.push({ type: String(type), payload }));
    r.onLeave((code: number) => (this.leftCode = code));
  }

  async create(variant: string, settings: object = {}) {
    this.attach(await new Client(this.endpoint).create('lamma', { variant, settings, name: this.name }));
    await waitFor(() => !!this.view, 'first view');
    return this.view!.code;
  }

  async join(code: string, extra: object = {}) {
    this.attach(await new Client(this.endpoint).joinById(code, { name: this.name, ...extra }));
    await waitFor(() => !!this.view, 'join view');
  }

  send(type: string, payload?: unknown) {
    this.room.send(type, payload);
  }

  async leave() {
    await Promise.race([this.room.leave(true).catch(() => {}), sleep(300)]);
  }
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function waitFor(pred: () => boolean, what: string, ms = 8000) {
  const t0 = Date.now();
  while (!pred()) {
    if (Date.now() - t0 > ms) throw new Error('timeout waiting for ' + what);
    await sleep(15);
  }
}
