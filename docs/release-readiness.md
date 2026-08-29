# PetMagic release readiness

Last verified: **2026-08-27**. This is a current-state checklist, not a change
log. Record an item as complete only with direct provider, device, or VPS
evidence; configuration and local tests are not substitutes.

## Production platform

Production runs on the dedicated OVH VPS `vps-fea3ac06` (Ubuntu 26.04 LTS).
The canonical operator runbook is
[`deploy/vps/README.md`](../deploy/vps/README.md).

| Component | Current state | Evidence boundary |
| --- | --- | --- |
| Caddy and TLS | operational | `api.petgpt.app` and `admin.petgpt.app` return HTTP 200 over HTTPS |
| Compose supervisor | operational | `petmagic-compose.service` active; API, admin, worker, PostgreSQL, and internal Mailpit healthy |
| Deployed source | `61bc60724176193f72dbe1dc1e9a8970a2995b5d` | verified on the VPS; deploy only through `deploy-release.sh` |
| Database and persistent data | operational | PostgreSQL and API-data paths are on the VPS; backup/restore evidence exists |
| Backups | operational | nightly `petmagic-postgres-backup.timer`, encrypted restic repository in dedicated R2 storage |
| Production email | operational | Resend SMTP is the delivery provider; Mailpit is not used for customer email |
| Media and generation | operational | R2 storage and fal.ai provider health are healthy; one worker is active |

`GET https://api.petgpt.app/health` currently returns overall `Degraded` only
because `STORE_ACCOUNT_BINDING_MODE=compatibility`. This is intentional until
store-account binding has real Google Play and App Store evidence.

## Mobile release and authentication

| Surface | Current state | Still required |
| --- | --- | --- |
| Android | `1.0.0+22` is signed, uploaded to Play Internal, and installed through Google Play | store-purchase lifecycle on a licensed tester account |
| Android API and Google auth | device reached the VPS; native account chooser and backend session creation were observed | owner acceptance of terms/privacy and authenticated workspace pass |
| iOS signing | Match and App Store Connect API key completed signed archive and upload | physical iPhone acceptance |
| TestFlight | App Store Connect API exposes `1.0.0 (22)` | create/invite a TestFlight group, install, then test on device |
| Sign in with Apple | client ID, audience, and server JWT are configured | real authorization-code exchange on iPhone |
| Push | Firebase registration/outbox configuration is healthy | visible FCM and APNs delivery on physical devices |

## Billing and catalog

| Provider | Configuration state | Still required |
| --- | --- | --- |
| Stripe | production live endpoint and separate VPS staging test endpoint configured | real staging cancel/retry/refund/renewal and signed webhook lifecycle |
| Google Play | subscriptions and one-time products active; verification credentials authorized | licensed Internal tester purchase, backend verification, consume, replay, and restore |
| App Store | subscriptions and consumables configured; notification destinations configured | StoreKit Sandbox purchase, Premium activation, backend crediting, restore, and signed notification |

Current test catalog:

- Premium: monthly USD 0.99 and yearly USD 1.99.
- Token packs: starter USD 0.99, creator USD 1.49, viral USD 1.99.
- Premium grants 40 PawSpark at activation and every seven days while active.

On iOS, App Store Billing is the only in-app route. External Stripe checkout is
disabled there until a separate compliant Apple entitlement and implementation
exist. Android uses native Google Play billing for its store products and a
native Stripe PaymentSheet only in the appropriate Stripe flow.

## Required device acceptance

Use distinct test accounts and preserve screenshots/provider event IDs without
recording secrets. The detailed scenarios are in
[`payments-sandbox-checklist.md`](payments-sandbox-checklist.md).

- [ ] Google Play: purchase one token pack and Premium as a license tester;
  verify exactly-once credit, consume, cancellation, restart/recovery, and
  subscription state.
- [ ] App Store: install `1.0.0 (22)` through TestFlight; use a Sandbox Apple
  Account to test token pack, Premium, restore, cancellation, and notification.
- [ ] Stripe staging: complete success, cancel, retry, refund, and webhook
  replay tests with test-mode credentials only.
- [ ] Apple Sign In and APNs: verify on a real iPhone.
- [ ] FCM: verify foreground and background delivery on a real Android device.
- [ ] fal.ai: run one controlled generation/callback/R2-import canary before
  charging users for generation.

## Release rules

1. Never move `STORE_ACCOUNT_BINDING_MODE` to `enforce` before both stores pass
   purchase, restore, replay, mismatch, and new-account binding scenarios.
2. Never use production Stripe keys or a real card for a payment test. Use the
   isolated staging environment and Stripe test mode.
3. Never put provider keys, service-account JSON, `.p8` files, keystores,
   database URLs, or the VPS environment file in Git, Markdown, logs, or chat.
4. A green CI workflow, public `/health`, or provider dashboard configuration is
   not production acceptance by itself.
5. Update this file after a verified acceptance result; preserve a clear
   `pending` entry when the provider or device step was not actually run.

## Canonical references

- [`deploy/vps/README.md`](../deploy/vps/README.md) — production operations,
  deploy, backups, and isolated payment staging.
- [`payments-sandbox-checklist.md`](payments-sandbox-checklist.md) — evidence
  required for each payment provider.
- [`API contracts`](api-contracts.md), [`security`](security.md), and
  [`notifications`](notifications-contract.md) — cross-stack behaviour and
  secret-handling rules.
- [`mobile-build-automation.md`](mobile-build-automation.md) — self-hosted Mac
  runner and mobile release automation.
