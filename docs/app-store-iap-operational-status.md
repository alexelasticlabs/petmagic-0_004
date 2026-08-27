# App Store In-App Purchase operational status

Last verified: 2026-08-27.

## Confirmed configuration

- TestFlight build `1.0.0 (22)` is available through the App Store Connect API.
- The iOS checkout API exposes the expected StoreKit products:
  - `com.petmagic.app.premium.monthly`
  - `com.petmagic.app.premium.yearly`
  - `com.petmagic.app.tokens.apple.starter`
  - `com.petmagic.app.tokens.apple.creator`
  - `com.petmagic.app.tokens.apple.viral`
- Each product has a configured price and one `en-US` product localization.
- The customer-facing `en-US` subscription group localization `Pet Video Magic Premium` was created through the protected production workflow.
- The iOS backend configuration exposes only the App Store purchase route. Stripe is intentionally disabled on iOS; it remains an Android/web route.

## Blocking App Store configuration

All five StoreKit products are currently `MISSING_METADATA`. The App Store Connect API confirms that every product is missing its App Review screenshot. Apple requires this screenshot to show the actual offered item or service; it is review-only and is not a product-page image.

Do not use a generated placeholder or an unrelated marketing asset. Capture real screens from the TestFlight build showing:

1. the Premium monthly offer;
2. the Premium yearly offer;
3. the Starter token pack;
4. the Creator token pack;
5. the Viral token pack.

Upload each screenshot to its matching App Store Connect product. Then wait for App Store sandbox propagation and test a StoreKit Sandbox purchase, cancellation, restore, and backend reconciliation on a physical iPhone.

## Stripe policy boundary

Premium access and PawSpark token packs are digital goods. The current iOS application must use Apple In-App Purchase for those flows. Enabling the existing Stripe option in all iOS storefronts is not a safe fix and can create App Review risk. Any future external-purchase path needs a separate storefront-by-storefront policy and entitlement review before implementation.

