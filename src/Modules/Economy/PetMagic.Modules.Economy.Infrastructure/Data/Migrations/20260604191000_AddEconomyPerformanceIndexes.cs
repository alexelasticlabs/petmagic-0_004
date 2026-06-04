using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddEconomyPerformanceIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_ledger_CreatedAtUtc",
                table: "economy_wallet_ledger",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_ledger_Source_CreatedAtUtc",
                table: "economy_wallet_ledger",
                columns: new[] { "Source", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_CreatedAtUtc",
                table: "economy_purchase_orders",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_Status_CreatedAtUtc",
                table: "economy_purchase_orders",
                columns: new[] { "Status", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_codes_CreatedAtUtc",
                table: "economy_redeem_codes",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_RedeemedAtUtc",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "RedeemCodeId", "RedeemedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_UpdatedAtUtc",
                table: "economy_user_subscriptions",
                column: "UpdatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_Status_UpdatedAtUtc",
                table: "economy_user_subscriptions",
                columns: new[] { "Status", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_Provider_UpdatedAtUtc",
                table: "economy_user_subscriptions",
                columns: new[] { "Provider", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_event_logs_CreatedAtUtc",
                table: "economy_subscription_event_logs",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_event_logs_Provider_Status_CreatedAtUtc",
                table: "economy_subscription_event_logs",
                columns: new[] { "Provider", "Status", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_economy_wallet_ledger_CreatedAtUtc",
                table: "economy_wallet_ledger");

            migrationBuilder.DropIndex(
                name: "IX_economy_wallet_ledger_Source_CreatedAtUtc",
                table: "economy_wallet_ledger");

            migrationBuilder.DropIndex(
                name: "IX_economy_purchase_orders_CreatedAtUtc",
                table: "economy_purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_economy_purchase_orders_Status_CreatedAtUtc",
                table: "economy_purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_economy_redeem_codes_CreatedAtUtc",
                table: "economy_redeem_codes");

            migrationBuilder.DropIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_RedeemedAtUtc",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.DropIndex(
                name: "IX_economy_user_subscriptions_UpdatedAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropIndex(
                name: "IX_economy_user_subscriptions_Status_UpdatedAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropIndex(
                name: "IX_economy_user_subscriptions_Provider_UpdatedAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropIndex(
                name: "IX_economy_subscription_event_logs_CreatedAtUtc",
                table: "economy_subscription_event_logs");

            migrationBuilder.DropIndex(
                name: "IX_economy_subscription_event_logs_Provider_Status_CreatedAtUtc",
                table: "economy_subscription_event_logs");
        }
    }
}
