import { useEffect, useState } from 'react';

/**
 * Tiny router with two interchangeable modes (VITE_ROUTER_MODE):
 *  - 'history' (default): /r/CODE  (web; the host needs an SPA fallback to index.html)
 *  - 'hash':              #/r/CODE (works with no web server at all, e.g. inside a native shell later)
 * Parsing accepts BOTH forms, so an invite link of either shape always opens the room.
 */
const MODE = (import.meta.env.VITE_ROUTER_MODE as string | undefined) === 'hash' ? 'hash' : 'history';

export type TabName = 'home' | 'games' | 'store' | 'clubs' | 'challenges' | 'tables';
export type Route = { name: TabName } | { name: 'room'; code: string };
const TABS: TabName[] = ['games', 'store', 'clubs', 'challenges', 'tables'];

const ROOM_RE = /\/r\/([A-Za-z0-9]{6})\/?$/;

export function parseLocation(): Route {
  const fromHash = window.location.hash.replace(/^#/, '').match(ROOM_RE);
  const fromPath = window.location.pathname.match(ROOM_RE);
  const m = fromHash ?? fromPath;
  if (m) return { name: 'room', code: m[1].toUpperCase() };
  const path = (MODE === 'hash' ? window.location.hash.replace(/^#/, '') : window.location.pathname).replace(/\/+$/, '').slice(1);
  return (TABS as string[]).includes(path) ? { name: path as TabName } : { name: 'home' };
}

export function roomPath(code: string): string {
  return MODE === 'hash' ? `#/r/${code}` : `/r/${code}`;
}

/** Absolute invite link for sharing (kept as a plain /r/CODE shape so it can map to a deep link later). */
export function inviteLink(code: string): string {
  const { origin } = window.location;
  return MODE === 'hash' ? `${origin}/#/r/${code}` : `${origin}/r/${code}`;
}

export function navigate(r: Route) {
  const target = r.name === 'room' ? roomPath(r.code) : `${MODE === 'hash' ? '#' : ''}/${r.name === 'home' ? '' : r.name}`;
  if (MODE === 'hash') window.location.hash = target.slice(1);
  else window.history.pushState(null, '', target);
  window.dispatchEvent(new Event('lamma:navigate'));
}

export function useRoute(): Route {
  const [route, setRoute] = useState<Route>(parseLocation);
  useEffect(() => {
    const on = () => setRoute(parseLocation());
    window.addEventListener('popstate', on);
    window.addEventListener('hashchange', on);
    window.addEventListener('lamma:navigate', on);
    return () => {
      window.removeEventListener('popstate', on);
      window.removeEventListener('hashchange', on);
      window.removeEventListener('lamma:navigate', on);
    };
  }, []);
  return route;
}
