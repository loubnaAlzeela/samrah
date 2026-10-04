# إعداد الخادم: الحسابات والدفع والإشعارات

الخادم (`apps/server`) يحفظ الحسابات والمحافظ والأندية والمسابقات والرسائل في ملف JSON واحد إلى أن تُبنى قاعدة البيانات:
`$LAMMA_DATA_DIR/samrah.json` (القيمة الافتراضية `data`).

**على Railway يجب ربط Volume** بالمسار `/app/data`، وإلا تُمسح البيانات مع كل نشر.

## متغيرات البيئة

| المتغير | لماذا | إلزامي؟ |
|---|---|---|
| `LAMMA_DATA_DIR` | مجلد ملف البيانات | لا (الافتراضي `data`) |
| `ADMIN_KEY` | مفتاح صفحة الإدارة `/admin` (12 حرفاً على الأقل). بدونه تبقى الإدارة مغلقة | نعم لتفعيل الأندية |
| `CLUBS_AUTO_APPROVE=1` | تفعيل الأندية الجديدة فوراً بلا موافقة | لا |
| `CLUBS_OPEN_UNTIL_USERS` | الأندية مفتوحة للجميع حتى هذا العدد من اللاعبين (الافتراضي 1000) | لا |
| `CLUBS_LEVEL_AFTER` | المستوى المطلوب للأندية بعد ذلك (الافتراضي 2) | لا |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | حساب خدمة Google (JSON كما هو أو base64): لـ Google Play وFirebase | للدفع على أندرويد والإشعارات |
| `GOOGLE_PLAY_PACKAGE` | اسم الحزمة (الافتراضي `com.samrah.app`) | لا |
| `FIREBASE_PROJECT_ID` | مشروع Firebase إن كان غير مشروع حساب الخدمة | لا |
| `APPLE_IAP_ISSUER_ID`، `APPLE_IAP_KEY_ID`، `APPLE_IAP_PRIVATE_KEY`، `APPLE_BUNDLE_ID` | التحقق من مشتريات App Store | للدفع على iOS |
| `TWILIO_ACCOUNT_SID`، `TWILIO_AUTH_TOKEN`، `TWILIO_VERIFY_SID` | رمز SMS للدخول برقم الهاتف | للدخول بالهاتف |
| `GOOGLE_CLIENT_IDS` | معرّفات OAuth للتطبيق (مفصولة بفواصل) | للدخول بحساب Google |
| `IAP_TEST_MODE=1` | قبول مشتريات وهمية على خادم التطوير فقط | لا، ولا يعمل مع `NODE_ENV=production` |

## التطبيق (`--dart-define`)

| المتغير | لماذا |
|---|---|
| `GAME_SERVER` | عنوان الخادم (الافتراضي خادم Railway) |
| `FIREBASE_API_KEY`، `FIREBASE_APP_ID`، `FIREBASE_SENDER_ID`، `FIREBASE_PROJECT_ID` | الإشعارات على الهاتف |
| `GOOGLE_SERVER_CLIENT_ID` | زر الدخول بحساب Google (يظهر فقط عند وجوده) |

## ما يلزم في المتاجر

- **Google Play Console**: منتجات قابلة للاستهلاك بالمعرّفات `units_500`، `units_1200`، `units_3500`، `units_8000`، `units_18000`، `units_50000`، `stars_50`، `stars_120`، `stars_350`، `stars_800`. ثم دعوة حساب الخدمة إلى Play Console بصلاحيتي عرض البيانات المالية وإدارة الطلبات.
- **App Store Connect**: المنتجات نفسها بالمعرّفات نفسها، ومفتاح In-App Purchase (ملف ‎.p8).
- **رابط سياسة الخصوصية**: `https://<الخادم>/privacy` (وأيضاً `/terms` و`/club-rules`).

## الإدارة

افتحي `https://<الخادم>/admin` واكتبي `ADMIN_KEY`. فيها: الموافقة على الأندية أو رفضها (مع إعادة المبلغ)، حسم المسابقات المجمّدة، الحكم على إخراج لاعب بلا مبرر، البلاغات وآراء اللاعبين، إيقاف حساب، منع من المسابقات، تعويض لاعب، وإشعار لكل اللاعبين.
