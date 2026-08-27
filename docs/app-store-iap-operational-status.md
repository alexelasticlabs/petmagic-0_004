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
- The protected catalog workflow creates the same customer-facing group name for the supported application locales. App Store Connect accepts `de-DE`, `es-ES`, and `fr-FR`; its required shortcodes for the remaining locales are `it` and `pl` (not `it-IT`/`pl-PL`). The next protected workflow run will verify all six configured locales: `en-US`, `de-DE`, `es-ES`, `fr-FR`, `it`, `pl`.

## Blocking App Store configuration

All five StoreKit products are currently `MISSING_METADATA`. The App Store Connect API confirms that every product is missing its App Review screenshot. Apple requires this screenshot to show the actual offered item or service; it is review-only and is not a product-page image.

Do not use a generated placeholder or an unrelated marketing asset. Capture real screens from the TestFlight build showing:

1. the Premium monthly offer;
2. the Premium yearly offer;
3. the Starter token pack;
4. the Creator token pack;
5. the Viral token pack.

Upload each screenshot to its matching App Store Connect product. Then wait for App Store sandbox propagation and test a StoreKit Sandbox purchase, cancellation, restore, and backend reconciliation on a physical iPhone.

## iOS Stripe storefront policy

Product-owner decision recorded on 2026-08-27: users in the United States and
the 27 European Union storefronts may choose either App Store Billing or Stripe
for Premium and PawSpark purchases. Stripe is a separate option, not the
default; the application must keep both choices visible and require any
provider-specific disclosures supplied by the API.

The backend policy uses precise `US` and `EU` routes. `EU` matches `AT`, `BE`,
`BG`, `HR`, `CY`, `CZ`, `DK`, `EE`, `FI`, `FR`, `DE`, `GR`, `HU`, `IE`, `IT`,
`LV`, `LT`, `LU`, `MT`, `NL`, `PL`, `PT`, `RO`, `SK`, `SI`, `ES`, and `SE`.
The global iOS Stripe route remains disabled, so Stripe is not exposed in other
storefronts by fallback. iOS Stripe uses the native Stripe `PaymentSheet`, not
a browser checkout.

This is a product policy and source configuration change. It becomes live only
after the corresponding VPS release and API checks for `US` plus an EU country
confirm both `app_store` and `stripe` payment methods.
