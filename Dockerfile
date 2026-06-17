FROM --platform=linux/amd64 oven/bun:1.3.14 AS base

##### BUILDER
FROM base AS builder

WORKDIR /app

COPY package.json bun.lock .env ./

RUN bun install --no-save --frozen-lockfile

COPY . .

RUN bun run build

##### RUNNER
FROM base AS runner

WORKDIR /app

ENV NODE_ENV production
ENV BUN_INSTALLER_ENV production

COPY --from=builder /app/.output/. ./.

ENV PORT 3000
ENV HOSTNAME 0.0.0.0

CMD ["bun", "server/index.mjs"]
