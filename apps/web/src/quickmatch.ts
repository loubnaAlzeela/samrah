import type { Client } from '@colyseus/sdk';
import type { TableListing, Variant } from '@lamma/rules';

type SdkRoom = Awaited<ReturnType<Client['joinById']>>;
export interface Listed {
  roomId: string;
  metadata?: TableListing;
}

/** Read the current public tables once from the Colyseus lobby. */
export async function fetchPublicTables(client: Client): Promise<Listed[]> {
  const lobby = await client.joinOrCreate('lobby');
  try {
    return await new Promise<Listed[]>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('lobby timeout')), 5000);
      lobby.onMessage('rooms', (rooms: Listed[]) => {
        clearTimeout(t);
        resolve(rooms);
      });
    });
  } finally {
    void lobby.leave(true).catch(() => {});
  }
}

/**
 * «العب الآن»: join the first public table of this game that has room (empty seat before the start, or a computer
 * seat during a game); otherwise open a new public quick table that fills with computers after 20 seconds.
 * Pure SDK logic (no DOM) so the server tests can exercise it too.
 */
export async function quickMatch(client: Client, variant: Variant, name: string): Promise<SdkRoom> {
  const tables = await fetchPublicTables(client);
  const open = tables
    .filter((t) => t.metadata && t.metadata.variant === variant && t.metadata.joinable && t.metadata.status !== 'finished')
    // prefer tables that have not started (you play from the first card), then the fullest
    .sort((a, b) => Number(a.metadata!.status !== 'waiting') - Number(b.metadata!.status !== 'waiting') || count(b) - count(a));
  for (const t of open) {
    try {
      return await client.joinById(t.roomId, { name });
    } catch {
      /* filled up meanwhile: try the next one */
    }
  }
  return client.create('lamma', { variant, name, quick: true });
}

const count = (t: Listed) => t.metadata!.seats.filter((s) => s && !s.bot).length;
