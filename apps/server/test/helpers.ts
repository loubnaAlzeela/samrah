import { Client } from '@colyseus/sdk';
import type { RoomView } from '@lamma/rules';

type SdkRoom = Awaited<ReturnType<Client['joinById']>>;

let nextTestAccount = 1;

/** A signed-in account made straight on the server (the tests run it in-process): there is no guest sign-up any more.
 *  Loaded when called, because the tests set the server's environment before its modules load. */
export async function testAccount(name: string, kind: 'google' | 'apple' = 'google') {
  const { createAccount } = await import('../src/accounts.ts');
  const made = createAccount(name, kind, `test-${kind}-${nextTestAccount++}`);
  made.user.name = name; // the rooms' tests use one-letter names, which a real sign-in would not allow
  return made;
}

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

  /** the account token, made on first use */
  private authToken: string | null = null;
  async auth(): Promise<string> {
    return (this.authToken ??= (await testAccount(this.name)).token);
  }

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
    this.attach(await new Client(this.endpoint).create('lamma', { variant, settings, auth: await this.auth() }));
    await waitFor(() => !!this.view, 'first view');
    return this.view!.code;
  }

  async join(code: string, extra: object = {}) {
    this.attach(await new Client(this.endpoint).joinById(code, { auth: await this.auth(), ...extra }));
    await waitFor(() => !!this.view, 'join view');
  }

  send(type: string, payload?: unknown) {
    this.room.send(type, payload);
  }

  async leave() {
    if (!this.room) return;
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
