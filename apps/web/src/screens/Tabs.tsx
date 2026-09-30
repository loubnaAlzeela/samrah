import { useState } from 'react';
import type { Variant } from '@lamma/rules';
import { BottomNav, Header, NameSheet, useToast } from '../components/Chrome.tsx';
import { Icon, type IconId } from '../components/Icons.tsx';
import { Stage } from '../components/Stage.tsx';
import { num } from '../i18n.ts';
import { saveLastGame, savedName } from '../net.ts';
import { type TabName, navigate } from '../router.ts';
import { GAMES } from './Home.tsx';

/** Common frame for the bottom-nav tabs: header + content + nav. Coins/levels/store/clubs/challenges are display-only in phase A. */
function TabFrame({ on, children }: { on: TabName; children: (toast: (t: string) => void) => React.ReactNode }) {
  const [toast, showToast] = useToast();
  const [nameOpen, setNameOpen] = useState(false);
  return (
    <Stage className="tabs-v3">
      <Header onEditName={() => setNameOpen(true)} toast={showToast} />
      {children(showToast)}
      <BottomNav on={on} />
      {nameOpen && <NameSheet initial={savedName()} onClose={() => setNameOpen(false)} onDone={() => setNameOpen(false)} />}
      {toast && <div className="stage-toast">{toast}</div>}
    </Stage>
  );
}

const RULES: Record<string, string[]> = {
  tarneeb: [
    '4 لاعبين، كل متقابلين فريق، والدور عكس عقارب الساعة.',
    'المزايدة من 7 لـ13، وكل طلب أعلى من اللي قبله، و«تمرير» يطلّعك من المزايدة.',
    'صاحب أعلى طلب يختار الطرنيب ويبدأ. لازم تلحق الشكل إذا معك، والطرنيب يقطع.',
    'جبت طلبك أو أكثر: تاخذ عدد أكلاتك. فشلت: ينطرح الطلب وياخد الخصم أكلاته.',
    'كبوت بدون طلب 13 = 16، طلب 13 وجابها = 26، وفشل = −16.',
  ],
  syrian41: [
    'آخر ورقة للموزّع تنقلب، والطرنيب هو الشكل التاني من نفس اللون (قلب↔ديناري، بستوني↔سباتي).',
    'كل لاعب يطلب مرة وحدة لحاله من 2 لـ13، وإذا المجموع أقل من 11 يعاد التوزيع.',
    'جبت طلبك: ينضاف الطلب. فشلت: ينطرح.',
    'يفوز الفريق لما يوصل أحد لاعبيه لـ41 وشريكه فوق الصفر.',
  ],
};

export function Games() {
  const [rules, setRules] = useState<string | null>(null);
  return (
    <TabFrame on="games">
      {(toast) => (
        <>
          <h1 className="ptitle">الألعاب</h1>
          <div className="glist">
            {GAMES.map((g) => (
              <div key={g.id} className={`grow ${g.ready ? '' : 'soon'}`}>
                <div className="gf" aria-hidden="true">
                  <i style={{ transform: 'rotate(-14deg)' }} />
                  <i />
                  <i style={{ transform: 'rotate(14deg)' }} />
                </div>
                <div className="gt">
                  <h3>{g.name}</h3>
                  <p>{g.ready ? g.desc : '4 لاعبين'}</p>
                </div>
                {g.ready ? (
                  <>
                    <button className="ic" aria-label={`قوانين ${g.name}`} onClick={() => setRules(g.id)}>
                      <Icon id="i-book" />
                    </button>
                    <button
                      className="btn play-btn"
                      onClick={() => {
                        saveLastGame(g.id as Variant);
                        navigate({ name: 'home' });
                      }}
                    >
                      العب
                    </button>
                  </>
                ) : (
                  <button className="soon-tag" onClick={() => toast(`${g.name} قريباً`)}>
                    قريباً
                  </button>
                )}
              </div>
            ))}
          </div>
          {rules && (
            <>
              <div className="dim" onClick={() => setRules(null)} />
              <div className="bsheet rules-sheet" role="dialog" aria-label="القوانين">
                <div className="grab" />
                <header>
                  <h2>قوانين {GAMES.find((g) => g.id === rules)!.name}</h2>
                  <button className="ic close" aria-label="إغلاق" onClick={() => setRules(null)}>
                    <Icon id="i-x" />
                  </button>
                </header>
                <ul className="rules">
                  {RULES[rules].map((r) => (
                    <li key={r}>{r}</li>
                  ))}
                </ul>
              </div>
            </>
          )}
        </>
      )}
    </TabFrame>
  );
}

export function Store() {
  const [cur, setCur] = useState<'coins' | 'stars'>('coins');
  const packs = cur === 'coins' ? [500, 1200, 3000, 8000] : [20, 50, 120, 300];
  const icon: IconId = cur === 'coins' ? 'i-coin' : 'i-starc';
  return (
    <TabFrame on="store">
      {(toast) => (
        <>
          <h1 className="ptitle">المتجر</h1>
          <div className="seg store-seg" role="group" aria-label="نوع العملة">
            <button aria-pressed={cur === 'coins'} onClick={() => setCur('coins')}>
              وحدات
            </button>
            <button aria-pressed={cur === 'stars'} onClick={() => setCur('stars')}>
              نجوم
            </button>
          </div>
          <div className="sgrid">
            {packs.map((n) => (
              <div key={n} className="pack">
                <Icon id={icon} className="pi" />
                <b className="num">{n.toLocaleString('en')}</b>
                <button className="price num" onClick={() => toast('ما في شراء بهالنسخة')}>
                  0.00
                </button>
              </div>
            ))}
          </div>
          <p className="store-note">الأسعار تُحدَّد لاحقاً. ما في شراء فعلي بهالنسخة.</p>
        </>
      )}
    </TabFrame>
  );
}

export function Clubs() {
  return (
    <TabFrame on="clubs">
      {() => (
        <div className="locked">
          <div className="big">
            <Icon id="i-shield" />
          </div>
          <h2>الأندية</h2>
          <p>
            بتفتح لما توصل للمستوى <span className="num">{num(5)}</span>
          </p>
          <div className="lvl" dir="ltr">
            <b className="num">1</b>
            <span className="bar">
              <i style={{ width: '0%' }} />
            </span>
            <span className="num pct">0%</span>
          </div>
        </div>
      )}
    </TabFrame>
  );
}

const CHALLENGES = {
  day: [
    ['العب 3 جولات طرنيب', 0, 3, 5],
    ['اربح لعبتين مع شريك', 0, 2, 10],
    ['اجمع 13 أكلة (كبوت)', 0, 1, 25],
    ['ادعُ صديق يلعب معك', 0, 1, 15],
  ],
  week: [
    ['العب 20 جولة', 0, 20, 40],
    ['اربح 5 ألعاب', 0, 5, 60],
  ],
} as const;

export function Challenges() {
  const [p, setP] = useState<'day' | 'week'>('day');
  return (
    <TabFrame on="challenges">
      {() => (
        <>
          <h1 className="ptitle">التحديات</h1>
          <div className="seg store-seg" role="group" aria-label="الفترة">
            <button aria-pressed={p === 'day'} onClick={() => setP('day')}>
              اليوم
            </button>
            <button aria-pressed={p === 'week'} onClick={() => setP('week')}>
              الأسبوع
            </button>
          </div>
          <div className="chl">
            {CHALLENGES[p].map(([t, a, b, rw]) => (
              <div key={t} className="ch">
                <div className="ct">
                  <h3>{t}</h3>
                  <div className="pb">
                    <i style={{ width: `${(a / b) * 100}%` }} />
                  </div>
                  <small className="num">
                    {num(a)}/{num(b)}
                  </small>
                </div>
                <div className="rw">
                  <Icon id="i-starc" />
                  <span className="num">{num(rw)}</span>
                </div>
              </div>
            ))}
          </div>
          <p className="store-note">التحديات للعرض بهالنسخة، والتقدّم بينحسب بعد الحسابات.</p>
        </>
      )}
    </TabFrame>
  );
}
