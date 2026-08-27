using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class EnableIosStripeForUsAndEuStorefronts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_payment_provider_configs
                SET "IsEnabled" = TRUE,
                    "IsRecommended" = FALSE,
                    "IsSelectedByDefault" = FALSE,
                    "RequiresExternalWarning" = TRUE,
                    "RequiresStoreDisclosure" = TRUE,
                    "AllowedFromAppVersion" = '1.0.0',
                    "ExternalCheckoutAllowed" = TRUE,
                    "BonusTokensPercent" = 0,
                    "DisplayLabel" = 'Stripe',
                    "DisplaySubtitle" = 'Secure payment form inside PetMagic.',
                    "WarningTitle" = 'Pay with Stripe',
                    "WarningMessage" = 'Stripe payment opens in a secure payment form inside PetMagic. Provider terms and support may differ from App Store.',
                    "Notes" = CASE
                        WHEN "Region" = 'EU' THEN 'Owner-approved Stripe alternative billing route for iOS in EU storefronts.'
                        ELSE 'Owner-approved Stripe alternative billing route for the iOS US storefront.'
                    END,
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Provider" = 'stripe'
                  AND "Platform" = 'ios'
                  AND "Region" IN ('EU', 'US');
                """);

            migrationBuilder.Sql(
                """
                INSERT INTO economy_payment_provider_configs (
                    "Id", "AllowedFromAppVersion", "BonusTokensPercent", "CreatedAtUtc",
                    "DisplayLabel", "DisplaySubtitle", "ExternalCheckoutAllowed", "IsEnabled",
                    "IsRecommended", "IsSelectedByDefault", "Mode", "Notes", "Platform",
                    "Provider", "Region", "RequiresExternalWarning", "RequiresStoreDisclosure",
                    "UpdatedAtUtc", "WarningMessage", "WarningTitle")
                SELECT
                    'c3a4ad30-06e1-4882-af90-d02d77414ff6'::uuid,
                    '1.0.0', 0, CURRENT_TIMESTAMP,
                    'Stripe', 'Secure payment form inside PetMagic.', TRUE, TRUE,
                    FALSE, FALSE, source."Mode",
                    'Owner-approved Stripe alternative billing route for the iOS US storefront.',
                    'ios', 'stripe', 'US', TRUE, TRUE, CURRENT_TIMESTAMP,
                    'Stripe payment opens in a secure payment form inside PetMagic. Provider terms and support may differ from App Store.',
                    'Pay with Stripe'
                FROM (
                    SELECT "Mode"
                    FROM economy_payment_provider_configs
                    WHERE "Provider" = 'stripe'
                      AND "Platform" = 'ios'
                      AND "Region" IN ('EU', '*')
                    ORDER BY CASE WHEN "Region" = 'EU' THEN 0 ELSE 1 END
                    LIMIT 1
                ) AS source
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM economy_payment_provider_configs
                    WHERE "Provider" = 'stripe'
                      AND "Platform" = 'ios'
                      AND "Region" = 'US');
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DELETE FROM economy_payment_provider_configs
                WHERE "Id" = 'c3a4ad30-06e1-4882-af90-d02d77414ff6'::uuid;

                UPDATE economy_payment_provider_configs
                SET "IsEnabled" = FALSE,
                    "IsRecommended" = FALSE,
                    "IsSelectedByDefault" = FALSE,
                    "RequiresExternalWarning" = FALSE,
                    "ExternalCheckoutAllowed" = FALSE,
                    "BonusTokensPercent" = 0,
                    "DisplaySubtitle" = 'Not available in this storefront.',
                    "WarningTitle" = NULL,
                    "WarningMessage" = NULL,
                    "Notes" = 'Disabled outside the approved US and EU storefronts.',
                    "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Provider" = 'stripe'
                  AND "Platform" = 'ios'
                  AND "Region" = 'EU';
                """);
        }
    }
}
