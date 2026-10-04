// Gifts at the table: a player sends another seat something small, paid in «وحدات». The table sees it fly across;
// the receiver keeps the count on their profile.
import { type User, blockedBetween, debit } from './accounts.ts';
import { db } from './data/db.ts';
import { notify } from './social.ts';
import { fail } from './util.ts';

export const GIFTS: { id: string; name: string; price: number }[] = [
  { id: 'rose', name: 'وردة', price: 20 },
  { id: 'coffee', name: 'فنجان قهوة', price: 30 },
  { id: 'tea', name: 'كاسة شاي', price: 30 },
  { id: 'dates', name: 'تمر', price: 50 },
  { id: 'cake', name: 'كيكة', price: 100 },
  { id: 'trophy', name: 'كأس', price: 200 },
  { id: 'crown', name: 'تاج', price: 500 },
  { id: 'diamond', name: 'ألماسة', price: 1000 },
];

/** Charges [from] and counts the gift for [to]; the room broadcasts it. */
export function giveGift(from: User, to: User, giftId: unknown) {
  const gift = GIFTS.find((g) => g.id === giftId) ?? fail('badGift');
  if (from.id === to.id) fail('badGift');
  if (blockedBetween(from, to) || !to.settings.allowGifts) fail('giftsOff', 403);
  debit(from, 'units', gift.price, `gift:${gift.id}`);
  to.stats.giftsReceived++;
  db.touch();
  notify(to.id, 'gifts', `وصلتك هدية من ${from.name}`, `${gift.name} 🎁`);
  return gift;
}
