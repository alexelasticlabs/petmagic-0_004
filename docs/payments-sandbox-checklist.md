# Payments and FCM sandbox checklist

This checklist defines evidence required before production release for token packs, subscriptions, store purchases and push notifications.

## Required credentials

- Stripe test secret key and webhook secret.
- Stripe test products/prices for token packs and subscriptions.
- Google Play test app, package name, billing products, license tester account, service account access.
- App Store sandbox app, bundle id, product ids, sandbox Apple ID, App Store Server API/signing setup.
- Firebase project id and FCM service account JSON/path.
- Real Android device for Google Play and FCM.
- Real iOS device or simulator/device setup that can perform StoreKit/App Store sandbox validation.

## Stripe token pack

Evidence to capture:

- Mobile creates order through `POST /api/economy/purchases/create`.
- Stripe checkout opens.
- Payment succeeds in Stripe test mode.
- Stripe webhook reaches backend.
- Purchase becomes `Succeeded`.
- Wallet balance increases once.
- Ledger has exactly one `pack_purchase` credit.
- Replayed webhook is ignored and does not create a second credit.
- Mobile refresh shows updated balance.
- Admin purchases list shows the order.

Status: `needs verification` until run with Stripe sandbox credentials.

## Stripe subscription

Evidence to capture:

- Mobile starts subscription checkout.
- Stripe webhook reaches backend.
- Premium status becomes active.
- Subscription allowance is granted once.
- Replayed webhook does not duplicate entitlement or tokens.
- Cancel/expiration changes premium state.
- Mobile premium screen reflects the new state.
- Admin subscription event log shows the lifecycle.

Status: `needs verification` until run with Stripe sandbox credentials.

## Google Play token pack

Evidence to capture:

- Android wallet UI shows Google Play/native purchase path when configured.
- Purchase completes with a license tester.
- Play purchase carries the authenticated PetMagic user through `obfuscatedAccountId`.
- Backend `verify-store` confirms the purchase.
- An unacknowledged purchase is accepted and credited exactly once.
- The token pack remains unconsumed until backend verification succeeds, then Android consume succeeds before local pending state is cleared.
- Wallet balance increases once.
- Receipt replay does not duplicate credit.
- A mismatched binding returns `economy.store_account_binding_mismatch`.
- A new unbound transaction returns `economy.store_account_binding_missing` in `enforce` mode; a legacy transaction already owned by the same user can still be restored.
- Pending purchase survives app restart.
- Restore/recovery works after reinstall or local order loss.
- Admin purchase appears with provider `google_play`.

Status: `needs verification` until Android device, Play Console setup and tester account are available.

## App Store token pack

Evidence to capture:

- iOS wallet UI shows App Store/native purchase path when configured.
- Sandbox purchase completes.
- StoreKit purchase carries the authenticated PetMagic user through `appAccountToken`.
- Backend `verify-store` confirms the purchase.
- Wallet balance increases once.
- Receipt/server event replay does not duplicate credit.
- Mismatched, new-unbound and same-user legacy restore cases follow the same binding policy as Google Play.
- Restore/recovery works after reinstall or local order loss.
- Admin purchase appears with provider `app_store`.

Status: `needs verification` until App Store sandbox setup and test device/account are available.

## FCM

Evidence to capture on a real device:

- generation completion push is received;
- wallet/purchase push is received;
- support chat push is received;
- tapping push opens the expected safe route;
- foreground message renders once;
- dedupe key prevents duplicate UI messages;
- invalid token is disabled by backend sender after FCM rejection.

Status: `needs verification` until Firebase credentials and real device session are available.

## Mobile wallet UI

Manual checks:

- token packs render with expected price/currency/bonus;
- Stripe path is visible when configured;
- Google Play/App Store path is visible when configured;
- disabled payment methods are hidden or explained;
- double submit is blocked;
- checkout close/cancel leaves a clear pending or recoverable state;
- backend verify failure shows an actionable error;
- balance refreshes after success;
- pending store purchase is recovered after app restart.

## Release gate

Production release requires attaching evidence for every checked item. If an external dependency is unavailable, record `needs verification`, the missing credential/device/account, and the exact scenario that remains unverified.

Keep `STORE_ACCOUNT_BINDING_MODE=compatibility` while the backend fix and bound mobile client roll out. Change production to `enforce` only after Google Play and App Store purchase, restore, replay, mismatch and new-unbound sandbox evidence is attached. A production deployment must not perform this switch implicitly.

While production remains in `compatibility`, `/health` reports `store_account_binding` as `Degraded` with the required remediation. Treat that status as a release follow-up, not as permission to keep compatibility enabled indefinitely.
