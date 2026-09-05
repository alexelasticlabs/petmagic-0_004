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

Release builds require at least 12 GiB free before checkout/configuration changes.
The release reserves 64 MiB for rollback, checks environment writes explicitly,
and preserves the existing stack if image building fails before restart.
Run `bash scripts/qa/test-deploy-release-safety.sh` to check failure handling of
the environment writer without accessing production configuration.

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
- watermark rendering enabled for free-user image and video results;
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

PostgreSQL also has an online off-site copy every 15 minutes (`:07`, `:22`, `:37`,
`:52` UTC), through `petmagic-postgres-frequent.timer`. `pg_dump` takes a consistent
database snapshot without stopping the API. Each dump is validated locally,
checksummed and encrypted by restic before a success marker is written. Failed
uploads preserve the local dump and retry up to three times. Local frequent dumps
are retained for three days; off-site retention keeps all snapshots from the last
24 hours, then 14 daily, 8 weekly and 12 monthly restore points.

Frequent snapshots have a separate `postgres-frequent` tag. Both retention
policies group by `host,tags`, because timestamped filenames must not create
independent retention groups. Nightly retention selects only `production`
snapshots, so it cannot remove the recent frequent database restore points.
All backup and restore operations share the release and backup locks. The Compose
unit preserves its runtime directory across maintenance stops to retain the same
lock inodes.

`petmagic-postgres-verify.timer` runs every Sunday at 04:40 UTC: it reads and checks
the encrypted repository, downloads the latest frequent snapshot, verifies its
checksum and restores it into a disposable PostgreSQL container without network
access or published ports. Production data is never used as the restore target.
`petmagic-backup-health.timer` checks success markers every 15 minutes and fails
if a database copy is over 45 minutes old, the coordinated nightly copy is over
30 hours old, or restore verification is over eight days old. Failures are visible
in systemd/journald; an external notification destination is a separate integration.

Install `scripts/postgres-backups.py` and `scripts/backup-offsite.sh` into the
root-only `/opt/petmagic/shared/operations/` directory before installing the
corresponding systemd units. Run a frequent backup, a coordinated nightly backup,
an isolated restore, and the freshness check successfully before enabling timers.
Failure-path tests run with `python3 scripts/qa/test_postgres_backups.py` on Linux.

The database recovery-point target is 15 minutes plus backup completion time;
this is snapshot recovery, not continuous WAL/PITR or a zero-data-loss guarantee.
Local API files are covered by the coordinated nightly snapshot. R2 application
media objects are separate from these database/local-file snapshots. Disaster
recovery also requires a separately protected operator copy of the restic password
and dedicated backup credentials: copies on the VPS alone cannot survive its loss.

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

### Staging persistence and host maintenance

Staging bind mounts use `!override`. Do not replace this with `!reset`: Compose
discards the supplied mount values for a reset, leaving PostgreSQL on an anonymous
volume and API files inside the container. Run
`bash scripts/qa/test-staging-compose.sh` to validate the resolved Compose model.
The test uses synthetic example settings and does not require a Docker daemon.

The host installs `systemd/petmagic-staging.service` for boot and Docker restart
recovery. `/opt/petmagic-staging/runtime` points to the pinned staging release;
`/opt/petmagic-staging/compose.vps.yaml` is the installed staging override.
This preserves the staging application revision independently of production.
Before first enabling this unit on an existing host, compare actual container
mounts with the intended bind mounts, back up PostgreSQL and API files, and move
existing data while staging is stopped. Never recreate a legacy staging database
against empty bind mounts. Verify table counts and health after the transfer.

Repository host configuration templates are `ssh/00-petmagic.conf` (key-based
SSH, no password or X11 forwarding) and `journald/60-petmagic.conf` (512 MiB /
14-day journal retention). Verify a fresh operator key login before installing
the SSH template, run `sshd -t`, reload SSH, and verify another fresh key login.
Keep a timed rollback until that second login succeeds.

Before OS/Docker maintenance, verify the off-site backup with an isolated restore,
check active generations, download and review package updates, and validate both
production and staging startup. Use systemd for planned stack stops/restarts.
After a host reboot, verify all containers, public health endpoints, backup timer,
kernel version, and production runtime preflight. OS maintenance does not change
the application source revision.

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
