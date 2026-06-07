using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    public partial class AddStoreBillingIdempotencyIndexes : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId",
                table: "economy_purchase_orders");

            migrationBuilder.CreateIndex(
                name: "UX_epo_Provider_ExternalPaymentId",
                table: "economy_purchase_orders",
                columns: new[] { "PaymentProvider", "ExternalPaymentId" },
                unique: true,
                filter: "\"ExternalPaymentId\" IS NOT NULL AND \"ExternalPaymentId\" <> ''");

            migrationBuilder.CreateIndex(
                name: "UX_eus_Provider_ExternalTransactionId",
                table: "economy_user_subscriptions",
                columns: new[] { "Provider", "ExternalTransactionId" },
                unique: true,
                filter: "\"ExternalTransactionId\" IS NOT NULL AND \"ExternalTransactionId\" <> ''");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_epo_Provider_ExternalPaymentId",
                table: "economy_purchase_orders");

            migrationBuilder.DropIndex(
                name: "UX_eus_Provider_ExternalTransactionId",
                table: "economy_user_subscriptions");

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId",
                table: "economy_purchase_orders",
                columns: new[] { "PaymentProvider", "ExternalPaymentId" });
        }
    }
}
