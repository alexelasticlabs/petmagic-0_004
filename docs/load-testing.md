# Load Testing

PetMagic generation load tests use k6 and write summaries to `artifacts/load/`, which is ignored by Git. Run these tests against a disposable environment with realistic PostgreSQL, backend, and generation-worker sizing.

## Prerequisites

- Docker, for the baseline wrapper. Local k6 is optional for manual profile runs.
- Backend reachable through `BASE_URL`. When the backend is not published on the host, run Docker k6 on the Compose network with `K6_DOCKER_NETWORK=<project>_petmagic-network` and `BASE_URL=http://backend:5000`.
- At least one active template id.
- One or more bearer tokens through `AUTH_TOKEN` or comma-separated `AUTH_TOKENS`, or `LOGIN_EMAIL` and `LOGIN_PASSWORD`.
- Generation workers running separately from the backend. In Docker Compose, scale with `docker compose up --scale generation-worker=3`.
- PostgreSQL access for query-plan captures, either through Docker Compose service `postgres` or `POSTGRES_HOST`.

## Baseline Wrapper

Use the wrapper for baseline captures. It runs Docker k6 and stores k6 output, Docker stats, Compose state, PostgreSQL connection count, and queue depth before and after the test in one timestamped directory.

```bash
docker compose up -d --scale generation-worker=3

BASE_URL=http://host.docker.internal:5001 \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
PROFILE=generation \
VUS=100 \
ITERATIONS=100 \
WORKER_COUNT=3 \
bash scripts/load/run-template-generation-baseline.sh
```

Use the minimal readiness suite to run the required 100/100/100/10/10 profile set as one command:

```bash
docker compose up -d --scale generation-worker=3

BASE_URL=http://host.docker.internal:5001 \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
WORKER_COUNT=3 \
bash scripts/load/run-minimal-template-generation-suite.sh
```

The suite runs:

- 100 generation create requests.
- 100 create-and-poll flows.
- 100 status-polling virtual users.
- 10 duplicate idempotency checks.
- 10 overload-profile virtual users.

It writes `minimal-suite-report.md` plus one baseline artifact directory per profile under `artifacts/load/<suite-id>/`.

For a Compose-only backend that is reachable from other containers but not from the host:

```bash
docker compose up -d --scale generation-worker=3

BASE_URL=http://backend:5000 \
K6_DOCKER_NETWORK=petmagic-0_004_petmagic-network \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
PROFILE=generation \
VUS=100 \
ITERATIONS=100 \
WORKER_COUNT=3 \
bash scripts/load/run-template-generation-baseline.sh
```

For worker recovery, set a short lock timeout when starting the stack, run `PROFILE=create-and-poll`, stop one `generation-worker` container while jobs are processing, then rerun the wrapper or capture queue state after restart:

```bash
Templates__JobLockTimeoutMilliseconds=5000 docker compose up -d --scale generation-worker=3
PROFILE=create-and-poll bash scripts/load/run-template-generation-baseline.sh
```

## Profiles

Manual k6 commands are useful for focused checks when host metrics are not needed.

```bash
# 50-100 concurrent generation create requests.
k6 run \
  -e BASE_URL=http://localhost:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e AUTH_TOKENS=<token1,token2> \
  -e PROFILE=generation \
  -e VUS=100 \
  -e ITERATIONS=100 \
  scripts/k6/template-generation-load-test.js

# Create jobs and poll status until terminal state or timeout.
k6 run \
  -e BASE_URL=http://localhost:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e AUTH_TOKENS=<token1,token2> \
  -e PROFILE=create-and-poll \
  -e VUS=50 \
  -e ITERATIONS=100 \
  -e POLL_ATTEMPTS=20 \
  -e POLL_SLEEP_SECONDS=1 \
  scripts/k6/template-generation-load-test.js

# High-frequency status polling for an existing job.
k6 run \
  -e BASE_URL=http://localhost:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e GENERATION_ID=<generation-id> \
  -e AUTH_TOKEN=<token> \
  -e PROFILE=polling \
  -e VUS=100 \
  -e DURATION=2m \
  scripts/k6/template-generation-load-test.js

# Duplicate Idempotency-Key requests must return the same generation id.
k6 run \
  -e BASE_URL=http://localhost:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e AUTH_TOKEN=<token> \
  -e PROFILE=duplicates \
  -e VUS=20 \
  -e ITERATIONS=50 \
  scripts/k6/template-generation-load-test.js

# Queue overload should produce GENERATION_QUEUE_OVERLOADED or expected throttling.
k6 run \
  -e BASE_URL=http://localhost:5001 \
  -e TEMPLATE_ID=<template-id> \
  -e AUTH_TOKENS=<token1,token2> \
  -e PROFILE=overload \
  -e RATE=100 \
  -e VUS=100 \
  -e DURATION=2m \
  scripts/k6/template-generation-load-test.js
```

Use `MODE=admin-test` to exercise admin test generation endpoints. This still goes through the same worker, lock, retry, and recovery path.

## Worker Crash And Recovery

1. Start backend, PostgreSQL, and at least one generation worker.
2. Run `PROFILE=create-and-poll` with enough jobs to keep a worker busy.
3. Stop one worker container while a job is `Processing`.
4. Restart workers after `Templates__JobLockTimeoutMilliseconds` has elapsed.
5. Verify the stale job is either requeued and completed, or failed after `Templates__MaxGenerationAttempts` with refund handling.

Useful checks:

```sql
select "Status", count(*)
from templates_generation_jobs
group by "Status"
order by "Status";

select "Id", "UserId", "Status", "AttemptCount", "LockedBy", "LockedAtUtc", "UpdatedAtUtc"
from templates_generation_jobs
order by "QueuedAtUtc" desc
limit 20;

select count(*)
from pg_stat_activity
where datname = current_database();
```

```bash
docker compose ps
docker stats --no-stream
docker compose logs --tail=200 backend
docker compose logs --tail=200 generation-worker
```

## Baseline Report

For each run, keep the generated markdown summary and record:

- profile, date, git commit, environment, and worker count;
- RPS, p95 and p99 latency, HTTP failure rate, check pass rate;
- `generation_create_accepted`, `generation_queue_overloaded`, and `generation_active_limit_reached`;
- CPU/RAM from `docker stats --no-stream`;
- PostgreSQL connection count from `pg_stat_activity`;
- queue growth by status before and after the run;
- minimum worker count that keeps queue growth stable for the tested rate.

The wrapper writes the required artifacts under `artifacts/load/<run-id>/`:

- `baseline-metadata.env`;
- `baseline-report.md`;
- `k6-template-generation-summary.md`;
- `k6-template-generation-summary.json`;
- `docker-compose-ps-before.txt` and `docker-compose-ps-after.txt`;
- `docker-stats-before.txt` and `docker-stats-after.txt`;
- `postgres-connections-before.txt` and `postgres-connections-after.txt`;
- `queue-depth-before.txt` and `queue-depth-after.txt`.

A production baseline is complete only after these files are captured from the target environment and reviewed for stable queue growth and acceptable p95/p99 latency.

## Query Plan Baseline

Capture query plans from the same database used for the load baseline. The script records hot paths for generation claim/status/history/idempotency checks, provider RPM permits, email dispatch claim, support inbox, and economy subscription lookup.

```bash
# Against Docker Compose postgres.
SAMPLE_USER_ID=<known-user-id> \
SAMPLE_GENERATION_ID=<known-generation-id> \
bash scripts/db/capture-hot-query-plans.sh

# Against a remote PostgreSQL endpoint.
POSTGRES_HOST=<host> \
POSTGRES_PORT=5432 \
POSTGRES_USER=<user> \
POSTGRES_PASSWORD=<password> \
POSTGRES_DB=<database> \
SAMPLE_USER_ID=<known-user-id> \
SAMPLE_GENERATION_ID=<known-generation-id> \
bash scripts/db/capture-hot-query-plans.sh
```

The query-plan script writes `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)` output to `artifacts/query-plans/<run-id>/`. Mutation-style claim plans run inside `BEGIN ... ROLLBACK`, so they exercise planner and lock paths without leaving claimed jobs behind.

Review each `.sqlplan.txt` for sequential scans on growing hot tables, unexpected sort nodes, high shared buffer reads, and plans that do not use the indexes documented by `DatabaseIndexModelTests`. Keep the generated `query-plan-report.md` with the load baseline evidence.
