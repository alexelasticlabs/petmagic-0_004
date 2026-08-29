# PetMagic first-time hosting guide

This guide describes the current PetMagic hosting model: one dedicated VPS with
Docker Compose, Caddy, PostgreSQL, and an isolated payment-staging project. It
is intentionally provider-neutral; the active production server is documented
in [`deploy/vps/README.md`](../deploy/vps/README.md).

## Target topology

| Component | Location | Public |
| --- | --- | --- |
| API | Docker Compose on the VPS, Caddy reverse proxy | `https://api.petgpt.app` |
| Admin web | Docker Compose on the VPS, Caddy reverse proxy | `https://admin.petgpt.app` |
| Generation worker | one Compose worker on the VPS | no |
| PostgreSQL | Compose volume on the VPS | no |
| Media | Cloudflare R2 | through application/public media URLs only |
| Email | Resend SMTP | no |
| Payment staging | separate Compose project on the VPS | `https://api.staging.petgpt.app` |

Do not expose PostgreSQL, Docker ports, the admin container port, or Mailpit to
the Internet. Caddy is the only public entry point.

## What to obtain before the first server

1. A dedicated VPS with enough RAM and disk for PostgreSQL, three application
   containers, backups, and image builds. Keep it separate from unrelated
   applications.
2. A domain controlled in Cloudflare. The current production names are
   `petgpt.app`, `api.petgpt.app`, and `admin.petgpt.app`.
3. A GitHub deploy key with read-only access only to `alexelasticlabs/petmagic-0_004`.
4. Cloudflare R2 media and backup buckets with separate least-privilege keys.
5. Provider accounts and production credentials for fal.ai, Resend, Firebase,
   Stripe, Google Play, and App Store Connect.
6. An owner-controlled encrypted escrow copy of the restic password. It must
   not reside only on the VPS.

## One-time server setup

Follow the bootstrap section of [`deploy/vps/README.md`](../deploy/vps/README.md).
At minimum:

1. Install Docker Engine, Docker Compose, Caddy, UFW, restic, and PostgreSQL
   client tools.
2. Allow only SSH, HTTP, and HTTPS through UFW.
3. Clone the repository to `/opt/petmagic/current` with the root-only deploy
   key; do not use a personal developer SSH key for unattended releases.
4. Install the checked-in systemd units.
5. Create `/opt/petmagic/shared/env/.env.vps` from
   `deploy/vps/.env.vps.example`, with `root:root` ownership and mode `0600`.
6. Install and validate `deploy/vps/Caddyfile` before enabling Caddy.
7. Run `preflight.sh`, then start the supervisor and backup timer.

Do not paste secrets into a terminal history or commit them into the repository.

## DNS and TLS

Create DNS-only Cloudflare records pointing to the VPS public IP:

| Name | Type | Target |
| --- | --- | --- |
| `api.petgpt.app` | A | VPS public IP |
| `admin.petgpt.app` | A | VPS public IP |
| `api.staging.petgpt.app` | A | VPS public IP |

Validate Caddy after the records resolve, then check HTTPS from outside the
server. Do not proxy a partially configured origin or change production DNS
while restore, preflight, or public smoke checks are failing.

## Normal deployment

Every production update follows the same sequence:

```text
local validation -> commit on master -> push -> VPS deploy-release.sh -> public smoke -> monitor
```

On the VPS, use only:

```bash
sudo bash /opt/petmagic/current/deploy/vps/scripts/deploy-release.sh
```

The release script validates the protected environment, requires a clean
checkout, builds commit-labelled images, restarts the supervised stack, and
rolls back the checkout/source revision if the release fails. It is the only
supported deployment command.

## Isolated payment staging

Payment testing is separate from production:

- host: `api.staging.petgpt.app`;
- separate PostgreSQL volume, application data paths, JWT, Stripe test keys,
  and webhook secret;
- no production database, R2, SMTP, Firebase, OAuth, fal.ai, or store
  credentials;
- Mailpit is local-only and the staging email worker is disabled.

Use staging for Stripe test cards and webhook tests. Use Google Play Internal
testing and TestFlight/App Store Sandbox for store payments; do not attempt to
simulate their provider flows by pointing them at production Stripe.

## Provider setup checklist

| Provider | Production responsibility | Acceptance that remains separate |
| --- | --- | --- |
| Cloudflare | DNS, R2 media, private backup bucket | media upload/read and backup restore |
| Resend | SMTP sender and DNS records | delivery and bounce monitoring |
| Stripe | live catalog/webhook and isolated staging catalog/webhook | staging success/cancel/retry/refund/replay |
| Google Play | Android signing, Internal track, purchase verification | licensed tester purchase/consume/replay/restore |
| Apple | signing, TestFlight, StoreKit catalog, notification route | iPhone Apple Sign In and Sandbox purchase/restore |
| Firebase | Android/iOS configuration and server credentials | visible FCM/APNs notification on devices |
| fal.ai | dedicated VPS key and provider callback | controlled generation/callback/R2 canary |

Track only completed evidence in [`release-readiness.md`](release-readiness.md).

## Daily operating rules

- Check `/health`, systemd status, and bounded logs before restarting anything.
- Deploy only a reviewed `master` revision through `deploy-release.sh`.
- Keep exactly one generation worker unless capacity evidence and a reviewed
  architecture change justify another one.
- Review backup timer runs and perform isolated restore tests periodically.
- Do not use a public provider dashboard or a green build as proof that a
  mobile/device/payment flow works.
- Record provider acceptance and operational incidents in the release-readiness
  document so a new task has one reliable current source.
