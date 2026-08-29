# VPS fal.ai staging checklist

Use this checklist only for the isolated VPS staging environment. It does not
change production configuration automatically and it must not receive production
credentials or data.

## Current safe topology

| Area | Production | Isolated staging |
| --- | --- | --- |
| API host | `api.petgpt.app` | `api.staging.petgpt.app` |
| Compose project | `petmagic-0_004` | `petmagic-staging` |
| PostgreSQL/data paths | production VPS paths | separate staging paths |
| AI/media | fal.ai and R2 enabled | disabled by default |
| Email | Resend SMTP | local Mailpit, dispatch worker disabled |
| Payments | live provider configuration | Stripe test configuration only |

Production runs one generation worker. Its bounded lanes are `4 dispatch / 4
reconciliation / 1 media import / 1 maintenance`; provider capacity is governed
by the persisted PostgreSQL policy, not by adding workers.

## Before a fal.ai canary

- [ ] The staging environment file exists at
  `/opt/petmagic-staging/env/.env.staging`, has mode `0600`, and contains only
  distinct staging values.
- [ ] `api.staging.petgpt.app/health` is healthy before the worker is enabled.
- [ ] The staging database and media paths are empty or intentionally seeded;
  no production restore was used.
- [ ] A dedicated non-production fal.ai key and R2 bucket/path are available.
- [ ] The staging callback URL is
  `https://api.staging.petgpt.app/api/templates/provider/fal/webhook`.
- [ ] The owner set a small explicit provider budget and confirmed the expected
  paid-provider cost.

## Controlled staging enablement

1. Keep the API process worker-disabled and enable exactly one dedicated worker.
2. Set `TEMPLATES_AI_PROVIDER=Fal`, staging-only R2 configuration, and the
   staging callback URL in the staging environment file.
3. Run the environment preflight and start only the staging Compose project.
4. Verify API and worker fingerprints match the intended revision before
   admitting work.
5. Submit one controlled image job. Do not begin with video or a batch.
6. Confirm each transition: queued, provider accepted, callback reconciled,
   result media imported into staging R2, and terminal job state persisted.
7. Verify exactly one ledger/refund outcome for success, provider failure, and
   explicit cancellation.

## Capacity and safety checks

Use the Admin generation-control endpoint or the Generations capacity panel:

- `GET /api/admin/templates/generation-control`;
- `PUT /api/admin/templates/generation-control/policy` with a fresh
  `expectedRevision`, reason, and idempotency key;
- `POST /api/admin/templates/generation-control/provider/refresh`.

Before increasing capacity, verify:

- provider balance and concurrency are fresh;
- API and worker heartbeat are fresh;
- no fingerprint mismatch or critical alert is present;
- PostgreSQL has headroom for API, worker, and migration traffic;
- the queue drains at the measured rate without a rise in reconciliation
  failures.

Do not scale worker replicas merely because users are queued. Increase the
persisted policy only after the provider limit and real backlog justify it.

## Evidence required before production changes

- [ ] one successful image generation with R2 import;
- [ ] one provider failure with a single correct refund/terminal transition;
- [ ] one cancellation/retry flow;
- [ ] callback replay does not duplicate media or credits;
- [ ] worker restart recovers an in-flight job safely;
- [ ] measured queue/connection headroom at the proposed capacity;
- [ ] owner approval for the production capacity and provider spend limit.

Record only verified results in [`release-readiness.md`](release-readiness.md).
Do not reuse staging provider keys, database data, or temporary settings in
production.
