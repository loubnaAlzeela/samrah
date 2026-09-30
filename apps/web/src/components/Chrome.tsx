import { useState } from 'react';
import { num } from '../i18n.ts';
import { guestProfile, saveName } from '../net.ts';
import { type TabName, navigate } from '../router.ts';
import { Icon, type IconId } from './Icons.tsx';

/** Shared header (layout-v3 §1): icon row, guest profile capsule, two wallets. Display only in phase A. */
export function Header({ onEditName, toast }: { onEditName: () => void; toast: (t: string) => void }) {
  const g = guestProfile();
  return (
    <>
      <div className="hbar">
        <div className="grp">
          <button className="ic" aria-label="الأصدقاء" onClick={() => toast('الأصدقاء قريباً')}>
            <Icon id="i-users" />
          </button>
          <button className="ic" aria-label="الإشعارات" onClick={() => toast('ما في إشعارات')}>
            <Icon id="i-bell" />
          </button>
        </div>
        <div className="grp">
          <button className="ic" aria-label="الإعدادات" onClick={onEditName}>
            <Icon id="i-gear" />
          </button>
        </div>
      </div>
      <button className="prof" onClick={onEditName} aria-label={`ملفك: ${g.name || 'ضيف'}، المستوى ${g.level}. اضغط لتغيير الاسم`}>
        <span className="pav" aria-hidden="true">
          {(g.name || 'ض').slice(0, 1)}
        </span>
        <span className="pinfo">
          <span className="pname">{g.name || 'ضيف'}</span>
          <span className="lvl" dir="ltr">
            <b className="num">{num(g.level)}</b>
            <span className="bar">
              <i style={{ width: `${g.progress}%` }} />
            </span>
            <span className="num pct">{num(g.progress)}%</span>
          </span>
        </span>
      </button>
      <div className="wallets" dir="ltr">
        <Wallet icon="i-coin" label="وحدات" value={g.coins} />
        <Wallet icon="i-starc" label="نجوم" value={g.stars} />
      </div>
    </>
  );
}

function Wallet({ icon, label, value }: { icon: IconId; label: string; value: number }) {
  return (
    <div className="wal" aria-label={`${label}: ${value}`}>
      <Icon id={icon} className="wi" />
      <b className="num">{num(value)}</b>
      <button className="add" aria-label={`اشترِ ${label}`} onClick={() => navigate({ name: 'store' })}>
        <Icon id="i-plus2" />
      </button>
    </div>
  );
}

const NAV: [TabName, IconId, string][] = [
  ['store', 'i-bag', 'المتجر'],
  ['games', 'i-cards', 'الألعاب'],
  ['home', 'i-home', 'الرئيسية'],
  ['clubs', 'i-shield', 'الأندية'],
  ['challenges', 'i-flag', 'التحديات'],
];

/** Bottom navigation, 5 tabs (layout-v3 §8). Order from the right: store, games, HOME, clubs, challenges. */
export function BottomNav({ on }: { on: TabName }) {
  return (
    <nav className="nav5" aria-label="التنقل">
      {NAV.map(([k, ic, t]) => (
        <button key={k} className={`${k === 'home' ? 'home' : ''} ${on === k ? 'on' : ''}`} aria-current={on === k ? 'page' : undefined} onClick={() => navigate({ name: k })}>
          {k === 'home' ? (
            <span className="hb">
              <Icon id={ic} />
            </span>
          ) : (
            <Icon id={ic} />
          )}
          {t}
          {k === 'clubs' && (
            <span className="lockb" aria-label="مقفل">
              <Icon id="i-lock" />
            </span>
          )}
        </button>
      ))}
    </nav>
  );
}

/** First-launch / edit name sheet for the local guest. */
export function NameSheet({ initial, onDone, onClose }: { initial: string; onDone: (n: string) => void; onClose?: () => void }) {
  const [name, setName] = useState(initial);
  const clean = name.trim();
  return (
    <>
      <div className="dim" onClick={onClose} />
      <div className="bsheet name-sheet" role="dialog" aria-label="اسمك">
        <div className="grab" />
        <header>
          <h2>اسمك باللعبة</h2>
          {onClose && (
            <button className="ic close" aria-label="إغلاق" onClick={onClose}>
              <Icon id="i-x" />
            </button>
          )}
        </header>
        <input value={name} maxLength={16} autoFocus placeholder="مثلاً: أبو سمير" autoComplete="nickname" onChange={(e) => setName(e.target.value)} />
        <button
          className="btn primary"
          disabled={!clean}
          onClick={() => {
            saveName(clean);
            onDone(clean);
          }}
        >
          تم
        </button>
      </div>
    </>
  );
}

/** Tiny toast used by the chrome ("قريباً" etc.). */
export function useToast(): [string | null, (t: string) => void] {
  const [t, setT] = useState<string | null>(null);
  return [
    t,
    (text: string) => {
      setT(text);
      window.setTimeout(() => setT((cur) => (cur === text ? null : cur)), 2200);
    },
  ];
}
