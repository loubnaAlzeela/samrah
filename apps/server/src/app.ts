import { LobbyRoom, Server } from '@colyseus/core';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { LammaRoom } from './LammaRoom.ts';

/** Build and start the game server (used by index.ts and by the server tests). */
export async function startGameServer(port: number): Promise<Server> {
  const server = new Server({
    transport: new WebSocketTransport({ pingInterval: 5000, pingMaxRetries: 3 }),
    greet: false,
    gracefullyShutdown: false,
  });
  // public tables are listed live through Colyseus' built-in lobby (private rooms are never listed)
  server.define('lamma', LammaRoom).enableRealtimeListing();
  server.define('lobby', LobbyRoom);
  await server.listen(port);
  return server;
}
