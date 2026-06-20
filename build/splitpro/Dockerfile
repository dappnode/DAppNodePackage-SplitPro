FROM node:22.16.0-alpine3.21 AS base

RUN apk update && apk add --no-cache git

WORKDIR /app

RUN git clone --depth 1 --branch v2.1.3 https://github.com/oss-apps/split-pro.git .

ENV SKIP_ENV_VALIDATION=true
ENV DOCKER_OUTPUT=1
ENV NEXT_TELEMETRY_DISABLED=1
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV NEXT_PUBLIC_APP_VERSION=v2.1.3
ENV NEXT_PUBLIC_GIT_SHA=dce49ae038b89b8bb83ea93a5f37e4747d3e181c

RUN npm i -g corepack@latest && corepack enable
RUN pnpm install --frozen-lockfile
RUN pnpm build

FROM node:22.16.0-alpine3.21 AS release

ENV NODE_ENV=production
ENV DOCKER_OUTPUT=1

WORKDIR /app

RUN apk update && apk add --no-cache libc6-compat

COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static
COPY --from=base /app/public ./public
COPY --from=base /app/prisma/migrations ./prisma/migrations
COPY --from=base /app/start.sh ./start.sh
COPY build/splitpro/entrypoint.sh ./entrypoint.sh

ENV SKIP_ENV_VALIDATION=false

RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
RUN mkdir -p /app/uploads && chown -R nextjs:nodejs /app
USER nextjs

CMD ["sh", "entrypoint.sh"]
