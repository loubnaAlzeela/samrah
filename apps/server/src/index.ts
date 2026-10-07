import { startGameServer } from './app.ts';

const port = Number(process.env.PORT ?? 2567);
// accounts, wallets, clubs and competitions are saved in PostgreSQL when DATABASE_URL is set; otherwise in
// $LAMMA_DATA_DIR/samrah.json (on Railway that directory must be a mounted volume)
const dataDir = process.env.LAMMA_DATA_DIR ?? 'data';
const databaseUrl = process.env.DATABASE_URL || undefined;
await startGameServer(port, { dataDir, databaseUrl });
console.log(`[lamma] game server listening on ws://localhost:${port} (data in ${databaseUrl ? 'PostgreSQL' : dataDir})`);
