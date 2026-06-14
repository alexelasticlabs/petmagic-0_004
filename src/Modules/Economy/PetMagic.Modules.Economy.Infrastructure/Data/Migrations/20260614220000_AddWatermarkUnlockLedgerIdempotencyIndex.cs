using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Economy.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(EconomyDbContext))]
    [Migration("20260614220000_AddWatermarkUnlockLedgerIdempotencyIndex")]
    public partial class AddWatermarkUnlockLedgerIdempotencyIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "UX_ewl_UserId_Source_Reason_WatermarkUnlock",
                table: "economy_wallet_ledger",
                columns: new[] { "UserId", "Source", "Reason" },
                unique: true,
                filter: "\"Source\" = 'watermark_unlock'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_ewl_UserId_Source_Reason_WatermarkUnlock",
                table: "economy_wallet_ledger");
        }
    }
}
