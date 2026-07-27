# syntax=docker/dockerfile:1.7
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,id=npm-admin-web,sharing=locked,target=/root/.npm \
    npm ci --engine-strict --prefer-offline --fetch-retries=5 --fetch-retry-mintimeout=20000 --fetch-retry-maxtimeout=120000

FROM deps AS builder
WORKDIR /app
COPY . .
RUN mkdir -p public
ARG NEXT_PUBLIC_API_BASE_URL
ARG INTERNAL_API_BASE_URL
ARG ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
ARG NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV INTERNAL_API_BASE_URL=$INTERNAL_API_BASE_URL
ENV ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=$ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION
ENV NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=$NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM deps AS production-deps
WORKDIR /app
RUN npm prune --omit=dev --engine-strict

FROM node:24-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
COPY --chown=node:node --from=builder /app/package.json /app/package-lock.json ./
COPY --chown=node:node --from=production-deps /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/.next ./.next
COPY --chown=node:node --from=builder /app/next.config.ts ./next.config.ts
COPY --chown=node:node --from=builder /app/public ./public
USER node
EXPOSE 3000
CMD ["npm", "run", "start", "--", "-H", "0.0.0.0", "-p", "3000"]
