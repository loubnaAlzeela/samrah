// The team's tools: approve or refuse new clubs, settle competitions, rule on appeals, read reports and feedback,
// suspend players, compensate them, and send a notice to everyone. Every call needs the `x-admin-key` header equal
// to ADMIN_KEY (no key set = the tools are off). The page at /admin is a small form over these calls.
import { timingSafeEqual } from 'node:crypto';
import express, { type NextFunction, type Request, type Response, Router } from 'express';
import * as A from './accounts.ts';
import * as K from './clubs.ts';
import * as C from './competitions.ts';
import { notify } from './social.ts';
import { db } from './data/db.ts';
import { ApiError, cleanText, fail } from './util.ts';

function checkKey(req: Request, _res: Response, next: NextFunction) {
  const want = process.env.ADMIN_KEY;
  const got = req.headers['x-admin-key'];
  if (!want || want.length < 12) return next(new ApiError(403, 'adminOff'));
  if (typeof got !== 'string' || got.length !== want.length || !timingSafeEqual(Buffer.from(got), Buffer.from(want))) return next(new ApiError(403, 'badKey'));
  next();
}

const ok =
  (h: (req: Request) => unknown) =>
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      res.json((await h(req)) ?? { ok: true });
    } catch (e) {
      next(e);
    }
  };

const userRef = (req: Request) => A.findUser(req.params.ref) ?? fail('badUser', 404);
const name = (id: string) => {
  const u = A.userById(id);
  return u ? `${u.name} (${u.no})` : id;
};

export function adminRouter(): Router {
  const r = Router();
  r.use(express.json({ limit: '32kb' }));
  r.use(checkKey);

  r.get(
    '/overview',
    ok(() => {
      const d = db.data;
      const users = Object.values(d.users);
      const day = Date.now() - 86400000;
      return {
        users: users.length,
        activeToday: users.filter((u) => u.lastSeen > day).length,
        clubsUnlockLevel: K.clubsUnlockLevel(),
        pendingClubs: K.pendingClubs(),
        frozen: Object.values(d.competitions)
          .filter((c) => c.phase === 'frozen' || c.phase === 'review')
          .map((c) => ({ id: c.id, title: c.title, phase: c.phase, organiser: name(c.organiserId), complaints: c.complaints.length, stale: C.staleFrozen().includes(c) })),
        kicked: Object.values(d.competitions).flatMap((c) => c.kicked.filter((e) => e.paid > 0).map((e) => ({ comp: c.id, title: c.title, entry: e.id, players: e.userIds.map(name).join(' و ') }))),
        reports: d.reports.slice(-100).reverse().map((x) => ({ ...x, from: name(x.from), against: name(x.against) })),
        feedback: d.feedback.slice(-100).reverse().map((x) => ({ ...x, from: name(x.from) })),
        purchases: Object.values(d.purchases).slice(-50).reverse(),
      };
    }),
  );

  r.post('/clubs/:id/approve', ok((req) => K.approveClub(req.params.id)));
  r.post('/clubs/:id/reject', ok((req) => K.rejectClub(req.params.id, req.body?.reason)));
  r.post('/competitions/:id/settle', ok((req) => C.settle('admin', req.params.id, req.body ?? {})));
  r.post('/competitions/:id/unjust-kick/:eid', ok((req) => C.unjustKick(req.params.id, req.params.eid)));

  r.get(
    '/users/:ref',
    ok((req) => {
      const u = userRef(req);
      return { ...A.meView(u), banned: u.banned, ledger: db.data.ledger.filter((l) => l.userId === u.id).slice(-50).reverse() };
    }),
  );
  r.post(
    '/users/:ref/ban',
    ok((req) => {
      const u = userRef(req);
      u.banned = req.body?.ban !== false;
      if (u.banned) for (const [t, s] of Object.entries(db.data.sessions)) if (s.userId === u.id) delete db.data.sessions[t];
      db.touch();
    }),
  );
  r.post(
    '/users/:ref/comp-ban',
    ok((req) => {
      const u = userRef(req);
      const level = req.body?.level;
      u.compBanned = level === 'organise' || level === 'all' ? level : false;
      db.touch();
    }),
  );
  r.post(
    '/users/:ref/credit',
    ok((req) => {
      const u = userRef(req);
      const currency = req.body?.currency === 'stars' ? 'stars' : 'units';
      const amount = Number(req.body?.amount);
      if (!Number.isInteger(amount) || amount <= 0 || amount > 1_000_000) fail('badAmount');
      const why = cleanText(req.body?.reason, 120) ?? 'تعويض من فريق سمرة';
      A.credit(u, currency, amount, `admin:${why}`);
      notify(u.id, 'system', 'تعويض من فريق سمرة', `أُضيفت ${amount} ${currency === 'stars' ? 'نجمة' : 'وحدة'} إلى محفظتك: ${why}`);
    }),
  );
  r.post(
    '/broadcast',
    ok((req) => {
      const title = cleanText(req.body?.title, 60) ?? fail('badText');
      const body = cleanText(req.body?.body, 300) ?? fail('badText');
      for (const u of Object.values(db.data.users)) notify(u.id, 'system', title, body);
      return { sent: Object.keys(db.data.users).length };
    }),
  );
  return r;
}

/** The admin page: one HTML file, the key typed in by hand and kept only in the browser tab. */
export const ADMIN_PAGE = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>إدارة سمرة</title><style>
body{font-family:system-ui,sans-serif;background:#1b1b1b;color:#f5ead6;margin:0;padding:16px;max-width:900px;margin:auto}
h1{color:#fa8112}h2{border-bottom:1px solid #444;padding-bottom:4px;margin-top:28px}
input,select,textarea{background:#2a2a2a;color:#f5ead6;border:1px solid #555;border-radius:6px;padding:6px;font:inherit}
button{background:#fa8112;color:#111;border:0;border-radius:6px;padding:6px 12px;font:inherit;font-weight:700;cursor:pointer;margin:2px}
button.no{background:#555;color:#eee}.row{background:#242424;border-radius:8px;padding:10px;margin:8px 0}.muted{color:#aaa;font-size:13px}
</style></head><body><h1>إدارة سمرة</h1>
<p><input id="key" type="password" placeholder="مفتاح الإدارة" size="30"> <button onclick="load()">دخول</button> <span id="msg" class="muted"></span></p>
<div id="out"></div>
<h2>لاعب</h2><p><input id="ref" placeholder="رقم اللاعب"> <button onclick="user()">اعرض</button></p><pre id="u" class="muted" style="white-space:pre-wrap"></pre>
<p><button onclick="act('/users/'+ref.value+'/ban',{ban:true})">إيقاف الحساب</button><button class="no" onclick="act('/users/'+ref.value+'/ban',{ban:false})">رفع الإيقاف</button>
<select id="cb"><option value="">بلا حظر مسابقات</option><option value="organise">ممنوع من التنظيم</option><option value="all">ممنوع من المسابقات كلها</option></select><button onclick="act('/users/'+ref.value+'/comp-ban',{level:cb.value||false})">احفظ</button></p>
<p><input id="amt" type="number" placeholder="الكمية" style="width:90px"><select id="cur"><option value="units">وحدات</option><option value="stars">نجوم</option></select><input id="why" placeholder="السبب"><button onclick="act('/users/'+ref.value+'/credit',{amount:+amt.value,currency:cur.value,reason:why.value})">عوّض</button></p>
<h2>إشعار للجميع</h2><p><input id="bt" placeholder="العنوان" size="30"><br><textarea id="bb" rows="3" cols="50" placeholder="النص"></textarea><br><button onclick="act('/broadcast',{title:bt.value,body:bb.value})">أرسل</button></p>
<script>
const api=(p,b)=>fetch('/api/admin'+p,{method:b?'POST':'GET',headers:{'x-admin-key':key.value,'content-type':'application/json'},body:b?JSON.stringify(b):undefined}).then(async r=>{const j=await r.json();if(!r.ok)throw new Error(j.error);return j});
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
async function act(p,b){try{await api(p,b);msg.textContent='تم';load()}catch(e){msg.textContent='خطأ: '+e.message}}
async function user(){try{u.textContent=JSON.stringify(await api('/users/'+ref.value),null,1)}catch(e){u.textContent='خطأ: '+e.message}}
async function load(){try{const o=await api('/overview');msg.textContent='اللاعبون: '+o.users+' · نشطون اليوم: '+o.activeToday+' · مستوى فتح الأندية: '+o.clubsUnlockLevel;
let h='<h2>أندية بانتظار الموافقة</h2>'+(o.pendingClubs.map(c=>'<div class="row"><b>'+esc(c.name)+'</b> · '+esc(c.type)+' · '+esc(c.motto)+'<div class="muted">المؤسس: '+esc(c.founder&&c.founder.name)+' ('+esc(c.founder&&c.founder.no)+')</div><button onclick="act(\\'/clubs/'+c.id+'/approve\\')">موافقة</button><button class="no" onclick="act(\\'/clubs/'+c.id+'/reject\\',{reason:prompt(\\'سبب الرفض\\')||undefined})">رفض وإعادة المبلغ</button></div>').join('')||'<p class="muted">لا شيء</p>');
h+='<h2>مسابقات بشكاوى</h2>'+(o.frozen.map(c=>'<div class="row"><b>'+esc(c.title)+'</b> · '+c.phase+' · شكاوى: '+c.complaints+(c.stale?' · <b>تأخر المنظم</b>':'')+'<div class="muted">المنظم: '+esc(c.organiser)+'</div><button onclick="act(\\'/competitions/'+c.id+'/settle\\',{action:\\'confirm\\'})">اعتماد النتيجة</button><button class="no" onclick="act(\\'/competitions/'+c.id+'/settle\\',{action:\\'refund\\'})">إعادة الرسوم</button></div>').join('')||'<p class="muted">لا شيء</p>');
h+='<h2>لاعبون أخرجهم المنظم</h2>'+(o.kicked.map(k=>'<div class="row">'+esc(k.players)+' من «'+esc(k.title)+'» <button class="no" onclick="act(\\'/competitions/'+k.comp+'/unjust-kick/'+k.entry+'\\')">طرد بلا مبرر: أعد الرسوم واحظر المنظم</button></div>').join('')||'<p class="muted">لا شيء</p>');
h+='<h2>البلاغات</h2>'+(o.reports.map(x=>'<div class="row"><b>'+esc(x.reason)+'</b> · '+esc(x.from)+' ← على '+esc(x.against)+'<div>'+esc(x.text)+'</div><div class="muted">'+new Date(x.at).toLocaleString('ar')+' '+esc(x.where)+'</div></div>').join('')||'<p class="muted">لا شيء</p>');
h+='<h2>آراء اللاعبين</h2>'+(o.feedback.map(x=>'<div class="row"><b>'+esc(x.kind)+'</b> · '+esc(x.from)+'<div>'+esc(x.text)+'</div></div>').join('')||'<p class="muted">لا شيء</p>');
out.innerHTML=h}catch(e){msg.textContent='خطأ: '+e.message}}
</script></body></html>`;
