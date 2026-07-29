# Load Testing

PetMagic generation load tests use k6 and write summaries to `artifacts/load/`, which is ignored by Git. Run these tests against a disposable environment with realistic PostgreSQL, backend, and generation-worker sizing.

## Prerequisites

- Docker, for the baseline wrapper. Local k6 is optional for manual profile runs.
- Backend reachable through `BASE_URL`. When the backend is not published on the host, run Docker k6 on the Compose network with `K6_DOCKER_NETWORK=<project>_petmagic-network` and `BASE_URL=http://backend:5000`.
- At least one active template id.
- One or more bearer tokens through `AUTH_TOKEN` or comma-separated `AUTH_TOKENS`, or `LOGIN_EMAIL` and `LOGIN_PASSWORD`.
- One generation worker running separately from the backend with Scheduler V2 bounded lanes
  `4/4/1/1` and `Templates__GenerationSchedulerV2Enabled=true`. Multi-worker tests are separate HA
  experiments, not the production capacity baseline.
- PostgreSQL access for query-plan captures, either through Docker Compose service `postgres` or `POSTGRES_HOST`.

## Baseline Wrapper

Use the wrapper for baseline captures. It runs Docker k6 and stores k6 output, Docker stats, Compose state, PostgreSQL connection count, and queue depth before and after the test in one timestamped directory.

```bash
docker compose up -d generation-worker

BASE_URL=http://host.docker.internal:5001 \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
PROFILE=generation \
VUS=100 \
ITERATIONS=100 \
WORKER_COUNT=1 \
bash scripts/load/run-template-generation-baseline.sh
```

Use the minimal readiness suite to run the required 100/100/100/10/10 profile set as one command:

```bash
docker compose up -d generation-worker

BASE_URL=http://host.docker.internal:5001 \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
WORKER_COUNT=1 \
bash scripts/load/run-minimal-template-generation-suite.sh
```

The suite runs:

- 100 generation create requests.
- 100 create-and-poll flows.
- 100 status-polling virtual users.
- 10 duplicate idempotency checks.
- 10 overload-profile virtual users.

It writes `minimal-suite-report.md` plus one baseline artifact directory per profile under `artifacts/load/<suite-id>/`.

## Scheduler V2 acceptance profile

Run this against a disposable PostgreSQL database and fake fal provider with exactly one worker:

- 50 distinct users and 200 mixed image/video jobs;
- policy effective global `38` for saturation, plus a separate global `8` strict-video-reserve run;
- active durable provider attempts never exceed the effective global limit;
- at global `8`, at least two slots remain available to video while image backlog is continuous;
- media import concurrency stays `1` and dispatch/reconciliation/cancel progress during a blocked or
  failing FFmpeg/import operation;
- no duplicate provider submission, PawSpark charge, refund, R2 object, or media row;
- restart recovery is under 120 seconds;
- Standard-equivalent worker RAM p95 is below 70%, peak below 85%, sustained CPU below 80%;
- total PostgreSQL connections stay below 70.

This is not production proof until the report contains the actual policy revision, worker lane
configuration, provider-attempt counts, queue/stage ages, CPU/RAM samples, DB connections, and
restart timestamps. A fake-provider pass does not prove real fal callbacks, limits, or billing.

The repository includes a fail-closed core-load runner for the first part of this matrix:

```bash
IMAGE_TEMPLATE_ID=<active-image-template-uuid> \
VIDEO_TEMPLATE_ID=<active-video-template-uuid> \
AUTH_TOKENS=<exactly-50-jwts-with-unique-uuid-sub-claims> \
WORKER_COUNT=1 \
bash scripts/load/run-generation-scheduler-v2-acceptance.sh
```

It requires exactly 50 JWTs with 50 unique UUID `sub` claims and submits exactly 200 jobs split
100/100 between verified Image and Video templates. Its runtime series is scoped to the current run's
idempotency prefix and requires one fresh Scheduler V2 worker, lanes `4/4/1/1`, effective global
capacity exactly `38`, actual provider-attempt saturation at `38`, worker progress after the run
started, and fewer than 70 PostgreSQL connections. Zero worker work, duplicate JWT subjects, stale or
V1 fingerprints, wrong lanes, and a wrong effective limit fail closed.

The verdict JSON always declares `scope: "core_load_only"`, `fullAcceptance: false`, and uses the
scoped statuses `CORE_LOAD_PASS` / `CORE_LOAD_FAIL` instead of generic PASS/FAIL. A passing core-load
verdict is therefore **not** complete Scheduler V2 acceptance. Run the strict global-8
video-reserve, blocked import/FFmpeg progress, restart-under-120-seconds, CPU/RAM, and exactly-once
provider/billing/storage scenarios separately and attach their artifacts before checking the full
list above.

For a Compose-only backend that is reachable from other containers but not from the host:

```bash
docker compose up -d generation-worker

BASE_URL=http://backend:5000 \
K6_DOCKER_NETWORK=petmagic-0_004_petmagic-network \
TEMPLATE_ID=<template-id> \
AUTH_TOKENS=<token1,token2> \
PROFILE=generation \
VUS=100 \
ITERATIONS=100 \
WORKER_COUNT=1 \
bash scripts/load/run-template-generation-baseline.sh
```

For worker recovery, set a short lock timeout when starting the stack, run `PROFILE=create-and-poll`, stop one `generation-worker` container while jobs are processing, then rerun the wrapper or capture queue state after restart:

```bash
Templates__JobLockTimeoutMilliseconds=5000 docker compose up -d generation-worker
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

1. Start backend, PostgreSQL, and exactly one generation worker for the production-topology test.
2. Run `PROFILE=create-and-poll` with enough jobs to keep a worker busy.
3. Stop the worker at each submit/reconciliation/import boundary, including after fal accepted a
   request but before its response was persisted.
4. Restart the worker after the applicable lock timeout.
5. Verify durable attempts are reclaimed, `SubmissionUnknown` is reconciled without blind resubmit,
   media checkpoints resume deterministically, and any terminal refund remains exactly once.

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
- oldest actionable dispatch/reconciliation/import age while provider capacity is free;
- whether one worker meets the limits above. A second worker is justified only for HA or if
  actionable backlog grows despite free fal capacity.

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
