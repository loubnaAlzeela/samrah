import { useState } from 'react';
import type { RoomView } from '@lamma/rules';
import { setSoundOn, soundOn } from '../net.ts';
import { inviteLink, navigate } from '../router.ts';
import { Icon } from './Icons.tsx';
import { playSound, primeAudio } from '../sound.ts';

export const VARIANT_TITLE = { tarneeb: 'طرنيب', syrian41: 'طرنيب سوري 41', trix: 'تركس', trixPartners: 'تركس شراكة', b187: 'لعبة 187', b187five: 'لعبة 187 · 5 لاعبين', baloot: 'بلوت', hand: 'هاند' } as const;

export function inviteText(v: RoomView) {
  return `تعال العب ${VARIANT_TITLE[v.variant]} معنا على لَمّة. كود الغرفة ${v.code}`;
}
/** WhatsApp share link (plain wa.me URL; no WhatsApp logo is used, see layout-v3 §4). */
export function whatsappUrl(v: RoomView) {
  return `https://wa.me/?text=${encodeURIComponent(`${inviteText(v)}\n${inviteLink(v.code)}`)}`;
}
/** Native share sheet when available (mobile), else copy the link. Returns a toast text or null. */
export async function shareInvite(v: RoomView): Promise<string | null> {
  const url = inviteLink(v.code);
  try {
    if (navigator.share) {
      await navigator.share({ title: 'لَمّة', text: inviteText(v), url });
      return null;
    }
    await navigator.clipboard.writeText(url);
    return 'انسخ رابط الدعوة ✓';
  } catch {
    return null;
  }
}

/**
 * Full top bar of the table screens (layout-v3 §4): menu + sound on the left, game name in the middle,
 * friends + invite on the right. The menu holds «مغادرة الطاولة» (disabled during a game when «بدون مغادرة» is on)
 * and «إعدادات اللعبة».
 */
export function RoomBar({ v, onSettings, toast }: { v: RoomView; onSettings: () => void; toast: (t: string) => void }) {
  const [menu, setMenu] = useState(false);
  const [sound, setSound] = useState(soundOn);
  const leaveLocked = v.status === 'playing' && v.settings.noLeave && v.mySeat !== null;
  return (
    <>
      <header className="topbar full">
        <div className="grp l">
          <button className="ic" aria-label="القائمة" aria-expanded={menu} onClick={() => setMenu(!menu)}>
            <Icon id="i-menu" />
          </button>
          <button
            className={`ic ${sound ? '' : 'off'}`}
            aria-label={sound ? 'كتم الصوت' : 'تشغيل الصوت'}
            aria-pressed={!sound}
            onClick={() => {
              primeAudio();
              const next = !sound;
              setSoundOn(next);
              setSound(next);
              if (next) playSound('bid'); // audible confirmation that sound is back on
            }}
          >
            <Icon id="i-volume" />
          </button>
        </div>
        <h1>{VARIANT_TITLE[v.variant]}</h1>
        <div className="grp r">
          <button className="ic" aria-label="الأصدقاء" onClick={() => toast('الأصدقاء قريباً')}>
            <Icon id="i-users" />
          </button>
          <button className="ic" aria-label="دعوة صديق" onClick={async () => { const t = await shareInvite(v); if (t) toast(t); }}>
            <Icon id="i-invite" />
          </button>
        </div>
      </header>
      {menu && (
        <>
          <div className="menu-dim" onClick={() => setMenu(false)} />
          <div className="room-menu" role="menu">
            <button
              role="menuitem"
              disabled={leaveLocked}
              onClick={() => {
                setMenu(false);
                navigate({ name: 'home' });
              }}
            >
              <Icon id="i-door" />
              {leaveLocked ? 'المغادرة معطّلة بهاللعبة' : 'مغادرة الطاولة'}
            </button>
            <button
              role="menuitem"
              onClick={() => {
                setMenu(false);
                onSettings();
              }}
            >
              <Icon id="i-gear" />
              إعدادات اللعبة
            </button>
          </div>
        </>
      )}
    </>
  );
}

/** Confirmation panel for the host's «إخراج» action. */
export function KickConfirm({
  name,
  queued = false,
  during = false,
  onYes,
  onNo,
}: {
  name: string;
  queued?: boolean;
  during?: boolean;
  onYes: () => void;
  onNo: () => void;
}) {
  return (
    <>
      <div className="stage-scrim" onClick={onNo} />
      <div className="table-panel" role="dialog" aria-label="إخراج لاعب">
        <h2 className="panel-h">{queued ? `إلغاء إخراج ${name}؟` : `إخراج ${name}؟`}</h2>
        <p className="muted small">
          {queued ? 'بيكمّل اللعب عادي.' : during ? 'بيطلع بنهاية الجولة الحالية، ومقعده بيروح للكمبيوتر.' : 'مقعده بيروح للكمبيوتر إذا اللعبة شغّالة.'}
        </p>
        <button className="btn" onClick={onYes}>
          <Icon id="i-userx" />
          {queued ? 'إلغاء الإخراج' : 'إخراج'}
        </button>
        <button className="btn" onClick={onNo}>
          إلغاء
        </button>
      </div>
    </>
  );
}
