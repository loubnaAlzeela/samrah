import { useState } from 'react';
import type { RoomView, Seat } from '@lamma/rules';
import { Icon } from '../components/Icons.tsx';
import { NewGameSheet } from '../components/NewGameSheet.tsx';
import { KickConfirm, RoomBar, shareInvite, whatsappUrl } from '../components/RoomBar.tsx';
import { Stage } from '../components/Stage.tsx';
import { num } from '../i18n.ts';
import type { RoomConn } from '../net.ts';

const POS = ['bottom', 'right', 'top', 'left'] as const;

/**
 * Room before the start (layout-v3 §4 + §5): table with the other three seats around it, the centre menu
 * (start / WhatsApp / settings), partner picker for the host, and the host's kick action.
 */
export function Waiting({ v, conn, toast }: { v: RoomView; conn: RoomConn; toast: (t: string) => void }) {
  const [sheet, setSheet] = useState(false);
  const [picker, setPicker] = useState(false);
  const [kick, setKick] = useState<Seat | null>(null);
  const me = (v.mySeat ?? 0) as Seat;
  const seatAt = (r: number) => ((me + r) % 4) as Seat;
  const others = [1, 2, 3].map(seatAt).filter((s) => v.seats[s]);
  const iChoose = v.partnerChooser !== null && v.partnerChooser === v.mySeat;

  function start() {
    // the host first picks a partner when other players are already seated
    if (iChoose && others.length > 0) setPicker(true);
    else conn.send('start');
  }

  return (
    <Stage className="room-v3">
      <RoomBar v={v} onSettings={() => setSheet(true)} toast={toast} />

      <div className="scorebox" role="img" aria-label={`النقاط، الهدف ${v.target}`}>
        {['c-top us', 'c-left', 'c-right', 'c-bottom us'].map((c) => (
          <span key={c} className={`${c} num`}>
            0
          </span>
        ))}
        <span className="c-mid num">{num(v.target)}</span>
      </div>

      <section className="table play-table" aria-label="الطاولة" />

      {[1, 2, 3].map((r) => {
        const s = seatAt(r);
        const info = v.seats[s];
        const canKick = !!info && v.isOwner && v.settings.kick && !info.bot;
        return (
          <div key={s} className={`player pos-${POS[r]} ${picker ? 'dimmed' : ''}`}>
            {info ? (
              <button className="seat-hit" disabled={!canKick} aria-label={canKick ? `إخراج ${info.name}` : info.name} onClick={() => canKick && setKick(s)}>
                <span className="avatar-wrap" aria-hidden="true">
                  <span className="avatar">{info.name.slice(0, 1)}</span>
                </span>
                <span className="player-name">
                  {info.name}
                  {v.ownerSeat === s && <span className="dealer-tag">المضيف</span>}
                </span>
                {!info.connected && <span className="player-meta">غير متصل</span>}
              </button>
            ) : (
              <button className="seat-hit" aria-label="مقعد فارغ، ادعُ صديق" onClick={async () => { const t = await shareInvite(v); if (t) toast(t); }}>
                <span className="avatar-wrap" aria-hidden="true">
                  <span className="avatar empty">
                    <Icon id="i-bot" />
                  </span>
                </span>
                <span className="player-name">مقعد فارغ</span>
              </button>
            )}
          </div>
        );
      })}

      <div className="action-panel room-menu-panel">
        {v.isOwner ? (
          <button className="btn primary" onClick={start}>
            <Icon id="i-play" className="fill" />
            بدء اللعبة
          </button>
        ) : (
          <p className="wait-host">بانتظار المضيف يبدأ اللعبة</p>
        )}
        <a className="btn" href={whatsappUrl(v)} target="_blank" rel="noopener noreferrer">
          <Icon id="i-chatwa" />
          دعوة على واتساب
        </a>
        <button className="btn" onClick={() => setSheet(true)}>
          <Icon id="i-gear" />
          إعدادات اللعبة
        </button>
      </div>

      <div className="me-panel" />
      <div className="me-row">
        <span className="avatar-wrap" aria-hidden="true">
          <span className="avatar">{(v.seats[me]?.name ?? '؟').slice(0, 1)}</span>
        </span>
        <span className="player-name">
          {v.seats[me]?.name ?? ''}
          {v.ownerSeat === me && <span className="dealer-tag">المضيف</span>}
        </span>
      </div>

      {picker && (
        <>
          <div className="stage-scrim light" onClick={() => setPicker(false)} />
          <div className="pick" role="dialog" aria-label="اختيار الشريك">
            <h2>الرجاء اختيار شريكك</h2>
            <hr />
            <div className="opts">
              {others.map((s) => (
                <button
                  key={s}
                  onClick={() => {
                    conn.send('partner', { seat: s });
                    conn.send('start');
                    setPicker(false);
                  }}
                >
                  <span className="pa">{v.seats[s]!.name.slice(0, 1)}</span>
                  <span>{v.seats[s]!.name}</span>
                </button>
              ))}
            </div>
          </div>
        </>
      )}

      {kick !== null && v.seats[kick] && (
        <KickConfirm
          name={v.seats[kick]!.name}
          onNo={() => setKick(null)}
          onYes={() => {
            conn.send('kick', { seat: kick });
            setKick(null);
          }}
        />
      )}

      {sheet && (
        <NewGameSheet
          variant={v.variant}
          initial={v.settings}
          code={v.code}
          mode={v.isOwner ? 'edit' : 'view'}
          onClose={() => setSheet(false)}
          onSubmit={(s) => {
            conn.send('settings', s);
            setSheet(false);
          }}
        />
      )}
    </Stage>
  );
}
