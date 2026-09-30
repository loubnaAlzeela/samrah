import { useEffect, useRef, useState } from 'react';
import { CHAT_MAX_LEN, type ChatMessage, type RoomView } from '@lamma/rules';
import { isMuted, toggleMuted } from '../net.ts';
import { Icon } from './Icons.tsx';

const BUBBLE_MS = 4000;
const QUICK = ['يلا شدّ حيلك!', 'مين معه الشايب؟', 'حظ أوفر المرة الجاية', 'أحسنت!', 'صبرك علينا 😄'];

/** One bubble per seat position (top/right/left/bottom), auto-hides after 4s (layout-v3 §6). */
export function ChatBubbles({ v, chat, seatAt }: { v: RoomView; chat: ChatMessage[]; seatAt: (r: 0 | 1 | 2 | 3) => number }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(t);
  }, []);
  const posOf = (seat: number): 'bottom' | 'right' | 'top' | 'left' | null => {
    for (const r of [0, 1, 2, 3] as const) if (seatAt(r) === seat) return (['bottom', 'right', 'top', 'left'] as const)[r];
    return null;
  };
  // most recent message per seat, still within the display window, from a non-muted player
  const latest = new Map<number, ChatMessage>();
  for (const m of chat) {
    if (now - m.at > BUBBLE_MS) continue;
    const name = v.seats[m.seat]?.name;
    if (name && isMuted(name)) continue;
    latest.set(m.seat, m);
  }
  return (
    <>
      {[...latest.entries()].map(([seat, m]) => {
        const pos = posOf(seat);
        if (!pos) return null;
        return (
          <div key={`${seat}-${m.at}`} className={`bubble bubble-${pos}`} aria-live="polite">
            {m.text}
          </div>
        );
      })}
    </>
  );
}

/**
 * Chat sheet: quick messages, a composer (120-char limit), the recent log, and a mute toggle per player
 * (local-only; the server never sees who muted whom).
 */
export function ChatSheet({ v, chat, onSend, onClose }: { v: RoomView; chat: ChatMessage[]; onSend: (text: string) => void; onClose: () => void }) {
  const [text, setText] = useState('');
  const logRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight });
  }, [chat.length]);

  const send = (t: string) => {
    const clean = t.trim().slice(0, CHAT_MAX_LEN);
    if (!clean) return;
    onSend(clean);
    setText('');
  };

  const otherSeats = [0, 1, 2, 3].filter((s) => s !== v.mySeat && v.seats[s] && !v.seats[s]!.bot);

  return (
    <>
      <div className="dim" onClick={onClose} />
      <div className="bsheet chat-sheet" role="dialog" aria-label="الدردشة">
        <div className="grab" />
        <header>
          <h2>الدردشة</h2>
          <button className="ic close" aria-label="إغلاق" onClick={onClose}>
            <Icon id="i-x" />
          </button>
        </header>
        {otherSeats.length > 0 && (
          <div className="chat-mute-row">
            {otherSeats.map((s) => {
              const name = v.seats[s]!.name;
              const muted = isMuted(name);
              return (
                <button key={s} className={`mute-chip ${muted ? 'on' : ''}`} onClick={() => toggleMuted(name)} aria-pressed={muted}>
                  {muted ? `مكتوم: ${name}` : name}
                </button>
              );
            })}
          </div>
        )}
        <div className="chat-log" ref={logRef} aria-live="polite">
          {chat.length === 0 && <p className="empty-note">ولا رسالة بعد</p>}
          {chat.map((m, i) => {
            const name = v.seats[m.seat]?.name ?? '؟';
            if (isMuted(name)) return null;
            return (
              <div key={i} className={`chat-line ${m.seat === v.mySeat ? 'mine' : ''}`}>
                <b>{name}</b>
                <span>{m.text}</span>
              </div>
            );
          })}
        </div>
        <div className="chat-quick">
          {QUICK.map((q) => (
            <button key={q} className="quick-chip" onClick={() => send(q)}>
              {q}
            </button>
          ))}
        </div>
        <div className="chat-compose">
          <input
            value={text}
            maxLength={CHAT_MAX_LEN}
            placeholder="اكتب رسالة…"
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && send(text)}
          />
          <button className="btn send-btn" disabled={!text.trim()} onClick={() => send(text)}>
            إرسال
          </button>
        </div>
      </div>
    </>
  );
}
