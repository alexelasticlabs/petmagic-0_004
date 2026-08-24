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
- [x] A root-only GitHub read-only deploy key now backs the VPS `origin`.
      The controlled `deploy-release.sh` path fetched `master`, built and
      deployed source revision `92c202369b7a8dde54c9ac441da41433e1d04668`;
      its runtime preflight and the public health check both passed.
- [x] Caddy, the Compose supervisor, PostgreSQL, API, admin web and exactly
      one generation worker are healthy. Public `api.petgpt.app/health` and
      `admin.petgpt.app/ru` return HTTP 200 over HTTPS.
- [x] Public TLS and edge headers were rechecked on 2026-08-24: `petgpt.app`,
      `admin.petgpt.app`, and `api.petgpt.app` present valid certificates and
      enforce HSTS, CSP, `nosniff`, and frame protection. Certificate expiry is
      no earlier than 2026-10-28; automated renewal still needs normal
      operational monitoring.
- [x] A stale exhausted `identity_email` job addressed to the reserved
      `example.com` test domain was removed after its SMTP failure was
      confirmed isolated from customer traffic. Fresh `/health` reports all
      notification queues healthy. The sole remaining overall `Degraded`
      signal is the intentional `store_account_binding=compatibility` release
      gate; do not switch it to `enforce` before real store-purchase evidence.
- [x] The 2026-08-24 economy rollout migration
      `20260824155159_AlignPremiumAllowanceAndTestPackPrices` is applied on the
      VPS. Live database verification reports `40` for monthly and yearly
      Premium allowance and `0.99`/`1.49`/`1.99` for the starter/creator/viral
      USD and EUR test packs. This is database acceptance, not provider charge
      acceptance.
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
      returns HTTP 200, a deliberately invalid native token is rejected with
      the expected authentication error, and a real Google-account login on a
      Play-installed physical Android device completed successfully through
      `/api/auth/me`.
- [x] The Play-distribution signing certificate matches the production Android
      OAuth client in the same Google project. This is configuration evidence,
      not a successful account sign-in.
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
- [x] Android `1.0.0+3` was built, signed, archived and uploaded to Play
      Internal by run `32698746633`. It contains corrected mobile auth feedback
      and production API routing.
- [x] A Play-installed Android `1.0.0+3` reached the VPS API. The email login
      request was rejected as `invalid_credentials`; the native Google SDK
      loaded the server configuration but did not reach the token-exchange
      endpoint. This is diagnostic evidence, not authentication acceptance.
- [x] Android `1.0.0+4` was built, signed, archived and uploaded to Play
      Internal by run `32701367339`. A physical device installed build `4`,
      which still displayed an offline error before opening the Google account
      selector despite direct HTTPS health evidence from that same device.
- [x] Android `1.0.0+5` was installed on a physical device. The VPS accepted
      a verified email/password request (`HTTP 200`), but the client did not
      make the subsequent `/api/auth/me` request; the native Google SDK also
      did not reach the token exchange. This is diagnostic evidence, not
      authentication acceptance.
- [x] Android `1.0.0+6` preserves an authenticated session in
      memory when Android secure-storage persistence stalls, bounds Google SDK
      cleanup, and gives the PetMagic API reachability probe realistic mobile
      timeouts. Run `32706661084` built, signed, archived and uploaded it to
      Play Internal; physical-device acceptance is pending.
- [x] Android `1.0.0+12` was built and uploaded to Play Internal by run
      `32722408718` from commit
      `01d92a177858fcf130f9e692d916146c4f4ffa77`; the physical Samsung device
      has `versionCode=12` installed. Cold start restored authentication and
      loaded server-backed wallet/UI state without a server-unavailable result.
- [x] Android `1.0.0+13` guards deferred `TemplatesPage` Riverpod access after
      unmount. Run `32728145852` built and uploaded it successfully from commit
      `dfa47dffde8a28e66400203622f50d0e625edf8a`; the Play-installed physical
      device confirms `versionCode=13`. Repeated account transitions exposed a
      separate provider-rebuild failure, so this is release evidence rather
      than final lifecycle acceptance.
- [x] Android `1.0.0+14` allows `TemplatesController` lifecycle collaborators
      to be reconstructed after a session-scope provider invalidation. Run
      `32730528049` built, archived and uploaded it from commit
      `30626279b24c2a5f4c8733fc55c10390f00b70a6` in 10m20s. The Play-installed
      physical device confirms `versionCode=14`; logout-to-guest,
      guest-to-Google, repeated authenticated navigation, background/foreground
      and cold restart passed without a fallback screen, targeted log error or
      native crash. The VPS completed Google native auth and `/api/auth/me`
      with HTTP 200. A short post-restart Crashlytics observation retained only
      the five existing build-13 events and showed no build-14 event; continue
      monitoring for delayed ingestion.
- [x] Android `1.0.0+15` was built and signed locally after GitHub-hosted run
      `32767419162` was rejected before its first step by the account billing or
      Actions spending-limit gate. The AAB SHA-256 is
      `098D568155BC3F3F981D446D90D463A59F5E9FAC01003A3D59F7FE8E0A34AC5D`.
      Android Publisher API upload and a separate API read confirm Internal
      release `1.0.0 (15)`, status `completed`, version code `15`. The hosted
      Gradle tuning remains unverified until the GitHub account-level block is
      resolved; physical-device install and payment acceptance are still pending.
- [ ] Repair the independent iOS CI signing configuration before TestFlight:
      Firebase iOS configuration and its App ID are now protected GitHub
      `production` secrets. App Store Connect API access is now approved. A
      dedicated private `petmagic-ios-signing` Match repository, repository-only
      deploy key and protected `MATCH_*` inputs are configured. The team API key
      and first Match bootstrap still have to be completed before TestFlight.
- [ ] Prove a real signed Stripe delivery and a real signed App Store Sandbox
      notification. Provider endpoint configuration is verified, but delivery
      and signature acceptance are not yet evidenced.
- [ ] Accept the native Stripe PaymentSheet release. The VPS backend now
      returns PaymentIntent or Subscription invoice
      client secrets for eligible Android checkout, keeps hosted Checkout as
      the iOS/web fallback,
      and uses an idempotency key for mobile subscription creation. Flutter
      regression tests, backend gateway tests, a production-flavor debug APK and
      a minified production release AAB pass locally. Android `1.0.0+15` is active
      on Play Internal; its device install, Stripe test-mode payment, webhook
      reconciliation and cancellation/retry proof are still required.
- [ ] Run real-provider acceptance: Sign in with Apple, FCM/APNs on a physical
      iOS device, Stripe Checkout/webhook reconciliation, App Store Sandbox
      purchase/restore/refund or cancellation lifecycle, and idempotent token
      crediting.
- [ ] Complete Google Play sandbox acceptance. The service account has verified
      PetMagic app and billing access: OAuth succeeds and the purchase API
      reaches its expected validation path for a synthetic token. Catalog-list
      access remains intentionally unavailable because `Manage store presence`
      is not required for backend purchase verification and is not granted.
- [x] Google Play contains active monthly and yearly Premium subscription
      products with active base plans and regional availability. No tester
      offer was created without an approved product decision; sandbox purchase,
      renewal, restore, cancellation/refund and backend-crediting acceptance
      remain pending.
- [ ] Deploy and accept the approved Premium entitlement before a public
      release. The owner chose `40 PawSpark` at purchase and every seven days
      while Premium remains active. Local plan defaults, health checks,
      migration and mobile copy now match that decision, and clean/existing DB
      migration checks pass. The VPS migration and live database values are
      confirmed aligned; active Google Play/App Store/Stripe product copy and a
      real sandbox renewal/cancellation lifecycle remain pending before public
      charging.
- [ ] Complete native Google Play acceptance on an eligible internal tester.
      The Internal track is active with completed release `1.0.0 (15)` and a
      tester list, but the attached device did not expose a purchasable Google
      Play option while Stripe remained available. The Play **One-time
      products** catalog now has active standard **Buy** products matching the
      VPS-derived IDs: `starter` at USD 0.99, `creator` at USD 1.49, and `viral`
      at USD 1.99. Verify
      Play-country/license-test eligibility, then purchase, verify, credit and
      consume each product exactly once before any public charge.
- [x] The **Play app signing** SHA-1 certificate matches the Android OAuth
      client in the Firebase/Google project. The separate upload certificate is
      not used for Google Sign-In configuration.
- [ ] Populate the template catalog with approved content. Read-only counts on
      both production VPS PostgreSQL and the retained Render PostgreSQL source
      are currently zero template items, zero categories and zero assets, so
      the empty mobile catalog is not a migration loss.
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
