# ── Stage 1: build webapp ────────────────────────────────────────────────────
FROM node:25-alpine AS webapp-build
WORKDIR /build/webapp
COPY webapp/package*.json ./
RUN npm ci
COPY webapp/ ./
RUN npm run build
# Output lands in /build/webapp/dist/

# ── Stage 2: build server ─────────────────────────────────────────────────────
FROM node:25-alpine AS server-build
WORKDIR /build/server
COPY server/package*.json ./
RUN npm ci
COPY server/ ./
RUN npm run build
# Output lands in /build/server/dist/

# ── Stage 3: runtime ──────────────────────────────────────────────────────────
FROM node:25-alpine
WORKDIR /app

# Production deps only
COPY server/package*.json ./
RUN npm ci --omit=dev

# Compiled server
COPY --from=server-build /build/server/dist ./dist

# Static files served by the server at /public
COPY server/public ./public

# Webapp build output goes into public/ so the server's SPA fallback works
COPY --from=webapp-build /build/webapp/dist ./public

EXPOSE 8787
ENV PORT=8787
ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
