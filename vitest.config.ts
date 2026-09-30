import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // rules and server run in Node (no browser DOM)
    environment: 'node',
  },
});
