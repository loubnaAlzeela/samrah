// Server error codes (the `error` message and create/join failures) as
// Modern Standard Arabic text. Mirrors apps/web/src/i18n.ts ERRORS.
const _errors = {
  'notYourTurn': 'ليس دورك',
  'badBid': 'طلب غير صالح',
  'mustFollowSuit': 'يجب أن تتبع الشكل المطلوب',
  'notInHand': 'هذه الورقة ليست معك',
  'wrongPhase': 'ليس هذا وقتها',
  'seatTaken': 'المقعد محجوز',
  'gameStarted': 'بدأت اللعبة في هذه الغرفة',
  'roomFull': 'اكتملت الغرفة',
  'badName': 'اكتب اسمك',
  'notFound': 'لم نجد غرفة بهذا الرمز',
  'network': 'تعذّر الاتصال بخادم اللعبة',
  'gameFull': 'الطاولة ممتلئة',
  'kicked': 'أخرجك صاحب الغرفة من الطاولة',
  'notOwner': 'هذا لصاحب الغرفة فقط',
  'kickDisabled': 'إخراج اللاعبين غير مفعّل في هذه اللعبة',
  'badSettings': 'إعدادات غير صالحة',
  'chatOff': 'الدردشة مغلقة في هذه اللعبة',
  'chatTooFast': 'تمهّل، أرسلت رسائل كثيرة',
  'badChat': 'الرسالة طويلة أو فارغة',
  'badContract': 'طلبة غير صالحة',
  'contractUsed': 'لُعبت هذه الطلبة في هذه المملكة',
  'badDouble': 'لا يمكنك تدبيل هذه الورقة',
  'cannotPlace': 'لا يمكن وضع هذه الورقة الآن',
  'noPlayers': 'لا يوجد لاعبون',
  'badCall': 'لا يمكنك هذا الطلب الآن',
  'badSuit': 'لا يمكنك اختيار هذا النوع',
  'badRaise': 'مضاعفة غير صالحة',
  'badDraw': 'سحب غير صالح',
  'fireEmpty': 'لا توجد ورقة في النار',
  'badMeld': 'هذه ليست مجموعة صحيحة',
  'openTooLow': 'مجموع نزولك الأول أقل من المطلوب',
  'mustUseFire': 'يجب أن تنزّل ورقة النار التي أخذتها',
  'notOpened': 'انزل مجموعاتك أولًا قبل التركيب',
  'cannotLayoff': 'لا تركب هذه الورقة على هذه المجموعة',
  'closedTrump': 'اللعب مغلق: لا تبدأ بورقة حكم ومعك نوع آخر',
};

/// Arabic text for a server error code or a connection exception.
String errorText(Object error) {
  final s = error.toString();
  if (_errors.containsKey(s)) return _errors[s]!;
  for (final e in _errors.entries) {
    if (s.contains(e.key)) return e.value;
  }
  if (s.contains('Connection') || s.contains('Socket') || s.contains('refused')) return _errors['network']!;
  return 'حدث خطأ، حاول مرة أخرى';
}
