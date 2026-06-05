using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Economy.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(EconomyDbContext))]
    [Migration("20260604214500_AddEconomyStripeDiagnosticsIndexes")]
    public partial class AddEconomyStripeDiagnosticsIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_UserId_PaymentProvider_CreatedAtUtc",
                table: "economy_purchase_orders",
                columns: new[] { "UserId", "PaymentProvider", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_esel_UserId_Provider_CreatedAtUtc",
                table: "economy_subscription_event_logs",
                columns: new[] { "UserId", "Provider", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_economy_purchase_orders_UserId_PaymentProvider_CreatedAtUtc",
                table: "economy_purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_esel_UserId_Provider_CreatedAtUtc",
                table: "economy_subscription_event_logs");
        }
    }
}
