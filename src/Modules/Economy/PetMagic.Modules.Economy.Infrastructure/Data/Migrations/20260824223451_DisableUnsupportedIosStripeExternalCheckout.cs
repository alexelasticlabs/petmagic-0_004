using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class DisableUnsupportedIosStripeExternalCheckout : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_payment_provider_configs
                SET "IsEnabled" = FALSE,
                    "IsRecommended" = FALSE,
                    "IsSelectedByDefault" = FALSE,
                    "RequiresExternalWarning" = FALSE,
                    "ExternalCheckoutAllowed" = FALSE,
                    "BonusTokensPercent" = 0,
                    "DisplaySubtitle" = 'Unavailable until Apple external-purchase requirements are implemented.',
                    "WarningTitle" = NULL,
                    "WarningMessage" = NULL,
                    "Notes" = 'Disabled until Apple external-purchase entitlement and transaction-reporting flow are implemented.',
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Provider" = 'stripe'
                  AND "Platform" = 'ios'
                  AND "Notes" IN (
                      'Global Stripe billing route for iOS.',
                      'EU Stripe alternative billing route for iOS.'
                  );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_payment_provider_configs
                SET "IsEnabled" = TRUE,
                    "IsRecommended" = CASE WHEN "Region" = 'EU' THEN TRUE ELSE FALSE END,
                    "IsSelectedByDefault" = CASE WHEN "Region" = 'EU' THEN TRUE ELSE FALSE END,
                    "RequiresExternalWarning" = TRUE,
                    "ExternalCheckoutAllowed" = TRUE,
                    "BonusTokensPercent" = CASE WHEN "Region" = 'EU' THEN 10 ELSE 0 END,
                    "DisplaySubtitle" = CASE
                        WHEN "Region" = 'EU' THEN 'Recommended · secure card payment'
                        ELSE 'Pay securely via Stripe'
                    END,
                    "WarningTitle" = 'Payment via Stripe',
                    "WarningMessage" = CASE
                        WHEN "Region" = 'EU' THEN 'Stripe billing opens in secure Stripe-hosted Checkout. Provider terms and support may differ from App Store or Google Play.'
                        ELSE 'Stripe billing opens in secure Stripe-hosted Checkout. PetMagic updates access after Stripe confirms payment.'
                    END,
                    "Notes" = CASE
                        WHEN "Region" = 'EU' THEN 'EU Stripe alternative billing route for iOS.'
                        ELSE 'Global Stripe billing route for iOS.'
                    END,
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Provider" = 'stripe'
                  AND "Platform" = 'ios'
                  AND "Notes" = 'Disabled until Apple external-purchase entitlement and transaction-reporting flow are implemented.';
                """);
        }
    }
}
