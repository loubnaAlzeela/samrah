import { useEffect, useState } from 'react';
import type { TableListing } from '@lamma/rules';
import { BottomNav, Header, NameSheet, useToast } from '../components/Chrome.tsx';
import { Icon } from '../components/Icons.tsx';
import { Stage } from '../components/Stage.tsx';
import { num, toLatinDigits } from '../i18n.ts';
import { client, lastGame, savedName } from '../net.ts';
import { navigate } from '../router.ts';
import { VARIANT_TITLE } from '../components/RoomBar.tsx';

type Listing = TableListing & { progress?: number };
interface Row {
  roomId: string;
  metadata?: Listing;
}
const SPEED_ICON = { slow: 'i-speed1', normal: 'i-speed2', fast: 'i-speed3' } as const;
const SPEED_LABEL = { slow: 'هادئة', normal: 'عادية', fast: 'سريعة' } as const;

/** Live public tables of the selected game, via the Colyseus lobby room (layout-v3 §7). */
function useTables() {
  const [rows, setRows] = useState<Row[]>([]);
  const [ok, setOk] = useState<boolean | null>(null);
  useEffect(() => {
    let lobby: Awaited<ReturnType<typeof client.joinOrCreate>> | null = null;
    let dead = false;
    client
      .joinOrCreate('lobby')
      .then((l) => {
        if (dead) return void l.leave(true);
        lobby = l;
        setOk(true);
        l.onMessage('rooms', (r: Row[]) => setRows(r));
        l.onMessage('+', ([id, r]: [string, Row]) => setRows((cur) => cur.filter((x) => x.roomId !== id).concat(r)));
        l.onMessage('-', (id: string) => setRows((cur) => cur.filter((x) => x.roomId !== id)));
      })
      .catch(() => setOk(false));
    return () => {
      dead = true;
      void lobby?.leave(true);
    };
  }, []);
  return { rows, ok };
}

export function Tables() {
  const [toast, showToast] = useToast();
  const [codeOpen, setCodeOpen] = useState(false);
  const [code, setCode] = useState('');
  const [nameFor, setNameFor] = useState<string | null>(null);
  const { rows, ok } = useTables();
  const variant = lastGame();
  const list = rows
    .filter((r) => r.metadata && r.metadata.variant === variant && r.metadata.status !== 'finished')
    .sort((a, b) => Number(b.metadata!.joinable) - Number(a.metadata!.joinable));

  const enter = (c: string) => (savedName() ? navigate({ name: 'room', code: c }) : setNameFor(c));

  return (
    <Stage className="tabs-v3">
      <Header onEditName={() => setNameFor('')} toast={showToast} />
      <div className="lhead">
        <button className="ic code-btn" aria-label="ادخل بكود غرفة" onClick={() => setCodeOpen(true)}>
          #
        </button>
        <h1>لائحة {VARIANT_TITLE[variant]}</h1>
        <button className="ic close" aria-label="إغلاق" onClick={() => navigate({ name: 'home' })}>
          <Icon id="i-x" />
        </button>
      </div>
      <div className="rows">
        {ok === false && <p className="empty-note">تعذّر الاتصال بسيرفر اللعب</p>}
        {ok && list.length === 0 && <p className="empty-note">ما في طاولات عامة هلق. جرّب «العب الآن» من الرئيسية.</p>}
        {list.map((r) => {
          const m = r.metadata!;
          const free = m.status === 'waiting' ? m.seats.filter((s) => !s).length : m.seats.filter((s) => s?.bot).length;
          const Row = m.joinable ? 'button' : 'div';
          return (
            <Row
              key={r.roomId}
              className={`row ${m.joinable ? '' : 'full'}`}
              {...(m.joinable ? { onClick: () => enter(m.code), 'aria-label': `ادخل، ${free} مقاعد` } : { 'aria-disabled': true })}
            >
              <div className="meta">
                <div className="icons">
                  <span title={`السرعة: ${SPEED_LABEL[m.settings.speed]}`}>
                    <Icon id={SPEED_ICON[m.settings.speed]} className="fill" />
                  </span>
                  <span className="tgt num">{num(m.settings.target)}</span>
                  {m.settings.chat && <Icon id="i-chat" />}
                  {m.settings.voice && <Icon id="i-mic" />}
                  {m.settings.kick && <Icon id="i-userx" />}
                </div>
                {m.joinable ? (
                  <span className="status-pill open">
                    {m.status === 'waiting' ? 'لعبة جديدة' : 'جارية'} · <span className="num">{num(free)}</span> {m.status === 'waiting' ? 'مقاعد' : 'مقاعد كمبيوتر'}
                  </span>
                ) : (
                  <div className="prog" role="img" aria-label={`ممتلئة، اللعبة ${m.progress ?? 0}%`}>
                    <i style={{ width: `${m.progress ?? 0}%` }} />
                    <span>لعبة ممتلئة</span>
                  </div>
                )}
              </div>
              <div className="circles" dir="ltr">
                {m.seats.map((s, i) =>
                  s ? (
                    <i key={i} className={s.bot ? 'b' : ''} aria-label={s.bot ? 'كمبيوتر' : s.name}>
                      {s.bot ? <Icon id="i-bot" /> : s.name.slice(0, 1)}
                    </i>
                  ) : (
                    <i key={i} className="e" aria-label="مقعد فارغ">
                      +
                    </i>
                  ),
                )}
              </div>
            </Row>
          );
        })}
      </div>
      <BottomNav on="home" />

      {codeOpen && (
        <>
          <div className="dim" onClick={() => setCodeOpen(false)} />
          <div className="bsheet name-sheet" role="dialog" aria-label="ادخل بكود">
            <div className="grab" />
            <header>
              <h2>عندك كود غرفة؟</h2>
              <button className="ic close" aria-label="إغلاق" onClick={() => setCodeOpen(false)}>
                <Icon id="i-x" />
              </button>
            </header>
            <input
              className="code-input"
              dir="ltr"
              autoCapitalize="characters"
              autoCorrect="off"
              spellCheck={false}
              maxLength={6}
              value={code}
              placeholder="ABC123"
              onChange={(e) => setCode(toLatinDigits(e.target.value).toUpperCase())}
            />
            <button
              className="btn"
              onClick={() => {
                const c = code.replace(/[^A-Z0-9]/g, '');
                if (c.length !== 6) return showToast('الكود 6 خانات');
                setCodeOpen(false);
                enter(c);
              }}
            >
              ادخل
            </button>
          </div>
        </>
      )}
      {nameFor !== null && (
        <NameSheet
          initial={savedName()}
          onClose={() => setNameFor(null)}
          onDone={() => {
            const c = nameFor;
            setNameFor(null);
            if (c) navigate({ name: 'room', code: c });
          }}
        />
      )}
      {toast && <div className="stage-toast">{toast}</div>}
    </Stage>
  );
}
