# syntax=docker/dockerfile:1.7

# ---- Stage 1: build TypeScript -> dist/ ------------------------------------
FROM node:22-alpine AS builder
WORKDIR /app

# Install all deps (including dev) for the TS build.
COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Now strip dev deps so we can copy a lean node_modules into the runtime image.
RUN npm prune --omit=dev

# ---- Stage 2: minimal runtime ---------------------------------------------
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
# Cloud Run injects PORT (defaults to 8080). Our server reads process.env.PORT.
ENV PORT=8080

# Run as the built-in non-root `node` user.
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./
# `public/` is referenced by index.ts for static assets / AASA. Copy if present.
COPY --chown=node:node public* ./

USER node
EXPOSE 8080

CMD ["node", "dist/index.js"]
