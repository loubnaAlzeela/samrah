/**
 * Dev helper: fill the empty seats of a room with 3 simple bot clients so one human can test the UI.
 *   npx tsx scripts/bots.mts <ROOMCODE> [count=3]
 * Bots are a TEST TOOL only (the product has no bots in slice 1).
 */
import { Client } from '@colyseus/sdk';
import type { RoomView } from '@lamma/rules';

const code = (process.argv[2] ?? '').toUpperCase();
const count = Number(process.argv[3] ?? 3);
const ENDPOINT = process.env.LAMMA_WS ?? 'ws://localhost:2567';
if (!/^[A-Z0-9]{6}$/.test(code)) {
  console.error('usage: tsx scripts/bots.mts <ROOMCODE> [count]');
  process.exit(1);
}

const names = ['بوت سامي', 'بوت رنا', 'بوت فادي'];
for (let i = 0; i < count; i++) {
  const room = await new Client(ENDPOINT).joinById(code, { name: names[i] ?? `بوت ${i}` });
  room.reconnection.enabled = false;
  let v: RoomView | null = null;
  let busy = false;
  room.onMessage('welcome', () => {});
  const trySit = () => {
    if (!v || v.status !== 'waiting' || v.mySeat !== null) return;
    const free = v.seats.map((s, k) => (s ? -1 : k)).filter((k) => k >= 0);
    if (free.length) room.send('sit', { seat: free[Math.floor(Math.random() * free.length)] });
  };
  room.onMessage('error', (m: { error: string }) => {
    if (m.error === 'seatTaken') setTimeout(trySit, 100 + Math.random() * 300);
    else console.log(names[i], 'error', m.error);
  });
  room.onMessage('state', (nv: RoomView) => {
    const first = v === null;
    v = nv;
    if (v.status === 'waiting') {
      if (first) setTimeout(trySit, 150 * (i + 1));
      return;
    }
    const g = v.game;
    if (!g || v.status !== 'playing' || g.turn !== v.mySeat || busy) return;
    busy = true;
    setTimeout(() => {
      busy = false;
      const cur = v?.game;
      if (!cur || cur.turn !== v?.mySeat) return;
      if (cur.phase === 'bidding')
        room.send('bid', {
          value: cur.variant === 'syrian41' ? 2 + Math.floor(Math.random() * 3) : (cur.minBid ?? 7) <= 8 && Math.random() < 0.5 ? cur.minBid : 'pass',
        });
      else if (cur.phase === 'trump') room.send('trump', { suit: cur.myHand[0][0] });
      else if (cur.phase === 'playing') room.send('play', { card: cur.legal[Math.floor(Math.random() * cur.legal.length)] });
    }, 700);
  });
  console.log(`${names[i]} joined ${code}`);
  // test helper: BOT_QUIT_AFTER_MS makes the LAST bot drop out mid-game (to see the away/autopilot states)
  if (process.env.BOT_QUIT_AFTER_MS && i === count - 1) {
    setTimeout(() => {
      console.log(`${names[i]} leaves`);
      void room.leave(true);
    }, Number(process.env.BOT_QUIT_AFTER_MS));
  }
}
