import type { Variant } from '@lamma/rules';
import { RoomConn, client } from './net.ts';
import { quickMatch } from './quickmatch.ts';

/** «العب الآن» for the web app: quick match and hand back a live RoomConn. */
export async function playNow(variant: Variant, name: string): Promise<RoomConn> {
  return RoomConn.adopt(await quickMatch(client, variant, name), name);
}
