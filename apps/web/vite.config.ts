import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The design tokens live in <repo>/design/tokens.css (owned by the designer) and are imported directly,
// so Vite must be allowed to read the monorepo root.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, host: true, fs: { allow: ['../..'] } },
  // absolute '/' so deep links like /r/CODE load /assets/* correctly on the web host.
  // A native shell (Capacitor) build can set VITE_BASE=./ for relative paths.
  base: process.env.VITE_BASE ?? '/',
});
