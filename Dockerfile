# Game server image (Railway, Fly.io, any Docker host). Build from the repo root:
#   docker build -t samrah-server .
# The server runs TypeScript directly with tsx (no build step), and reads PORT from the environment.
FROM node:24-slim

WORKDIR /app

# install first (cached while only source changes): the root + the two workspaces the server needs
COPY package.json package-lock.json tsconfig.base.json ./
COPY packages/rules/package.json packages/rules/
COPY apps/server/package.json apps/server/
RUN npm ci --no-audit --no-fund

COPY packages/rules packages/rules
COPY apps/server apps/server

ENV NODE_ENV=production
EXPOSE 2567
CMD ["npx", "tsx", "apps/server/src/index.ts"]
