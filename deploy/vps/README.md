# PetMagic VPS runbook

This directory is the only production deployment source for PetMagic.
Production does not use a managed application host or a Blueprint deployment.

## Current production topology

| Area | Current implementation |
| --- | --- |
| Host | Dedicated OVH VPS `vps-fea3ac06`, Ubuntu 26.04 LTS |
| Public edge | Host-level Caddy: `api.petgpt.app` and `admin.petgpt.app` over HTTPS |
| Runtime | Docker Compose supervised by `petmagic-compose.service` |
| Application | ASP.NET API, one `generation-worker`, Next.js admin web, PostgreSQL |
| Secrets | `/opt/petmagic/shared/env/.env.vps`, owned by root, mode `0600` |
| Persistent data | `/opt/petmagic/shared/postgres` and `/opt/petmagic/shared/api-data` |
| Backups | nightly systemd timer, PostgreSQL/API-data snapshot, encrypted restic backup in the dedicated R2 bucket |
| Production email | Resend SMTP; the bundled Mailpit container is not an external delivery service |

The deployed repository lives at `/opt/petmagic/current`. Application, PostgreSQL,
and admin ports bind to `127.0.0.1`; only Caddy accepts public HTTP(S) traffic.

## Confirmed runtime state — 2026-08-27

- `petmagic-compose.service`, `caddy`, and `petmagic-postgres-backup.timer` are
  active on the VPS.
- The API, admin web, generation worker, PostgreSQL, and internal Mailpit
  container are healthy. Public `https://api.petgpt.app/health` and
  `https://admin.petgpt.app/ru` return HTTP 200.
- The deployed source revision is
  `61bc60724176193f72dbe1dc1e9a8970a2995b5d`.
- `/health` intentionally reports overall `Degraded` only because
  `STORE_ACCOUNT_BINDING_MODE=compatibility`. Do not change it to `enforce`
  until real Google Play and App Store purchase/restore/replay evidence exists.
- Production email is delivered through Resend. Mailpit is available only for
  local and isolated staging diagnostics; it must never be configured as the
  production SMTP provider.

This is runtime and transport evidence. Store billing, Apple Sign In, APNs,
and provider webhook lifecycles still require their own device/Sandbox evidence;
see [release readiness](../../docs/release-readiness.md).

## Safety rules

- Run these commands only on `vps-fea3ac06`, never on another VPS.
- Do not print, copy, commit, or paste the production environment file, private
  keys, tokens, database URLs, or backup password.
- Do not edit `/opt/petmagic/shared/env/.env.vps` through a shell heredoc.
  Use `sudoedit`, then run preflight before any restart.
- Do not use local `.env`, `.env.example`, or isolated staging values as
  production configuration.
- Do not manually start individual production containers while the supervisor
  is active. Use the release script or the systemd unit.
- `restore-render-postgres.sh` and `restore-render-disk.sh` are completed
  one-time migration artifacts retained only because backup/runtime-preflight
  verifies their immutable restore markers. They are not deployment commands.

## Read-only status check

```bash
sudo systemctl is-active petmagic-compose caddy petmagic-postgres-backup.timer
sudo docker ps --format 'table {{.Names}}\t{{.Status}}'
curl --fail --silent --show-error https://api.petgpt.app/health
curl --fail --silent --show-error -o /dev/null -w '%{http_code}\n' https://admin.petgpt.app/ru
sudo git -C /opt/petmagic/current rev-parse HEAD
```

For an incident, inspect bounded logs before changing anything:

```bash
sudo journalctl -u petmagic-compose.service -n 200 --no-pager
sudo journalctl -u caddy -n 200 --no-pager
sudo docker compose \
  --env-file /opt/petmagic/shared/env/.env.vps \
  -f /opt/petmagic/current/docker-compose.yml \
  -f /opt/petmagic/current/deploy/vps/compose.vps.yaml \
  logs --tail=200 backend generation-worker admin-web
```

## Normal release procedure

1. Validate and merge the change into `master`; push it to GitHub.
2. SSH to the dedicated VPS.
3. Run the controlled release script:

```bash
sudo bash /opt/petmagic/current/deploy/vps/scripts/deploy-release.sh
```

The script fetches `origin/master`, requires a clean checkout, updates
`SOURCE_REVISION`, runs production preflight, builds the API/worker/admin images,
restarts the supervised stack, and verifies image revisions. If build, restart,
or runtime preflight fails, it restores the preceding checkout and source revision.

To deploy a known commit already contained in `origin/master`:

```bash
sudo bash /opt/petmagic/current/deploy/vps/scripts/deploy-release.sh --revision <full-40-character-sha>
```

Do not use `git pull`, edit `SOURCE_REVISION`, or call `docker compose up` as a
production deployment shortcut.

## Environment and preflight

The production configuration is root-only:

```bash
sudo stat -c '%U:%G %a %n' /opt/petmagic/shared/env/.env.vps
sudo bash /opt/petmagic/current/deploy/vps/scripts/preflight.sh
```

The expected permission is `root:root 600`. Preflight rejects duplicate keys,
placeholders, an unsafe production profile, a dirty checkout, and a source
revision mismatch. It also requires production provider credentials without
printing their values.

Important production invariants include:

- `ASPNETCORE_ENVIRONMENT=Production`;
- `DOCKER_BIND_ADDRESS=127.0.0.1`;
- R2 media storage and fal.ai provider enabled;
- exactly one generation worker with bounded `4/4/1/1` lanes;
- Firebase push enabled;
- `BOOTSTRAP_ADMIN_PASSWORD` empty;
- `STORE_ACCOUNT_BINDING_MODE=compatibility` until store acceptance is proven.

## Backups and restore readiness

The nightly timer starts at `03:30 UTC`:

```bash
sudo systemctl status petmagic-postgres-backup.timer --no-pager
sudo systemctl list-timers petmagic-postgres-backup.timer --all
```

The backup job takes a coordinated PostgreSQL and API-data snapshot, resumes the
API and worker, then encrypts and uploads the artifacts to the private R2 restic
repository. It retains daily, weekly, and monthly snapshots. The restic password
is `/opt/petmagic/shared/env/restic-password`, mode `0600`; never display it.

Before modifying backup configuration, first perform a read-only repository
check and an isolated restore test. Do not delete snapshots, reinitialize the
repository, or change R2 credentials during an incident.

## Isolated payment staging

`api.staging.petgpt.app` is an isolated payment test environment on the same
VPS. It has separate PostgreSQL data, paths, JWT, Stripe test keys, webhook
secret, and Compose project. It must never receive production data, SMTP, R2,
fal.ai, Firebase, OAuth, or store credentials.

The staging configuration is `/opt/petmagic-staging/env/.env.staging`; the
runtime uses `deploy/vps/compose.staging.vps.yaml`. Staging Mailpit is local-only
and its email dispatch worker remains disabled. It is valid for Stripe sandbox
tests, not for customer email delivery or production acceptance.

## Provider configuration summary

| Integration | Confirmed configuration | Still requires real acceptance |
| --- | --- | --- |
| Stripe | live production endpoint and separate staging test endpoint | cancellation, retry, refund, renewal, and signed webhook lifecycle |
| Google Play | production verification credentials and active catalog | licensed Internal tester purchase, backend verification, consume, replay, restore |
| App Store | API/signing setup, server-notification routes, catalog | TestFlight device install, Apple Sign In, StoreKit Sandbox purchase/restore, signed notification |
| Firebase | production configuration and backend registration | visible FCM/APNs delivery on physical devices |
| Resend | verified production sender and SMTP delivery path | routine monitoring and failure handling |

The current products use intentionally low test prices: Premium monthly USD 0.99,
Premium yearly USD 1.99, and token packs USD 0.99 / 1.49 / 1.99. Premium grants
40 PawSpark at activation and then every seven days while the entitlement is
active. Provider catalog configuration is not evidence of a completed purchase.

## First-server bootstrap only

The following steps are for a brand-new dedicated VPS, not normal releases:

1. Install Docker Engine, Docker Compose, Caddy, UFW, PostgreSQL client tools,
   and restic.
2. Install `petmagic-compose.service`, `petmagic-postgres-backup.service`, and
   `petmagic-postgres-backup.timer` from `deploy/vps/systemd/`.
3. Create `/opt/petmagic/shared` directories and the root-only production
   environment file from `.env.vps.example`.
4. Install and validate `Caddyfile`; expose only SSH, HTTP, and HTTPS through
   UFW.
5. Run `preflight.sh`, then start `petmagic-compose.service` and the backup
   timer after successful local and public smoke checks.

Do not repeat bootstrap or data-import steps on the active VPS. Production data
is already authoritative on the VPS; use the controlled release and backup
procedures above.
