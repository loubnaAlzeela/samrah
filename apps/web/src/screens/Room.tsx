import { useEffect, useState, useSyncExternalStore } from 'react';
import { isB187Variant, isBalootVariant, isHandVariant, isTrixVariant } from '@lamma/rules';
import { useToast } from '../components/Chrome.tsx';
import { errorText } from '../i18n.ts';
import { RoomConn, saveName, savedName, takeHandOff } from '../net.ts';
import { navigate } from '../router.ts';
import { Table } from './Table.tsx';
import { Waiting } from './Waiting.tsx';

function useConn(conn: RoomConn | null) {
  return useSyncExternalStore(
    (fn) => (conn ? conn.subscribe(fn) : () => {}),
    () => (conn ? `${conn.status}|${conn.fatal}|${conn.lastError?.at}|${JSON.stringify(conn.view)}` : ''),
  );
}

export function Room({ code }: { code: string }) {
  const [name, setName] = useState(savedName);
  const [conn, setConn] = useState<RoomConn | null>(null);
  const [needName, setNeedName] = useState(false);

  useEffect(() => {
    const handed = takeHandOff(code);
    if (handed) {
      setConn(handed);
      return () => handed.close();
    }
    const hasToken = (() => {
      try {
        return !!localStorage.getItem(`lamma:seat:${code}`);
      } catch {
        return false;
      }
    })();
    if (!savedName() && !hasToken) {
      setNeedName(true);
      return;
    }
    const c = new RoomConn(code, savedName() || 'لاعب');
    setConn(c);
    void c.connect();
    return () => c.close();
  }, [code, needName]);

  useConn(conn);
  const [localToast, showToast] = useToast();

  if (needName) {
    return (
      <main className="screen center">
        <h1 className="screen-title">غرفة <bdi dir="ltr" className="num">{code}</bdi></h1>
        <label className="field">
          <span>اسمك باللعبة</span>
          <input value={name} maxLength={16} autoFocus onChange={(e) => setName(e.target.value)} />
        </label>
        <button
          className="btn primary"
          disabled={!name.trim()}
          onClick={() => {
            saveName(name.trim());
            setNeedName(false);
          }}
        >
          ادخل الغرفة
        </button>
      </main>
    );
  }

  if (!conn || (!conn.view && !conn.fatal)) {
    return (
      <main className="screen center">
        <p className="muted">جاري الدخول للغرفة…</p>
      </main>
    );
  }

  if (conn.fatal && !conn.view) {
    return <Fatal reason={conn.fatal} />;
  }

  const v = conn.view!;
  if (isTrixVariant(v.variant) || isB187Variant(v.variant) || isBalootVariant(v.variant) || isHandVariant(v.variant)) {
    return (
      <main className="screen center">
        <div className="sheet">
          <p>هذه اللعبة متاحة حاليًا في تطبيق الجوال فقط.</p>
          <button className="btn primary" onClick={() => navigate({ name: 'home' })}>
            للصفحة الرئيسية
          </button>
        </div>
      </main>
    );
  }
  const toast = localToast ?? (conn.lastError && Date.now() - conn.lastError.at < 2500 ? errorText(conn.lastError.code) : null);

  return (
    <>
      {v.status === 'waiting' ? <Waiting v={v} conn={conn} toast={showToast} /> : <Table v={v} conn={conn} toast={showToast} />}
      {conn.status === 'reconnecting' && (
        <div className="overlay" role="status">
          <div className="sheet">انقطع الاتصال… نحاول نرجعك لنفس المقعد</div>
        </div>
      )}
      {conn.fatal && <Fatal reason={conn.fatal} overlay />}
      {toast && (
        <div className="toast" role="alert">
          {toast}
        </div>
      )}
    </>
  );
}

function Fatal({ reason, overlay }: { reason: string; overlay?: boolean }) {
  const text =
    reason === 'replaced' ? 'فتحت نفس المقعد من جهاز أو تبويب ثاني' : reason === 'network' ? 'انقطع الاتصال بالسيرفر' : errorText(reason);
  const body = (
    <div className="sheet">
      <p>{text}</p>
      <button className="btn primary" onClick={() => navigate({ name: 'home' })}>
        للصفحة الرئيسية
      </button>
    </div>
  );
  return overlay ? <div className="overlay">{body}</div> : <main className="screen center">{body}</main>;
}

