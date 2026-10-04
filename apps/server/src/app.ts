import { LobbyRoom, Server, matchMaker } from '@colyseus/core';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { LammaRoom } from './LammaRoom.ts';
import { apiRouter } from './api.ts';
import { ADMIN_PAGE } from './admin.ts';
import { LEGAL_PAGES } from './legal.ts';
import { db } from './data/db.ts';
import { setMatchRoomFactory, tickCompetitions } from './competitions.ts';

/** Build and start the game server (used by index.ts and by the server tests). */
export async function startGameServer(port: number, opts: { dataDir?: string } = {}): Promise<Server> {
  db.open(opts.dataDir);
  const server = new Server({
    transport: new WebSocketTransport({ pingInterval: 5000, pingMaxRetries: 3 }),
    greet: false,
    gracefullyShutdown: false,
    express: (app) => {
      app.use('/api', apiRouter());
      app.get('/admin', (_req, res) => {
        res.type('html').send(ADMIN_PAGE);
      });
      for (const [path, html] of Object.entries(LEGAL_PAGES)) {
        app.get(path, (_req, res) => {
          res.type('html').send(html);
        });
      }
    },
  });
  // public tables are listed live through Colyseus' built-in lobby (private rooms are never listed)
  server.define('lamma', LammaRoom).enableRealtimeListing();
  server.define('lobby', LobbyRoom);
  await server.listen(port);

  // competition matches are private rooms only their players may sit in
  setMatchRoomFactory(async (spec) => {
    const room = await matchMaker.createRoom('lamma', { variant: spec.variant, settings: { visibility: 'private', target: spec.target || undefined, kick: false }, competition: spec });
    return room.roomId;
  });
  const tick = setInterval(() => void tickCompetitions().catch((e) => console.error('[competitions]', e)), 3000);
  const flush = () => {
    clearInterval(tick);
    db.flush();
  };
  process.once('SIGTERM', () => {
    flush();
    process.exit(0);
  });
  process.once('SIGINT', () => {
    flush();
    process.exit(0);
  });
  const shutdown = server.gracefullyShutdown.bind(server);
  server.gracefullyShutdown = async (...args: Parameters<typeof shutdown>) => {
    flush();
    return shutdown(...args);
  };
  return server;
}
