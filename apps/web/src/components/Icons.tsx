/** Own-drawn line icons (design/layout-v3.html <defs>), 24x24, stroke 2. Mount <IconSprite/> once. */
const SPRITE = `<symbol id="star8" viewBox="0 0 100 100"><path d="M50 4L61 26L85 15L74 39L96 50L74 61L85 85L61 74L50 96L39 74L15 85L26 61L4 50L26 39L15 15L39 26Z"/></symbol>
  <symbol id="i-menu" viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16"/></symbol>
  <symbol id="i-invite" viewBox="0 0 24 24"><circle cx="10" cy="8" r="3.5"/><path d="M3.5 20c.7-3.6 3.2-5.6 6.5-5.6 1.4 0 2.6.3 3.6 1"/><path d="M18 13v7M14.5 16.5h7"/></symbol>
  <symbol id="i-chat" viewBox="0 0 24 24"><path d="M4 5h16v11H9l-4 4v-4H4z"/><path d="M8.5 10.5h.01M12 10.5h.01M15.5 10.5h.01"/></symbol>
  <symbol id="i-bot" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="12" rx="2.5"/><path d="M9 20h6M12 16v4"/><path d="M8.5 10h.01M15.5 10h.01"/></symbol>
  <symbol id="i-share" viewBox="0 0 24 24"><path d="M12 15V3M7.5 7.5L12 3l4.5 4.5"/><path d="M5 11v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8"/></symbol>
  <symbol id="i-gear" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2.5v2.2M12 19.3v2.2M4.9 4.9l1.6 1.6M17.5 17.5l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.9 19.1l1.6-1.6M17.5 6.5l1.6-1.6"/><circle cx="12" cy="12" r="6.5"/></symbol>
  <symbol id="i-play" viewBox="0 0 24 24"><path d="M7 4.5v15l12-7.5z"/></symbol>
  <symbol id="i-x" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></symbol>
  <symbol id="i-back" viewBox="0 0 24 24"><path d="M9 5l7 7-7 7"/></symbol>
  <symbol id="i-copy" viewBox="0 0 24 24"><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/></symbol>
  <symbol id="i-speed1" viewBox="0 0 24 24"><path d="M9 6l7 6-7 6z"/></symbol>
  <symbol id="i-speed2" viewBox="0 0 24 24"><path d="M4 6l7 6-7 6zM12 6l7 6-7 6z"/></symbol>
  <symbol id="i-speed3" viewBox="0 0 24 24"><path d="M1.5 6l6.5 6-6.5 6zM8.5 6l6.5 6-6.5 6zM15.5 6l6.5 6-6.5 6z"/></symbol>
  <symbol id="i-home" viewBox="0 0 24 24"><path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/></symbol>
  <symbol id="i-cards" viewBox="0 0 24 24"><rect x="3" y="6" width="11" height="15" rx="2"/><path d="M8 3h11a2 2 0 0 1 2 2v13"/></symbol>
  <symbol id="i-list" viewBox="0 0 24 24"><path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/></symbol>
  <symbol id="i-lock" viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></symbol>
  <symbol id="i-check" viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></symbol>
  <symbol id="i-plus2" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></symbol>
  <symbol id="i-chev" viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></symbol>
  <symbol id="i-bell" viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/></symbol>
  <symbol id="i-users" viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.8c1.8.8 3 2.6 3.5 5.2"/></symbol>
  <symbol id="i-book" viewBox="0 0 24 24"><path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 21V5M9 8h6"/></symbol>
  <symbol id="i-trophy" viewBox="0 0 24 24"><path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H4.5a3 3 0 0 0 3.6 4M16 6h3.5a3 3 0 0 1-3.6 4M12 13v4M8.5 20h7M10 17h4"/></symbol>
  <symbol id="i-bag" viewBox="0 0 24 24"><path d="M5 8h14l-1 12H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></symbol>
  <symbol id="i-shield" viewBox="0 0 24 24"><path d="M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6z"/><path d="M9 12l2 2 4-4"/></symbol>
  <symbol id="i-flag" viewBox="0 0 24 24"><path d="M5 21V4M5 4h11l-2 4 2 4H5"/></symbol>
  <symbol id="i-mic" viewBox="0 0 24 24"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/></symbol>
  <symbol id="i-userx" viewBox="0 0 24 24"><circle cx="10" cy="8" r="3.5"/><path d="M3.5 20c.7-3.6 3.2-5.6 6.5-5.6 1.4 0 2.6.3 3.6 1"/><path d="M16 14l5 5M21 14l-5 5"/></symbol>
  <symbol id="i-door" viewBox="0 0 24 24"><path d="M6 21V4h9v17M4 21h14"/><path d="M12 12h.01"/><path d="M18 8v4"/></symbol>
  <symbol id="i-volume" viewBox="0 0 24 24"><path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 9a4 4 0 0 1 0 6"/></symbol>
  <symbol id="i-coin" viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="#3A2F29" stroke="#C9BBA8" stroke-width="2"/><circle cx="16" cy="16" r="10" fill="none" stroke="#8F8272" stroke-width="1.2"/><text x="16" y="21.5" text-anchor="middle" font-family="Reem Kufi" font-weight="700" font-size="14" fill="#F2E9DC">ل</text></symbol>
  <symbol id="i-starc" viewBox="0 0 100 100"><path fill="#F2E9DC" stroke="#8F8272" stroke-width="4" d="M50 4L61 26L85 15L74 39L96 50L74 61L85 85L61 74L50 96L39 74L15 85L26 61L4 50L26 39L15 15L39 26Z"/><circle cx="50" cy="50" r="14" fill="#3A2F29"/></symbol>
  <symbol id="i-chatwa" viewBox="0 0 24 24"><path d="M4 5h16v11H9l-4 4v-4H4z"/><path d="M9 10.5h6"/></symbol>`;

export function IconSprite() {
  return <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true" focusable="false" dangerouslySetInnerHTML={{ __html: `<defs>${SPRITE}</defs>` }} />;
}

export type IconId =
  | 'star8'
  | 'i-menu'
  | 'i-invite'
  | 'i-chat'
  | 'i-bot'
  | 'i-share'
  | 'i-gear'
  | 'i-play'
  | 'i-x'
  | 'i-back'
  | 'i-copy'
  | 'i-speed1'
  | 'i-speed2'
  | 'i-speed3'
  | 'i-home'
  | 'i-cards'
  | 'i-list'
  | 'i-lock'
  | 'i-check'
  | 'i-plus2'
  | 'i-chev'
  | 'i-bell'
  | 'i-users'
  | 'i-book'
  | 'i-trophy'
  | 'i-bag'
  | 'i-shield'
  | 'i-flag'
  | 'i-mic'
  | 'i-userx'
  | 'i-door'
  | 'i-volume'
  | 'i-coin'
  | 'i-starc'
  | 'i-chatwa';

/** Line icon (stroke) or, for i-play / i-coin / i-starc / star8, a filled symbol. */
export function Icon({ id, className }: { id: IconId; className?: string }) {
  return (
    <svg className={`icon ${className ?? ''}`} aria-hidden="true" focusable="false">
      <use href={`#${id}`} />
    </svg>
  );
}
