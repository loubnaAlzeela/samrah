import { startGameServer } from './app.ts';

const port = Number(process.env.PORT ?? 2567);
// accounts, wallets, clubs and competitions live in $LAMMA_DATA_DIR/samrah.json until the database exists;
// on Railway that directory must be a mounted volume
const dataDir = process.env.LAMMA_DATA_DIR ?? 'data';
await startGameServer(port, { dataDir });
console.log(`[lamma] game server listening on ws://localhost:${port} (data in ${dataDir})`);
