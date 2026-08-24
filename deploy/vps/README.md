# PetMagic VPS deployment

This directory defines the production runtime for the dedicated PetMagic VPS. It keeps the
same application split as Render: PostgreSQL, API, one generation worker, and
admin web. Caddy runs on the host and is the only public listener.

## Safety boundaries

- Use only the dedicated PetMagic VPS. Do not run these commands on the
  ai-frontrunner production VPS.
- Application, PostgreSQL, and admin ports remain bound to `127.0.0.1`.
  UFW exposes only SSH, HTTP, and HTTPS.
- Do not copy secrets into this repository or this directory. The runtime
  environment file is `/opt/petmagic/shared/env/.env.vps`, mode `0600`.
- Do not point production DNS or provider webhooks to the VPS until the stack,
  backup, and read-only smoke checks pass.

## Current migration status

This section is a configuration inventory, not evidence that a provider flow
has been delivered successfully in production. It intentionally contains no
secret values, private keys, tokens, or service-account JSON.

### Confirmed upstream configuration

- App Store Connect contains the `Pet Video Magic` iOS app with bundle ID
  `com.petmagic.app`; the Paid Apps Agreement is active.
- The App Store Connect catalog contains configured auto-renewable Premium
  subscriptions and consumable token products in `Prepare for Submission`.
  Their product IDs and entitlement mapping still need end-to-end mobile and
  backend verification before submission.
- App Store Server Notifications are configured for both production and Sandbox
  at `https://api.petgpt.app/api/economy/webhooks/app-store`. This confirms the
  destinations; a real signed Sandbox delivery is still required.
- Sign in with Apple is enabled for the app and its server key was generated
  and stored outside the repository. The generated client secret and real login
  flow still need VPS verification.
- Firebase has an iOS registration for `com.petmagic.app`; its
  `GoogleService-Info.plist` was placed locally under
  `apps/petmagic-mobile/ios/Runner/` and is Git-ignored. A production APNs
  authentication key was uploaded to Firebase.

### Verified private-VPS acceptance

- [x] `/opt/petmagic/shared/env/.env.vps` passed the production preflight;
      runtime secrets remain only on the VPS.
- [x] Caddy, the Compose supervisor, PostgreSQL, API, admin web and exactly
      one generation worker are healthy. Public `api.petgpt.app/health` and
      `admin.petgpt.app/ru` return HTTP 200 over HTTPS.
- [x] The application R2 credentials completed a temporary `PUT`/`GET`/`DELETE`
      smoke check in the media bucket. The temporary object was deleted.
- [x] A dedicated least-privilege R2 backup bucket and encrypted restic
      repository are initialized. The nightly backup timer is enabled.
- [x] A PostgreSQL/API-data backup was created, integrity-checked and restored
      into a temporary database. The restore had 82 public tables and 99 EF
      migrations; the temporary database and copied dump were removed.
- [x] Stripe has exactly one enabled VPS webhook endpoint with all backend
      subscription and checkout event types subscribed. This confirms provider
      configuration, not a real signed-event delivery.
- [x] App Store Connect production and Sandbox notification URLs both target
      the VPS API webhook route. This confirms provider configuration, not a
      real signed Sandbox-event delivery.
- [x] Native Google sign-in is configured against the Google/Firebase project
      embedded in the published Android bundle. The mobile configuration route
      returns HTTP 200 and a deliberately invalid native token is rejected with
      the expected authentication error. A real Google-account login on a
      physical Android device is still required.
- [ ] Browser redirect-based Google OAuth remains intentionally disabled until
      a matching client secret is provisioned in that same Google project.
      Native Android/iOS token verification does not use a browser OAuth client
      secret.

### VPS cutover and acceptance still required

- [x] Android `1.0.0+2`, built with `API_BASE_URL=https://api.petgpt.app`, was
      published to Play Internal by run `32674447149`. The prior
      `api.petmagic.app` host does not resolve in DNS; do not use it for a
      release build.
- [x] Restore the protected GitHub production Android credentials: the existing
      Play upload keystore, Firebase production config and Play service-account
      JSON are configured. Run `32666052824` built and signed `1.0.0+2` and
      preserved its symbols artifact; no secret values are recorded here.
- [x] Grant the existing Play service account permission to release PetMagic to
      testing tracks. Run `32666052824` proved the missing permission; Play
      Console now confirms the account has five PetMagic app permissions,
      including `Release apps to testing tracks`.
- [x] Run `32674447149` built, archived, and published Android `1.0.0+2` to
      Play Internal after the testing-track release permission was granted.
- [x] A Play-installed Android `1.0.0+2` device reached the VPS API; server
      logs recorded its authentication requests.
- [ ] Complete real-device authentication acceptance: verified email/password
      login and native Google sign-in with a real Google account.
- [ ] Repair the independent iOS CI signing configuration before TestFlight:
      the App Store Connect API key and Firebase iOS configuration were absent
      or malformed in the protected GitHub production environment.
- [ ] Prove a real signed Stripe delivery and a real signed App Store Sandbox
      notification. Provider endpoint configuration is verified, but delivery
      and signature acceptance are not yet evidenced.
- [ ] Run real-provider acceptance: Sign in with Apple, FCM/APNs on a physical
      iOS device, Stripe Checkout/webhook reconciliation, App Store Sandbox
      purchase/restore/refund or cancellation lifecycle, and idempotent token
      crediting.
- [ ] Complete Google Play sandbox acceptance. The service account has verified
      PetMagic app and billing access: OAuth succeeds and the purchase API
      reaches its expected validation path for a synthetic token. Catalog-list
      access remains intentionally unavailable because `Manage store presence`
      is not required for backend purchase verification and is not granted.
- [ ] Create the approved Google Play subscription product, base plan, prices
  and tester offer. The Play Console subscription list currently has no
  subscription entries; a healthy VPS `economy_subscription_plans` check does
  not make an Android purchase possible.
- [ ] Match the **Play app signing** SHA-1 certificate to an Android OAuth
  client in the Firebase/Google project. The upload-key certificate is a
  different certificate and must not be used for Google Sign-In configuration.
- [ ] Prove restore of retained Render migration artifacts, including any
      persistent data not covered by the current VPS backup, before discarding
      the Render export/archive or signing off cutover.

## One-time server setup

The host needs Docker Engine, Docker Compose, Caddy, UFW, a PostgreSQL client
new enough to read the Render PostgreSQL 16 export, and `restic`. Caddy must be
installed but kept stopped until the release has passed local health checks.
Install the host-side restore/backup tools and firewall rules before importing:

```bash
sudo apt-get update
sudo apt-get install -y postgresql-client-18 restic
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

Install the checked-in units after the first release is placed at
`/opt/petmagic/current`:

```bash
sudo install -m 0644 deploy/vps/systemd/petmagic-compose.service /etc/systemd/system/petmagic-compose.service
sudo install -m 0644 deploy/vps/systemd/petmagic-postgres-backup.service /etc/systemd/system/petmagic-postgres-backup.service
sudo install -m 0644 deploy/vps/systemd/petmagic-postgres-backup.timer /etc/systemd/system/petmagic-postgres-backup.timer
sudo systemctl daemon-reload
```

## Environment file

Use the dedicated production template. Do not copy the repository-level local
development `.env.example`:

```bash
sudo install -m 0600 deploy/vps/.env.vps.example /opt/petmagic/shared/env/.env.vps
sudoedit /opt/petmagic/shared/env/.env.vps
```

Populate every `__REQUIRED__` value from the approved protected configuration,
without printing secret values in logs or chat. If Render is still being used
as the migration source, read its production configuration there; otherwise use
the owner's protected secret inventory.

For native Google Android/iOS token verification, `GOOGLE_CLIENT_ID` is
required and `GOOGLE_AUDIENCES` may specify the accepted mobile client IDs. A
`GOOGLE_CLIENT_SECRET` is only needed when enabling browser redirect-based
Google OAuth; never reuse a secret from another Google project.
Keep `BOOTSTRAP_ADMIN_PASSWORD` empty. Validate the result before starting any
container:

```bash
sudo bash deploy/vps/scripts/preflight.sh
```

Keep the API worker disabled and the separate worker enabled; this is already
enforced by `docker-compose.yml`.

Create the separate, root-only password used to encrypt the off-site restic
repository. Do not reuse an application secret:

```bash
sudo sh -c 'umask 077; openssl rand -base64 48 > /opt/petmagic/shared/env/restic-password'
```

`PETMAGIC_BACKUP_R2_BUCKET` must reference the private backup bucket. Prefer
dedicated least-privilege credentials in `PETMAGIC_BACKUP_R2_ACCESS_KEY` and
`PETMAGIC_BACKUP_R2_SECRET_KEY`; they must be supplied together. If both are
empty, the backup scripts temporarily fall back to `R2_ACCESS_KEY` and
`R2_SECRET_KEY`, which should only be used when the application key can access
the private backup bucket.
Escrow an encrypted copy of `restic-password` outside the VPS and test its
recovery with the owner's independent private key. Never commit either the
plaintext password or its private decryption key.

Initialize a brand-new restic repository exactly once, after reviewing the R2
account and bucket in the root-only environment file:

```bash
sudo bash deploy/vps/scripts/init-restic-repository.sh --confirm-new-repository
```

The scheduled backup fails closed if that repository cannot be opened. It never
initializes a replacement repository after an authentication, endpoint, bucket,
password, or integrity error.

## Source freeze and exports

Before the final exports, enable Render maintenance mode and keep admin/worker
suspended. Resume only the API long enough to archive `/var/petmagic` with the
archive root set to that directory, then suspend the API again. Create the final
PostgreSQL logical export only after the API is suspended. Record SHA-256 and
size for both files. This keeps database rows and Data Protection keys in one
consistent cutover window.

## Restore order

Never start the full systemd unit before restoring Render. Place the verified
Render database export and persistent-disk archive under
`/opt/petmagic/shared/backups/import`, then run this exact order:

```bash
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml pull postgres mailpit
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml build --pull backend generation-worker admin-web
sudo bash deploy/vps/scripts/restore-render-postgres.sh /opt/petmagic/shared/backups/import/<render-export> <render-export-sha256>
sudo bash deploy/vps/scripts/restore-render-disk.sh /opt/petmagic/shared/backups/import/<render-disk>.tar.gz <render-disk-sha256>
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml up -d backend admin-web
```

Do not start `generation-worker` yet. Verify the API and admin locally:

```bash
curl --fail --silent --show-error --header 'Host: api.petgpt.app' http://127.0.0.1:5001/health
curl --fail --silent --show-error --header 'Host: admin.petgpt.app' http://127.0.0.1:3000/ru >/dev/null
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml exec -T admin-web node -e "fetch('http://backend:5000/health',{headers:{Host:'api.petgpt.app'}}).then(r=>{if(!r.ok)process.exit(1)})"
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml exec -T postgres psql -U petmagic_user -d petmagic_db -c 'SELECT count(*) AS migrations FROM "__EFMigrationsHistory";'
```

Only after database counts, media files, R2 access, and API health pass, start
the single worker and verify its heartbeat:

```bash
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml up -d generation-worker
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml ps
```

After the whole stack has passed the production smoke gate, enable and start the
already installed systemd unit before running the coordinated backup:

```bash
sudo systemctl enable --now petmagic-compose.service
sudo systemctl is-active petmagic-compose.service
sudo systemctl start petmagic-postgres-backup.service
sudo systemctl show petmagic-postgres-backup.service -p Result -p ExecMainStatus
```

A release update must build the new
images from a clean Git checkout before restarting the unit. The VPS override
uses `restart: no`, so Docker cannot restore containers before the systemd
preflight during host boot. The systemd supervisor starts the healthy stack,
monitors every container, and restarts the whole stack through preflight after
an unexpected stop or sustained unhealthy state. It recognizes the coordinated
backup lock as the only maintenance window for API and worker. Runtime preflight
requires each application image to use a commit-scoped tag and carry the
deployed commit in its OCI revision label. The systemd unit is coupled to
`docker.service`, so a controlled Docker restart also re-runs the PetMagic
preflight and start.

Once the root-only read-only GitHub deploy key is installed, use the checked-in
release script instead of copying a release bundle or editing `SOURCE_REVISION`
by hand:

```bash
sudo bash deploy/vps/scripts/deploy-release.sh
```

It fetches `origin/master`, builds only the three application images, restarts
the supervised stack, and verifies runtime image revisions. If any of those
steps fails, it restores the prior Git revision and `SOURCE_REVISION` before
attempting to restart the previous stack. An explicit `--revision <full-sha>`
is allowed only for a commit that is already contained in `origin/master`.
The script refuses a dirty checkout, an active off-site backup, a non-GitHub
origin, or concurrent release.

If repeated failures exhaust the systemd start limit, inspect
`journalctl -u petmagic-compose.service`, correct the cause, then explicitly
recover with `sudo systemctl reset-failed petmagic-compose.service` followed by
`sudo systemctl start petmagic-compose.service`.

After the backup is verified, enable the nightly timer:

```bash
sudo systemctl enable --now petmagic-postgres-backup.timer
```

The off-site job takes a coordinated snapshot: it gracefully pauses the worker
and API, creates the PostgreSQL dump and a verified `api-data` archive, resumes
the services, and only then uploads both artifacts with restic. This avoids a
database/filesystem split-brain backup at the cost of a short API maintenance
window at 03:30 UTC. A dedicated exclusive maintenance lock covers only the
intentional stop/snapshot/resume window; the longer encrypted upload does not
mask unexpected API or worker failures from the systemd supervisor.

Validate Caddy before enabling it:

```bash
sudo install -m 0644 deploy/vps/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Only after the migration smoke checks and explicit owner approval should DNS be
changed and Caddy started with `sudo systemctl enable --now caddy`.

The initial rollback is DNS-only only while the VPS has accepted no writes.
After the first VPS write, switching DNS back to Render requires a reverse data
sync while the VPS is in maintenance; otherwise Render PostgreSQL is stale.
