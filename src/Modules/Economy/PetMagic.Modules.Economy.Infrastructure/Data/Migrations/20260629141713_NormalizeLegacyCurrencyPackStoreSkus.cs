using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeLegacyCurrencyPackStoreSkus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE economy_currency_packs
                SET "Code" = lower(regexp_replace("Code", '^.*\.', ''))
                WHERE "Code" LIKE '%.%';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: legacy dotted SKU values are normalized
            // in-place and the previous source values are not preserved.
        }
    }
}
