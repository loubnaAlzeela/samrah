import type { Suit } from '@lamma/rules';

/** Western digits everywhere (owner decision). Never use toLocaleString('ar'). */
const nf = new Intl.NumberFormat('ar-u-nu-latn', { useGrouping: false });
export function num(n: number): string {
  return nf.format(Math.abs(n));
}
/** Signed number as text; the caller wraps it in <bdi dir="ltr"> (see <Num/>). Uses U+2212 for minus. */
export function signed(n: number, plus = false): string {
  if (n < 0) return '−' + num(n);
  return (plus && n > 0 ? '+' : '') + num(n);
}
/** Convert Arabic-Indic / Persian digits to Western (room codes, inputs). */
export function toLatinDigits(s: string): string {
  return s.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0));
}

export const SUIT_NAME: Record<Suit, string> = { H: 'قلب', D: 'ديناري', S: 'بستوني', C: 'سباتي' };
export const RANK_LABEL: Record<number, string> = { 11: 'J', 12: 'Q', 13: 'K', 14: 'A' };
export function rankLabel(r: number): string {
  return RANK_LABEL[r] ?? String(r);
}

const ERRORS: Record<string, string> = {
  notYourTurn: 'مو دورك',
  badBid: 'طلب غير صالح',
  mustFollowSuit: 'لازم تلحق الشكل',
  notInHand: 'الورقة مو معك',
  wrongPhase: 'مو وقتها',
  seatTaken: 'المقعد محجوز',
  gameStarted: 'اللعبة بدأت بهالغرفة',
  roomFull: 'الغرفة اكتملت',
  badName: 'اكتب اسم',
  notFound: 'ما لقينا غرفة بهالكود',
  network: 'تعذّر الاتصال بسيرفر اللعب',
  gameFull: 'الطاولة ممتلئة',
  kicked: 'صاحب الغرفة أخرجك من الطاولة',
  notOwner: 'هذا لصاحب الغرفة فقط',
  notBetweenHands: 'الإخراج بين الجولات فقط',
  kickDisabled: 'إخراج اللاعبين مو مفعّل بهاللعبة',
  badSettings: 'إعدادات غير صالحة',
  chatOff: 'الدردشة مطفية بهاللعبة',
  chatTooFast: 'على مهلك، رسائل كثير',
  badChat: 'الرسالة طويلة أو فاضية',
};
export function errorText(code: string): string {
  return ERRORS[code] ?? 'صار خطأ، جرّب مرة ثانية';
}

export const NOTE_TEXT: Record<string, string> = {
  made: 'جابوا الطلب',
  kaboot: 'كبوت!',
  kaboot13: 'طلبوا 13 وجابوها!',
  fail: 'ما جابوا الطلب',
  fail13: 'طلبوا 13 وما جابوها',
  allPass: 'الكل مرّر: إعادة توزيع',
  lowBids: 'مجموع الطلبات أقل من 11: إعادة توزيع',
  syrian: 'انتهت الجولة',
};
