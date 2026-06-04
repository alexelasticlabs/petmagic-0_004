# PetMagic Load Testing

This repository ships a k6 scenario for the PostgreSQL-backed template generation queue:

- 50-100 concurrent generation requests.
- High-frequency generation status polling.
- Duplicate requests with the same `Idempotency-Key`.
- Queue overload behavior.
- Admin-test queue load that bypasses user billing/active limits.

## Prerequisites

Start the stack with one backend and multiple generation workers:

```bash
docker compose up -d --scale generation-worker=3
docker compose ps
```

Use real test users for user isolation tests, or an admin/moderator token for `MODE=admin-test`.

Required k6 environment:

- `BASE_URL`: API base URL, for example `http://localhost:5000` or `http://host.docker.internal:5001` from Docker on macOS.
- `TEMPLATE_ID`: active template id.
- `AUTH_TOKEN` or `AUTH_TOKENS`: comma-separated JWT access tokens.
- Alternative to tokens: `LOGIN_EMAIL` and `LOGIN_PASSWORD`.
- `MODE`: `user` or `admin-test`.

## Run Commands

Local k6:

```bash
BASE_URL=http://localhost:5000 \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token-1>,<token-2>,<token-3> \
MODE=user \
PROFILE=generation \
VUS=50 \
ITERATIONS=100 \
k6 run scripts/k6/template-generation-load-test.js
```

Docker k6 on macOS:

```bash
mkdir -p artifacts/load
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  -e BASE_URL=http://host.docker.internal:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e AUTH_TOKEN=<admin-or-user-token> \
  -e MODE=admin-test \
  -e PROFILE=create-and-poll \
  -e VUS=50 \
  -e ITERATIONS=100 \
  grafana/k6:0.49.0 run scripts/k6/template-generation-load-test.js
```

Profiles:

- `PROFILE=generation`: create jobs only.
- `PROFILE=create-and-poll`: create jobs and poll each job until terminal state or timeout.
- `PROFILE=polling`: status polling against `GENERATION_ID`, or creates a job per VU if absent.
- `PROFILE=duplicates`: submits two requests with the same `Idempotency-Key` and checks the same `generationId`.
- `PROFILE=overload`: constant-arrival-rate load; 503 `GENERATION_QUEUE_OVERLOADED` and 429 throttling are counted separately from unexpected failures.

## Worker Crash Recovery Check

Use a short lock timeout for a fast recovery test:

```bash
Templates__JobLockTimeoutMilliseconds=5000 docker compose up -d --scale generation-worker=3
```

Run `PROFILE=create-and-poll`, then stop one worker while jobs are processing:

```bash
docker compose ps generation-worker
docker stop <generation-worker-container>
```

Restart workers and verify stale jobs are requeued or failed after retry exhaustion:

```bash
docker compose up -d --scale generation-worker=3
docker compose exec postgres psql -U petmagic_user -d petmagic_db -c \
  'select "Status", count(*) from templates_generation_jobs group by "Status" order by "Status";'
```

## Baseline Capture

Each k6 run writes:

- `artifacts/load/k6-template-generation-summary.json`
- `artifacts/load/k6-template-generation-summary.md`

Capture infrastructure data next to the k6 summary:

```bash
docker stats --no-stream > artifacts/load/docker-stats.txt
docker compose exec postgres psql -U petmagic_user -d petmagic_db -c \
  "select count(*) from pg_stat_activity where datname = 'petmagic_db';" \
  > artifacts/load/postgres-connections.txt
docker compose exec postgres psql -U petmagic_user -d petmagic_db -c \
  'select "Status", count(*) from templates_generation_jobs group by "Status" order by "Status";' \
  > artifacts/load/queue-depth.txt
```

Record the minimum acceptable baseline per environment:

| Scenario | Workers | VUs/rate | RPS | p95 | p99 | CPU/RAM | Postgres connections | Queue growth | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | --- |
| generation | 3 | 50 VUs / 100 iterations | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| create-and-poll | 3 | 50 VUs / 100 iterations | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| overload | 3 | 100 rps / 2m | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
