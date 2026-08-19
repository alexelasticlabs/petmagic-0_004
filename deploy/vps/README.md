# PetMagic VPS deployment

This directory defines the production runtime for the OVH VPS. It keeps the
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

Populate every `__REQUIRED__` value directly from the existing Render
production configuration, without printing secret values in logs or chat.
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

`PETMAGIC_BACKUP_R2_BUCKET` must reference the private backup bucket. The R2
credentials must be able to access it; prefer a dedicated least-privilege key.
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
sudo bash /opt/petmagic/current/deploy/vps/scripts/backup-offsite.sh
```

Only after database counts, media files, R2 access, and API health pass, start
the single worker and verify its heartbeat:

```bash
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml up -d generation-worker
sudo docker compose --env-file /opt/petmagic/shared/env/.env.vps -f docker-compose.yml -f deploy/vps/compose.vps.yaml ps
```

After the whole stack has passed the production smoke gate, install and enable
the systemd unit for subsequent reboots. A release update must build the new
images from a clean Git checkout before restarting the unit. The VPS override
uses `on-failure` rather than `unless-stopped`, so Docker does not bypass the
systemd preflight during host boot. Runtime preflight also requires each
application image to use a commit-scoped tag and carry the deployed commit in
its OCI revision label. The systemd unit is coupled to `docker.service`, so a
controlled Docker restart also re-runs the PetMagic preflight and start.

After the backup is verified, enable the nightly timer:

```bash
sudo systemctl enable --now petmagic-postgres-backup.timer
```

The off-site job takes a coordinated snapshot: it gracefully pauses the worker
and API, creates the PostgreSQL dump and a verified `api-data` archive, resumes
the services, and only then uploads both artifacts with restic. This avoids a
database/filesystem split-brain backup at the cost of a short API maintenance
window at 03:30 UTC.

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
