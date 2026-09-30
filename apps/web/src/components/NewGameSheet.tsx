import { useState } from 'react';
import { type AnyVariant as Variant, DEFAULT_SETTINGS, type RoomSettings, type Speed } from '@lamma/rules';
import { num } from '../i18n.ts';
import { Icon, type IconId } from './Icons.tsx';

const SPEEDS: [Speed, IconId, string][] = [
  ['slow', 'i-speed1', 'هادئة (45 ثانية)'],
  ['normal', 'i-speed2', 'عادية (30 ثانية)'],
  ['fast', 'i-speed3', 'سريعة (15 ثانية)'],
];
const TARGETS = [31, 41, 61] as const;
export const MAX_LEVEL_SLIDER = 10;

function Toggle({ label, on, disabled, onChange }: { label: string; on: boolean; disabled?: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="srow2">
      <span className="lbl">{label}</span>
      <button className="tg" role="switch" aria-checked={on} aria-label={label} disabled={disabled} onClick={() => onChange(!on)} />
    </div>
  );
}

/**
 * «لعبة جديدة» bottom sheet (layout-v3 §3). Used to create a room, and in the room for the host to edit the
 * settings before the start (other players see it read-only).
 */
export function NewGameSheet({
  variant,
  initial,
  code,
  mode,
  onSubmit,
  onClose,
}: {
  variant: Variant;
  initial?: RoomSettings;
  code?: string;
  mode: 'create' | 'edit' | 'view';
  onSubmit?: (s: RoomSettings) => void;
  onClose: () => void;
}) {
  const [s, setS] = useState<RoomSettings>(initial ?? { ...DEFAULT_SETTINGS, target: variant === 'syrian41' ? 41 : DEFAULT_SETTINGS.target });
  const ro = mode === 'view';
  const set = <K extends keyof RoomSettings>(k: K, v: RoomSettings[K]) => !ro && setS((p) => ({ ...p, [k]: v }));
  const title = mode === 'create' ? 'لعبة جديدة' : 'إعدادات اللعبة';

  return (
    <>
      <div className="dim" onClick={onClose} />
      <div className="bsheet game-sheet" role="dialog" aria-label={title}>
        <div className="grab" />
        <header>
          <h2>{title}</h2>
          <button className="ic close" aria-label="إغلاق" onClick={onClose}>
            <Icon id="i-x" />
          </button>
        </header>
        <div className="sheet-body">
          <div className="srow2 wrap">
            <span className="lbl">نوع اللعبة</span>
            {code && s.visibility === 'private' && (
              <bdi dir="ltr" className="codebox num" aria-label={`رقم الغرفة ${code}`}>
                {code}
              </bdi>
            )}
            <div className="seg full" role="group" aria-label="نوع اللعبة">
              <button aria-pressed={s.visibility === 'private'} disabled={ro} onClick={() => set('visibility', 'private')}>
                <Icon id="i-lock" />
                لعبة خاصة
              </button>
              <button aria-pressed={s.visibility === 'public'} disabled={ro} onClick={() => set('visibility', 'public')}>
                لعبة عامة
              </button>
            </div>
          </div>
          <Toggle label="دردشة" on={s.chat} disabled={ro} onChange={(v) => set('chat', v)} />
          <Toggle label="الدردشة الصوتية" on={s.voice} disabled={ro} onChange={(v) => set('voice', v)} />
          <Toggle label="إخراج اللاعبين" on={s.kick} disabled={ro} onChange={(v) => set('kick', v)} />
          <Toggle label="بدون مغادرة" on={s.noLeave} disabled={ro} onChange={(v) => set('noLeave', v)} />
          <div className="srow2">
            <span className="lbl">سرعة اللعب</span>
            <div className="seg sm" role="group" aria-label="سرعة اللعب">
              {SPEEDS.map(([k, ic, label]) => (
                <button key={k} aria-pressed={s.speed === k} aria-label={label} disabled={ro} onClick={() => set('speed', k)}>
                  <Icon id={ic} className="fill" />
                </button>
              ))}
            </div>
          </div>
          <div className="srow2">
            <span className="lbl">النتيجة النهائية</span>
            <div className="seg sm num" role="group" aria-label="النتيجة النهائية">
              {TARGETS.map((t) => (
                <button key={t} aria-pressed={s.target === t} disabled={ro || variant === 'syrian41'} onClick={() => set('target', t)}>
                  {num(t)}
                </button>
              ))}
            </div>
          </div>
          <div className="srow2 last">
            <span className="lbl">تصنيف اللعبة</span>
            <label className="rng" dir="ltr">
              <span className="num">{num(s.minLevel)}</span>
              <input
                type="range"
                min={1}
                max={MAX_LEVEL_SLIDER}
                value={s.minLevel}
                disabled={ro}
                aria-label="أدنى مستوى للدخول"
                onChange={(e) => set('minLevel', Number(e.target.value))}
              />
            </label>
          </div>
        </div>
        {mode !== 'view' && (
          <div className="sheet-foot">
            <button className="btn primary big" onClick={() => onSubmit?.(s)}>
              {mode === 'create' ? 'أنشئ لعبة' : 'احفظ الإعدادات'}
            </button>
          </div>
        )}
      </div>
    </>
  );
}
