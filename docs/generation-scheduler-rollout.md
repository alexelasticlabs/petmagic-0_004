# Generation scheduler operations

PetMagic runs one dedicated generation worker on the production VPS. Scheduler
capacity is a persisted PostgreSQL policy; it is not derived from container
replica count or provider account balance.

## Current production baseline

| Setting | Value |
| --- | ---: |
| Generation workers | 1 |
| Dispatch lanes | 4 |
| Provider reconciliation lanes | 4 |
| Media import lanes | 1 |
| Maintenance lanes | 1 |
| Scheduler V2 flag | `false` |
| Global provider concurrency | 8 |
| fal.ai configured concurrency | 10 |
| Reserved provider headroom | 2 |

The worker reads the same application revision and persistent data as the API.
Do not start a second worker, change lane counts, or enable Scheduler V2 merely
to address a visible queue. First inspect queue age, provider availability,
worker heartbeat, reconciliation failures, and database headroom.

## Safe configuration boundary

Runtime capacity is changed through the generation-control API, not by editing
containers directly:

```text
GET  /api/admin/templates/generation-control
PUT  /api/admin/templates/generation-control/policy
POST /api/admin/templates/generation-control/provider/refresh
```

For `PUT`, provide the displayed `expectedRevision`, a meaningful 3-500
character reason, and a unique `Idempotency-Key`. A stale revision must return
`409`; replaying the same key/payload must be idempotent.

## Before changing capacity

- [ ] Confirm fal.ai account concurrency and balance in the provider dashboard.
- [ ] Confirm production `/health` reports a fresh `templates_fal_provider`.
- [ ] Confirm API and worker heartbeats are fresh in the Admin Generations view.
- [ ] Check queue depth and age by media type and entitlement tier.
- [ ] Check `max_connections`, active PostgreSQL connections, and API/worker
  pool headroom.
- [ ] Confirm no migration, backup, or release is in progress.
- [ ] Create an idempotent capacity-policy change with an operator reason.

## Controlled change procedure

1. Start with a small increase that leaves provider headroom.
2. Observe queue drain, provider errors, worker progress, and database use.
3. Do not cancel active provider attempts when lowering capacity; stop only new
   reservations and allow active jobs to drain.
4. If the result is unhealthy, restore the preceding policy revision with a new
   operator reason.
5. Record observed inputs, result, and rollback decision in the release record.

## Scheduler V2 rollout

Scheduler V2 remains disabled in production. Enabling it is a separate,
reviewed release:

1. Validate the migration on both an existing-data and a clean database.
2. Deploy the additive schema while the flag is `false`.
3. Verify backfill, compatibility loop, queue admission, and worker heartbeat.
4. Pause admission through the Admin API, allow active jobs to drain, and run a
   one-job canary.
5. Enable the flag with a reviewed VPS release, then re-open admission only when
   API and worker fingerprints converge.
6. Roll back by setting the flag to `false`; retain the additive schema unless a
   separately reviewed migration removes it.

## Production evidence required

- [ ] provider saturation respects the configured concurrency limit;
- [ ] premium/privileged/free ordering and aging behave as configured;
- [ ] cancellation and refund create one durable terminal outcome;
- [ ] provider callback replay never duplicates media or credit;
- [ ] worker restart recovers in-flight work safely;
- [ ] 50-user / representative-job load stays within PostgreSQL and provider
  capacity;
- [ ] a paid image/video canary completes with callback reconciliation and R2
  import.

Local Compose checks and fake-provider runs are useful regressions, but they do
not prove VPS/provider acceptance. Use
[`staging-fal-rollout-checklist.md`](staging-fal-rollout-checklist.md) for the
isolated staging procedure and [`release-readiness.md`](release-readiness.md)
for the authoritative current state.
