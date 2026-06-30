using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeLegacyRedeemCodeWindows : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_redeem_codes
                SET "StartsAtUtc" = NULL
                WHERE "StartsAtUtc" IS NOT NULL
                  AND "StartsAtUtc" <= TIMESTAMPTZ '1970-01-01 00:00:00+00';

                UPDATE economy_redeem_codes
                SET "ExpiresAtUtc" = NULL
                WHERE "ExpiresAtUtc" IS NOT NULL
                  AND "ExpiresAtUtc" <= TIMESTAMPTZ '1970-01-01 00:00:00+00';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: sentinel legacy window timestamps are
            // collapsed to NULL and the old invalid values are not retained.
        }
    }
}
