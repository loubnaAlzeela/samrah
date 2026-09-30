import { startGameServer } from './app.ts';

const port = Number(process.env.PORT ?? 2567);
await startGameServer(port);
console.log(`[lamma] game server listening on ws://localhost:${port}`);
