import { useEffect, useState } from 'react';
import type { RoomSettings, Variant } from '@lamma/rules';
import { BottomNav, Header, NameSheet, useToast } from '../components/Chrome.tsx';
import { Icon } from '../components/Icons.tsx';
import { NewGameSheet } from '../components/NewGameSheet.tsx';
import { Stage } from '../components/Stage.tsx';
import { SuitIcon } from '../components/Card.tsx';
import { errorText } from '../i18n.ts';
import { RoomConn, handOff, lastGame, saveLastGame, savedName } from '../net.ts';
import { navigate } from '../router.ts';
import { playNow } from '../matchmaking.ts';

export type GameId = Variant | 'trix' | 'baloot';
export const GAMES: { id: GameId; name: string; desc: string; ready: boolean }[] = [
  { id: 'tarneeb', name: 'طرنيب', desc: '4 لاعبين · فريقين', ready: true },
  { id: 'syrian41', name: 'طرنيب سوري 41', desc: '4 لاعبين · كل واحد لحاله', ready: true },
  { id: 'trix', name: 'تركس', desc: 'قريباً', ready: false },
  { id: 'baloot', name: 'بلوت', desc: 'قريباً', ready: false },
];

const SLIDES = [
  { title: 'طرنيب سوري 41', text: 'صار متاح. العبها مع أصحابك الليلة' },
  { title: 'العب الآن', text: 'طاولة جاهزة خلال ثواني، والكمبيوتر بيكمّل الناقص' },
  { title: 'ادعُ أصحابك', text: 'افتح لعبة خاصة وابعت الرابط على واتساب' },
];

function MiniFan() {
  const cards: [string, 'H' | 'S' | 'D', number][] = [
    ['A', 'H', -22],
    ['K', 'S', 0],
    ['Q', 'D', 22],
  ];
  return (
    <div className="mfan" aria-hidden="true">
      {cards.map(([r, s, a]) => (
        <span key={r} className={`mc suit-${s}`} style={{ transform: `rotate(${a}deg)` }}>
          {r}
          <SuitIcon suit={s} />
        </span>
      ))}
    </div>
  );
}

export function Home() {
  const [toast, showToast] = useToast();
  const [slide, setSlide] = useState(0);
  const [gi, setGi] = useState(() => GAMES.findIndex((g) => g.id === lastGame()));
  const [sheet, setSheet] = useState<null | 'create' | 'name'>(savedName() ? null : 'name');
  const [afterName, setAfterName] = useState<null | (() => void)>(null);
  const [busy, setBusy] = useState(false);
  const game = GAMES[gi];

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const t = setInterval(() => setSlide((s) => (s + 1) % SLIDES.length), 5000);
    return () => clearInterval(t);
  }, []);

  const pick = (d: number) => {
    const n = (gi + d + GAMES.length) % GAMES.length;
    setGi(n);
    if (GAMES[n].ready) saveLastGame(GAMES[n].id as Variant);
  };
  /** Run `fn` once we have a name (asks for it first if needed). */
  const withName = (fn: () => void) => {
    if (savedName()) return fn();
    setAfterName(() => fn);
    setSheet('name');
  };
  const needReady = (fn: () => void) => (game.ready ? withName(fn) : showToast(`${game.name} قريباً`));

  async function create(settings: RoomSettings) {
    setBusy(true);
    try {
      const conn = await RoomConn.create(game.id as Variant, settings, savedName());
      handOff(conn);
      navigate({ name: 'room', code: conn.code });
    } catch {
      showToast(errorText('network'));
    } finally {
      setBusy(false);
    }
  }

  async function friendly() {
    setBusy(true);
    try {
      const conn = await playNow(game.id as Variant, savedName());
      handOff(conn);
      navigate({ name: 'room', code: conn.code });
    } catch {
      showToast(errorText('network'));
    } finally {
      setBusy(false);
    }
  }

  async function invite() {
    const url = window.location.origin;
    try {
      if (navigator.share) await navigator.share({ title: 'لَمّة', text: 'تعال نلعب ورق على لَمّة', url });
      else {
        await navigator.clipboard.writeText(url);
        showToast('انسخ الرابط ✓');
      }
    } catch {
      /* cancelled */
    }
  }

  return (
    <Stage className="home-v3">
      <Header onEditName={() => setSheet('name')} toast={showToast} />

      <div className="banner-c" role="region" aria-roledescription="carousel" aria-label="إعلانات">
        <svg className="pat" aria-hidden="true">
          <use href="#star8" />
        </svg>
        <div className="txt" aria-live="polite">
          <h3>{SLIDES[slide].title}</h3>
          <p>{SLIDES[slide].text}</p>
        </div>
        <button className="banner-hit" aria-label="الإعلان التالي" onClick={() => setSlide((s) => (s + 1) % SLIDES.length)} />
      </div>
      <div className="dots dots-banner" aria-hidden="true">
        {SLIDES.map((_, i) => (
          <i key={i} className={i === slide ? 'on' : ''} />
        ))}
      </div>

      <div className="gpick">
        <MiniFan />
        <h2>{game.name}</h2>
        <p>{game.ready ? game.desc : 'قريباً'}</p>
        <button className="ic arr arr-prev" aria-label="اللعبة السابقة" onClick={() => pick(-1)}>
          <Icon id="i-back" />
        </button>
        <button className="ic arr arr-next" aria-label="اللعبة التالية" onClick={() => pick(1)}>
          <Icon id="i-chev" />
        </button>
      </div>

      <div className={`modes ${game.ready ? '' : 'soon'}`}>
        <button className="mode side side-right" disabled={busy} onClick={() => needReady(() => setSheet('create'))}>
          <span className="mi">
            <Icon id="i-plus2" />
          </span>
          <h3>إنشاء لعبة</h3>
        </button>
        <button className="mode mid" disabled={busy} onClick={() => needReady(friendly)}>
          <span className="play">
            <Icon id="i-play" className="fill" />
          </span>
          <h3>لعبة ودية</h3>
          <span className="cta">{busy ? 'لحظة…' : 'العب الآن'}</span>
        </button>
        <button className="mode side side-left" onClick={() => (game.ready ? navigate({ name: 'tables' }) : showToast(`${game.name} قريباً`))}>
          <span className="mi">
            <Icon id="i-list" />
          </span>
          <h3>الألعاب العامة</h3>
        </button>
      </div>
      <div className="dots dots-modes" aria-hidden="true">
        <i />
        <i className="on" />
        <i />
      </div>

      <div className="sideic side-r">
        <button className="ic" aria-label="القوانين" onClick={() => navigate({ name: 'games' })}>
          <Icon id="i-book" />
        </button>
        القوانين
      </div>
      <div className="sideic side-l">
        <button className="ic" aria-label="الترتيب" onClick={() => showToast('الترتيب قريباً')}>
          <Icon id="i-trophy" />
        </button>
        الترتيب
      </div>
      <button className="invite-fab" aria-label="ادعُ صديق" onClick={invite}>
        <Icon id="i-invite" />
        ادعُ
      </button>

      <BottomNav on="home" />

      {sheet === 'create' && game.ready && <NewGameSheet variant={game.id as Variant} mode="create" onClose={() => setSheet(null)} onSubmit={create} />}
      {sheet === 'name' && (
        <NameSheet
          initial={savedName()}
          onClose={savedName() ? () => setSheet(null) : undefined}
          onDone={() => {
            setSheet(null);
            const f = afterName;
            setAfterName(null);
            f?.();
          }}
        />
      )}
      {toast && (
        <div className="stage-toast" role="status">
          {toast}
        </div>
      )}
    </Stage>
  );
}
