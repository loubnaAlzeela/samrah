# سجل العمل

سجل بكل ما يقوم به Claude في هذا المشروع، بالترتيب الزمني.

## 2026-10-08

1. **سحب التعديلات من GitHub** (`git pull` على main)
   - من `169db2b` إلى `e3b1e75` (fast-forward)، 106 ملفات.
   - وصل: حسابات، نوادي، مسابقات، متجر ومدفوعات، إشعارات، شات، قاعدة بيانات، شاشات جديدة في التطبيق، إيموجي وأصوات.
   - ملاحظة: تغيّر `package-lock.json` و`pubspec.lock`، فقد يلزم `npm install` و`flutter pub get`.

2. **شرح متطلبات تفعيل التسجيل وإنشاء الحساب** (قراءة فقط، بلا تعديل)
   - المصدر: `docs/server-setup.md` و`apps/server/src/auth-providers.ts`.
   - الحسابات (ضيف) تعمل بلا إعداد. المطلوب فقط لطرق الدخول الإضافية:
     - حفظ البيانات: Volume على `/app/data` في Railway.
     - الهاتف: `TWILIO_ACCOUNT_SID`، `TWILIO_AUTH_TOKEN`، `TWILIO_VERIFY_SID`.
     - Google: `GOOGLE_CLIENT_IDS` في الخادم و`GOOGLE_SERVER_CLIENT_ID` في التطبيق.
     - اختياري: `ADMIN_KEY` لصفحة `/admin`.

3. **إنشاء هذا السجل** (`docs/work-log.md`)

4. **إعداد الدخول بحساب Google** (خطوات في Google Cloud مع المستخدمة)
   - أُنشئ مفتاح debug محلي في `~/.android/debug.keystore` (لم يكن موجوداً)، وأُخذت بصمة SHA-1 له.
   - أُنشئ عميل OAuth من نوع Android (اسم الحزمة `com.samrah.app`) وعميل من نوع Web.
   - الإعداد المطلوب: `GOOGLE_CLIENT_IDS` في الخادم = معرّف Web ثم معرّف Android، و`--dart-define=GOOGLE_SERVER_CLIENT_ID` في التطبيق = معرّف Web.
   - للإطلاق لاحقاً: عميل Android ثانٍ ببصمة App signing من Play Console، ويُضاف إلى `GOOGLE_CLIENT_IDS`.

5. **Google على iOS**
   - أُنشئ عميل OAuth من نوع iOS (Bundle ID `com.samrah.app`).
   - عُدّل `apps/mobile/ios/Runner/Info.plist`: أُضيف `GIDClientID` و`GIDServerClientID` و`CFBundleURLTypes` (الرابط المعكوس).
   - `GOOGLE_CLIENT_IDS` في الخادم يحتوي معرّفات Web وAndroid وiOS.

6. **إعداد خادم Railway** (نفّذته المستخدمة من لوحة Railway)
   - ربط Volume باسم `samrah-volume` على `/app/data`.
   - إضافة `GOOGLE_CLIENT_IDS` (معرّفات Web وAndroid وiOS) وإعادة النشر.
   - تحقق: `GET /api/config` على الخادم الحي يعيد `auth: {phone: false, google: true}`، أي أن دخول Google مفعّل والهاتف غير مفعّل بعد.

7. **بناء الدخول بحساب Apple** (لم يكن موجوداً في الكود)
   - الخادم: `POST /auth/apple` يتحقق من توكن Apple (توقيع RS256 من مفاتيح Apple العامة، والمُصدِر، والجمهور = `APPLE_BUNDLE_ID` أو `com.samrah.app`، والانتهاء). حقل `appleId` في المستخدم وفهرس `apple` في قاعدة البيانات، و`auth.apple` في `/api/config`. لا يحتاج أي مفتاح سري. اختبار جديد في `api.test.ts`.
   - التطبيق: حزمة `sign_in_with_apple`، دالة `continueWithApple`، زر في شاشة الدخول والإعدادات (iPhone فقط)، ونص خطأ `appleTaken`.
   - iOS: ملف `Runner.entitlements` (Sign in with Apple) مضاف إلى مشروع Xcode.
   - المطلوب من المستخدمة: تفعيل Sign in with Apple للـ App ID `com.samrah.app` في حساب Apple Developer، ثم البناء على Mac.

8. **طبقة PostgreSQL** (تمهيداً للانتقال إلى AWS)
   - `apps/server/src/data/db.ts`: إذا وُجد `DATABASE_URL` تُحفظ البيانات في جدول `samrah_state` (صف JSONB واحد) بدل الملف، مع `DATABASE_SSL=1` لـ RDS. استيراد تلقائي لملف `samrah.json` عند أول تشغيل على قاعدة فارغة. حفظ متسلسل مع إعادة محاولة عند الفشل، وانتظار الحفظ الأخير عند الإيقاف (SIGTERM).
   - بدون `DATABASE_URL` يعمل الخادم كما كان تماماً (ملف أو ذاكرة).
   - اختبار: `test/db.test.ts` (يعمل عند ضبط `TEST_DATABASE_URL`)، وجرّبته على PostgreSQL 18 حقيقي، وتحققت يدوياً أن حساباً بقي بعد إيقاف الخادم وتشغيله. اختبارات الخادم كلها تمر.
   - ملاحظة: يُكتب المستند كاملاً عند كل حفظ، وهذا يكفي لآلاف اللاعبين. والتحول إلى جداول منفصلة مؤجَّل.
