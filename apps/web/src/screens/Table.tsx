import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { type PlayerView, type RoomView, type Seat, type Suit, suitOf, teamOf, trickWinner } from '@lamma/rules';
import { PlayingCard, SuitIcon, SuitLabel } from '../components/Card.tsx';
import { Icon } from '../components/Icons.tsx';
import { Hand } from '../components/Hand.tsx';
import { Num } from '../components/Num.tsx';
import { Stage } from '../components/Stage.tsx';
import { NOTE_TEXT, SUIT_NAME, num } from '../i18n.ts';
import type { RoomConn } from '../net.ts';
import { KickConfirm, RoomBar } from '../components/RoomBar.tsx';
import { NewGameSheet } from '../components/NewGameSheet.tsx';
import { ChatBubbles, ChatSheet } from '../components/Chat.tsx';
import { navigate } from '../router.ts';
import { playSound } from '../sound.ts';

/** Physical positions relative to the viewer (0 = me at the bottom, 1 = right = next in turn order). */
const POS = ['bottom', 'right', 'top', 'left'] as const;
const VARIANT_NAME = { tarneeb: 'طرنيب', syrian41: 'طرنيب سوري' } as const;

/** Stable tilt for pile layers (seeded by index so it never jitters on re-render). */
const PILE_TILT = [0, -7, 5, -3, 8, -5];

function Pile({ count, label, where }: { count: number; label: string; where: 'us' | 'them' }) {
  const layers = Math.min(count, 6);
  return (
    <div className={`pile pile-${where}`} aria-label={`${label} ${count}`}>
      <div className="pile-stack" aria-hidden="true">
        {Array.from({ length: layers }, (_, i) => (
          <i key={i} style={{ transform: `rotate(${PILE_TILT[i]}deg) translateY(${-i}px)` }} />
        ))}
      </div>
      <span className="pile-label">
        {label} <span className="num">{num(count)}</span>
      </span>
    </div>
  );
}

/** Decorative fan of 5 card backs behind an opponent's avatar (fixed count, not the real hand size). */
function Fan() {
  return (
    <span className="fan" aria-hidden="true">
      {[-36, -18, 0, 18, 36].map((a) => (
        <i key={a} style={{ transform: `rotate(${a}deg)` }} />
      ))}
    </span>
  );
}

/** Avatar with the server-driven turn ring (--p = fraction of time left). */
function Avatar({ letter, turn, frac }: { letter: string; turn: boolean; frac: number }) {
  return (
    <span className="avatar-wrap" aria-hidden="true">
      {turn && <span className="turn-ring" style={{ ['--p' as string]: frac }} />}
      <span className="avatar">{letter}</span>
    </span>
  );
}

function useCountdown(msLeft: number | null, stamp: string) {
  const [left, setLeft] = useState(msLeft);
  useEffect(() => {
    if (msLeft === null) return setLeft(null);
    const t0 = Date.now();
    setLeft(msLeft);
    const iv = setInterval(() => setLeft(Math.max(0, msLeft - (Date.now() - t0))), 500);
    return () => clearInterval(iv);
  }, [msLeft, stamp]);
  return left;
}

/**
 * Turn timer driven by the server: the view carries turnDeadline + serverNow (both server clock), so the
 * remaining time is computed without trusting the device clock. Returns {left ms, frac 0..1}.
 */
function useTurnClock(v: RoomView) {
  const total = useRef(1);
  const [now, setNow] = useState(() => Date.now());
  const receivedAt = useMemo(() => Date.now(), [v]);
  const msAtReceive = v.turnDeadline === null ? null : Math.max(0, v.turnDeadline - v.serverNow);
  // the first time we see a deadline, remember its full length for the ring fraction
  const deadlineKey = v.turnDeadline;
  const seenKey = useRef<number | null>(null);
  if (deadlineKey !== seenKey.current) {
    seenKey.current = deadlineKey;
    total.current = Math.max(1, msAtReceive ?? 1);
  }
  useEffect(() => {
    if (msAtReceive === null) return;
    const iv = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(iv);
  }, [msAtReceive]);
  if (msAtReceive === null) return null;
  const left = Math.max(0, msAtReceive - Math.max(0, now - receivedAt)); // `now` may predate this message
  return { left, frac: Math.min(1, left / total.current) };
}

/**
 * Ambient sounds driven purely off server-state transitions (deal, a card lands, a trick is won, the final
 * 5-second warning, game over) — so every viewer hears the same thing at the same moment, no client-only
 * guessing. Your own bid/pass/card-play tap plays its sound immediately at the click site instead (snappier).
 */
function useGameSounds(v: RoomView, clock: { left: number; frac: number } | null) {
  const prev = useRef<{ hand: number | null; trickLen: number; phase: string | null; status: string | null; warnedKey: string | null }>({
    hand: null,
    trickLen: 0,
    phase: null,
    status: null,
    warnedKey: null,
  });
  useEffect(() => {
    const g = v.game as PlayerView | null; // trix rooms never reach this screen (Room.tsx)
    const p = prev.current;
    if (g) {
      if (p.hand !== g.handNo) playSound('deal');
      if (g.trick.length > p.trickLen) playSound('cardPlay');
      if (p.phase !== 'trickDone' && g.phase === 'trickDone') playSound('trickWin');
      if (v.mySeat !== null && g.turn === v.mySeat && ['bidding', 'trump', 'playing'].includes(g.phase) && clock) {
        const key = `${g.handNo}|${g.phase}|${g.bidLog.length}|${g.trick.length}`;
        if (clock.left <= 5000 && clock.left > 0 && p.warnedKey !== key) {
          playSound('timerWarning');
          p.warnedKey = key;
        }
      }
      p.hand = g.handNo;
      p.trickLen = g.trick.length;
      p.phase = g.phase;
      if (p.status !== 'finished' && v.status === 'finished' && v.mySeat !== null) {
        const us = teamOf(v.mySeat as Seat);
        playSound(g.winner === us ? 'gameWin' : 'gameLose');
      }
    }
    p.status = v.status;
  }, [v, clock]);
}

export function Table({ v, conn, toast }: { v: RoomView; conn: RoomConn; toast: (t: string) => void }) {
  const clock = useTurnClock(v);
  const [sheet, setSheet] = useState(false);
  const [kick, setKick] = useState<Seat | null>(null);
  const [chatOpen, setChatOpen] = useState(false);
  const meAutoEarly = v.mySeat !== null && !!v.seats[v.mySeat]?.auto;
  useEffect(() => {
    if (!meAutoEarly) return;
    // the player touches the screen -> they are back; the server hands the seat back from the autopilot
    const on = () => conn.send('back');
    window.addEventListener('pointerdown', on, { once: true });
    return () => window.removeEventListener('pointerdown', on);
  }, [meAutoEarly, conn]);
  // disconnected players (hold countdown) - hooks must run before any early return
  const awayFirst = v.seats.find((s) => s && !s.connected && !s.auto) ?? null;
  const awayLeft = useCountdown(awayFirst?.heldMsLeft ?? null, JSON.stringify(v.seats));
  useGameSounds(v, clock);
  const g = v.game as PlayerView | null; // trix rooms never reach this screen (Room.tsx)
  if (!g || v.mySeat === null) {
    return (
      <main className="screen center">
        <p className="muted">{v.pending ? 'بتاخد مقعد الكمبيوتر بنهاية اللمّة الحالية…' : 'اللعبة شغالة بهالغرفة وما عندك مقعد فيها.'}</p>
      </main>
    );
  }
  const me = v.mySeat;
  const rel = (s: number) => (s - me + 4) % 4;
  const seatAt = (r: number) => ((me + r) % 4) as Seat;
  const us = teamOf(me);
  const them = (1 - us) as 0 | 1;
  const name = (s: number) => v.seats[s]?.name ?? '؟';
  const myTurn = g.turn === me;

  const lastBid = (s: number) => {
    for (let i = g.bidLog.length - 1; i >= 0; i--) if (g.bidLog[i].seat === s) return g.bidLog[i].bid;
    return null;
  };

  const syrian = g.variant === 'syrian41';
  /** Syrian 41: per-player score, bid and tricks (individual scoring) */
  const seatLine = (s: number) =>
    syrian ? (
      <span className="seat-score">
        <Num value={g.seatScores[s]} />
        {g.seatBids[s] !== null && (
          <>
            {' '}
            · طلب <span className="num">{num(g.seatBids[s]!)}</span> أكل <span className="num">{num(g.tricks[s])}</span>
          </>
        )}
      </span>
    ) : null;

  const acting = ['bidding', 'trump', 'playing'].includes(g.phase) && v.status === 'playing';
  const meAuto = !!v.seats[me]?.auto;
  const winnerSeat = g.phase === 'trickDone' && g.trick.length === 4 ? trickWinner(g.trick, g.trump) : null;
  const pileUs = g.tricks[me] + g.tricks[(me + 2) % 4];
  const pileThem = g.tricks[(me + 1) % 4] + g.tricks[(me + 3) % 4];
  const frac = acting && clock ? clock.frac : 0;
  const panelOpen = myTurn && (g.phase === 'bidding' || g.phase === 'trump');
  const iPlayedThisTrick = g.trick.some((p) => p.seat === me);
  // host may ask to remove a player any time; the server applies it when the current hand ends
  const kickWindow = v.isOwner && v.settings.kick;

  // score box: top (partner) + bottom (me) = us, right + left = them; Syrian: each cell = that seat's own score
  const cell = (r: number) => (syrian ? g.seatScores[seatAt(r)] : r % 2 === 0 ? g.teamScores[us] : g.teamScores[them]);
  const scoreLabel = syrian
    ? [0, 1, 2, 3].map((r) => `${name(seatAt(r))} ${g.seatScores[seatAt(r)]}`).join('، ') + `، الهدف ${g.target}`
    : `لنا ${g.teamScores[us]}، لهم ${g.teamScores[them]}، الهدف ${g.target}`;

  return (
    <Stage className="game">
      <RoomBar v={v} onSettings={() => setSheet(true)} toast={toast} />

      <div className="scorebox" role="img" aria-label={scoreLabel}>
        <span className="c-top us">
          <Num value={cell(2)} />
        </span>
        <span className="c-left">
          <Num value={cell(3)} />
        </span>
        <span className="c-mid num">{num(g.target)}</span>
        <span className="c-right">
          <Num value={cell(1)} />
        </span>
        <span className="c-bottom us">
          <Num value={cell(0)} />
        </span>
      </div>

      <div className="info-chips">
        {g.trump && (
          <span className="chip trump-chip">
            الطرنيب <SuitLabel suit={g.trump} />
          </span>
        )}
        {syrian && g.revealed && (
          <span className="chip revealed">
            الورقة المقلوبة <PlayingCard card={g.revealed} width={30} className="mini-card" />
          </span>
        )}
        {!syrian && g.highBid && (
          <span className="chip">
            {g.phase === 'bidding' ? 'أعلى طلب' : 'الطلب'}: {name(g.highBid.seat)} <b className="num">{num(g.highBid.value)}</b>
          </span>
        )}
      </div>

      <section className="table play-table" aria-label="الطاولة" />

      {awayFirst && v.status === 'playing' && (
        <div className="pill-banner away-banner" role="status">
          بانتظار {awayFirst.name}… <span className="num">{num(Math.ceil((awayLeft ?? 0) / 1000))}</span> ث، بعدها يلعب عنه الكمبيوتر
        </div>
      )}

      <Pile count={pileUs} label="لمّتنا" where="us" />
      <Pile count={pileThem} label="لمّتهم" where="them" />

      {[1, 2, 3].map((r) => {
        const s = seatAt(r);
        const b = lastBid(s);
        const seat = v.seats[s];
        const isTurn = g.turn === s && acting;
        return (
          <div key={s} className={`player pos-${POS[r]} ${isTurn ? 'turn' : ''}`}>
            {g.handCounts[s] > 0 && <Fan />}
            {kickWindow && seat && !seat.bot ? (
              <button className="seat-hit" aria-label={`إخراج ${name(s)}`} onClick={() => setKick(s)}>
                <Avatar letter={name(s).slice(0, 1)} turn={isTurn} frac={frac} />
              </button>
            ) : (
              <Avatar letter={name(s).slice(0, 1)} turn={isTurn} frac={frac} />
            )}
            <span className="player-name">
              {name(s)}
              {seat && !seat.connected && !seat.auto && <span className="away"> (انقطع)</span>}
              {g.dealer === s && <span className="dealer-tag">موزّع</span>}
            </span>
            {v.kickQueued.includes(s) ? (
              <span className="auto-badge">بيطلع بنهاية الجولة</span>
            ) : seat?.bot ? (
              <span className="auto-badge bot-badge">كمبيوتر</span>
            ) : seat?.auto ? (
              <span className="auto-badge">يلعب عنه الكمبيوتر</span>
            ) : (
              <span className="player-meta">
                {!syrian && g.phase === 'bidding' && b !== null ? b === 'pass' ? 'تمرير' : <span className="bidtag num">{num(b)}</span> : null}
                {seatLine(s)}
              </span>
            )}
          </div>
        );
      })}

      {v.settings.chat && <ChatBubbles v={v} chat={conn.chat} seatAt={(r) => seatAt(r)} />}

      <div className="trick" aria-label="الورق على الطاولة">
        {g.phase === 'playing' && myTurn && !iPlayedThisTrick && <span className="my-slot" aria-hidden="true" />}
        {g.trick.map((p) => (
          <PlayingCard key={p.card} card={p.card} width={56} className={`trick-card at-${POS[rel(p.seat)]} ${winnerSeat === p.seat ? 'winning' : ''}`} />
        ))}
      </div>

      {!panelOpen && (
        <TurnBanner g={g} myTurn={myTurn} name={name} winnerSeat={winnerSeat} secondsLeft={acting && clock ? Math.ceil(clock.left / 1000) : null} />
      )}

      {myTurn && g.phase === 'bidding' && (
        <ActionPanel title={syrian ? <TurnText g={g} myTurn name={name} winnerSeat={null} /> : 'اختر الطلبة'} secondsLeft={clock ? Math.ceil(clock.left / 1000) : null}>
          <BidPanel
            g={g}
            onBid={(value) => {
              playSound(value === 'pass' ? 'pass' : 'bid');
              conn.send('bid', { value });
            }}
          />
        </ActionPanel>
      )}
      {myTurn && g.phase === 'trump' && (
        <ActionPanel title="اختار الطرنيب" secondsLeft={clock ? Math.ceil(clock.left / 1000) : null}>
          <TrumpPanel onPick={(suit) => conn.send('trump', { suit })} />
        </ActionPanel>
      )}

      <Hand cards={g.myHand} trump={g.trump} legal={myTurn && g.phase === 'playing' ? g.legal : null} onPlay={(card) => conn.send('play', { card })} />

      <div className="me-panel" />
      {v.settings.chat && (
        <button className="chatbtn" aria-label="الدردشة" onClick={() => setChatOpen(true)}>
          <Icon id="i-chat" />
        </button>
      )}
      <div className="me-row">
        <Avatar letter={name(me).slice(0, 1)} turn={myTurn && acting && !meAuto} frac={frac} />
        <span className="player-name">
          {name(me)}
          {g.dealer === me && <span className="dealer-tag">موزّع</span>}
        </span>
      </div>
      {syrian && <div className="me-line">{seatLine(me)}</div>}
      {meAuto && (
        <div className="auto-me" role="alert">
          <span>الكمبيوتر يلعب عنك</span>
          <button className="btn small-btn" onClick={() => conn.send('back')}>
            أنا هون، رجّعني
          </button>
        </div>
      )}

      {g.phase === 'handOver' && g.lastResult && <HandResult g={g} name={name} us={us} />}
      {kick !== null && v.seats[kick] && (
        <KickConfirm
          name={v.seats[kick]!.name}
          queued={v.kickQueued.includes(kick)}
          during={v.status === 'playing' && g.phase !== 'handOver'}
          onNo={() => setKick(null)}
          onYes={() => {
            conn.send('kick', { seat: kick });
            setKick(null);
          }}
        />
      )}
      {sheet && <NewGameSheet variant={v.variant} initial={v.settings} code={v.code} mode="view" onClose={() => setSheet(false)} />}
      {chatOpen && <ChatSheet v={v} chat={conn.chat} onSend={(text) => conn.send('chat', { text })} onClose={() => setChatOpen(false)} />}
      {v.status === 'finished' && <GameOver g={g} us={us} onRematch={() => conn.send('rematch')} />}
    </Stage>
  );
}

function ActionPanel({ title, secondsLeft, children }: { title: ReactNode; secondsLeft: number | null; children: ReactNode }) {
  return (
    <div className="action-panel" role="status" aria-live="polite">
      <h2 className="panel-title">{title}</h2>
      {secondsLeft !== null && (
        <p className="panel-sub">
          <span className="num">{num(secondsLeft)}</span> ث
        </p>
      )}
      <hr />
      {children}
    </div>
  );
}

function TurnText({ g, myTurn, name, winnerSeat }: { g: PlayerView; myTurn: boolean; name: (s: number) => string; winnerSeat: Seat | null }) {
  if (g.phase === 'trickDone' && winnerSeat !== null) return <>أكلها {winnerSeat === g.mySeat ? 'أنت' : name(winnerSeat)}</>;
  if (g.phase === 'bidding')
    return <>{myTurn ? (g.variant === 'syrian41' ? 'دورك · كم أكلة بتجيب لحالك؟' : 'دورك · اطلب أو مرّر') : `${name(g.turn)} عم يطلب…`}</>;
  if (g.phase === 'trump') return <>{myTurn ? 'اختار الطرنيب' : `${name(g.turn)} عم يختار الطرنيب…`}</>;
  if (g.phase === 'playing') {
    if (myTurn) {
      const led: Suit | null = g.trick.length ? suitOf(g.trick[0].card) : null;
      const follows = led && g.legal.every((c) => suitOf(c) === led);
      return follows ? (
        <>
          دورك · العب <SuitLabel suit={led!} />
        </>
      ) : (
        <>دورك · العب أي ورقة</>
      );
    }
    return <>دور {name(g.turn)}</>;
  }
  return null;
}

function TurnBanner({
  g,
  myTurn,
  name,
  winnerSeat,
  secondsLeft,
}: {
  g: PlayerView;
  myTurn: boolean;
  name: (s: number) => string;
  winnerSeat: Seat | null;
  secondsLeft: number | null;
}) {
  const text = <TurnText g={g} myTurn={myTurn} name={name} winnerSeat={winnerSeat} />;
  if (!['trickDone', 'bidding', 'trump', 'playing'].includes(g.phase) || (g.phase === 'trickDone' && winnerSeat === null)) return null;
  return (
    <div className="pill-banner turn-banner" role="status" aria-live="polite">
      {text}
      {secondsLeft !== null && g.phase !== 'trickDone' && (
        <span className="turn-secs">
          · <span className="num">{num(secondsLeft)}</span> ث
        </span>
      )}
    </div>
  );
}

/** All bids are always drawn (7..13, or 2..13 in Syrian); the ones below the minimum are disabled (display only). */
function BidPanel({ g, onBid }: { g: PlayerView; onBid: (v: number | 'pass') => void }) {
  const syrian = g.variant === 'syrian41';
  const first = syrian ? 2 : 7;
  const min = g.minBid ?? first;
  const options = [];
  for (let b = first; b <= 13; b++) options.push(b);
  return (
    <div role="group" aria-label="المزايدة">
      <div className="bid-grid">
        {options.map((b) => (
          <button key={b} className="bid-btn" aria-label={`اطلب ${b}`} disabled={b < min} onClick={() => onBid(b)}>
            <span className="num">{num(b)}</span>
            {b === 13 && !syrian && <small>كبوت</small>}
          </button>
        ))}
      </div>
      {!syrian && (
        <button className="btn pass-btn" onClick={() => onBid('pass')}>
          تمرير
        </button>
      )}
    </div>
  );
}

function TrumpPanel({ onPick }: { onPick: (s: Suit) => void }) {
  return (
    <div className="trump-grid" role="group" aria-label="اختيار الطرنيب">
      {(['H', 'D', 'S', 'C'] as Suit[]).map((s) => (
        <button key={s} className="trump-btn" aria-label={SUIT_NAME[s]} onClick={() => onPick(s)}>
          <span className="suitchip">
            <SuitIcon suit={s} />
          </span>
          <span className="trump-name">{SUIT_NAME[s]}</span>
        </button>
      ))}
    </div>
  );
}

function HandResult({ g, name, us }: { g: PlayerView; name: (s: number) => string; us: 0 | 1 }) {
  const r = g.lastResult!;
  return (
    <div className="table-panel soft">
      <h2 className="sheet-title">{NOTE_TEXT[r.note] ?? ''}</h2>
      {r.kind === 'scored' && r.bidder !== undefined && (
        <p>
          {name(r.bidder)} طلب <span className="num">{num(r.bid!)}</span> وفريقه جاب <span className="num">{num(r.bidderTricks!)}</span>
        </p>
      )}
      {r.kind === 'scored' && r.note === 'syrian' && (
        <ul className="seat-deltas">
          {[0, 1, 2, 3].map((s) => (
            <li key={s}>
              {name(s)}: طلب <span className="num">{num(g.seatBids[s] ?? 0)}</span> أكل <span className="num">{num(g.tricks[s])}</span> ←{' '}
              <Num value={r.seatDelta[s]} plus />
            </li>
          ))}
        </ul>
      )}
      {r.kind === 'scored' && (
        <p className="result-deltas">
          لنا <Num value={r.teamDelta[us]} plus /> · لهم <Num value={r.teamDelta[1 - us]} plus />
        </p>
      )}
      <p className="muted small">الجولة الجاية بعد لحظات…</p>
    </div>
  );
}

function GameOver({ g, us, onRematch }: { g: PlayerView; us: 0 | 1; onRematch: () => void }) {
  const won = g.winner === us;
  return (
    <>
      <div className="stage-scrim" />
      <div className="table-panel">
        <h2 className="sheet-title">{won ? 'فزنا!' : 'فازوا هالمرة'}</h2>
        <p className="result-deltas">
          لنا <Num value={g.teamScores[us]} /> · لهم <Num value={g.teamScores[1 - us]} />
        </p>
        <button className="btn primary" onClick={onRematch}>
          مباراة جديدة بنفس الطاولة
        </button>
        <button className="btn" onClick={() => navigate({ name: 'home' })}>
          للصفحة الرئيسية
        </button>
      </div>
    </>
  );
}
