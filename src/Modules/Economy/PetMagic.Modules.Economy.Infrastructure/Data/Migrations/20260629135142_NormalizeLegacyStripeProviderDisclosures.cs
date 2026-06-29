using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeLegacyStripeProviderDisclosures : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_payment_provider_configs
                SET "WarningTitle" = NULL
                WHERE lower("Provider") = 'stripe'
                  AND btrim(COALESCE("WarningTitle", '')) = '';

                UPDATE economy_payment_provider_configs
                SET "WarningMessage" = NULL
                WHERE lower("Provider") = 'stripe'
                  AND btrim(COALESCE("WarningMessage", '')) = '';

                UPDATE economy_payment_provider_configs
                SET "Notes" = NULL
                WHERE lower("Provider") = 'stripe'
                  AND btrim(COALESCE("Notes", '')) = '';

                UPDATE economy_payment_provider_configs
                SET "WarningMessage" = NULL,
                    "Notes" = NULL
                WHERE lower("Provider") = 'stripe'
                  AND (
                    lower(COALESCE("WarningMessage", '')) LIKE '%stripe checkout%'
                    OR lower(COALESCE("WarningMessage", '')) LIKE '%continue to stripe%'
                    OR lower(COALESCE("Notes", '')) LIKE '%external checkout%'
                  );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
