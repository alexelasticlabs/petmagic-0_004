using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationRefundLedgerIdempotencyIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "UX_ewl_UserId_Reason_GenerationRefund",
                table: "economy_wallet_ledger",
                columns: new[] { "UserId", "Reason" },
                unique: true,
                filter: "\"Source\" = 'generation_refund'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_ewl_UserId_Reason_GenerationRefund",
                table: "economy_wallet_ledger");
        }
    }
}
