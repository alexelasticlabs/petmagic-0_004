using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPurchasesAndWebhookEvents : Migration
    {
        private static readonly string[] columns = ["Provider", "EventId"];

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "economy_processed_webhook_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    EventId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    EventType = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    ProcessedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_processed_webhook_events", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_purchase_orders",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PackId = table.Column<Guid>(type: "uuid", nullable: false),
                    PaymentProvider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    PriceAmount = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    CurrencyCode = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    SparkToGrant = table.Column<int>(type: "integer", nullable: false),
                    ExternalPaymentId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    CheckoutUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ConfirmedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_purchase_orders", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_economy_processed_webhook_events_ProcessedAtUtc",
                table: "economy_processed_webhook_events",
                column: "ProcessedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_processed_webhook_events_Provider_EventId",
                table: "economy_processed_webhook_events",
                columns: columns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId",
                table: "economy_purchase_orders",
                columns: ["PaymentProvider", "ExternalPaymentId"]);

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_UserId_CreatedAtUtc",
                table: "economy_purchase_orders",
                columns: ["UserId", "CreatedAtUtc"]);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_processed_webhook_events");

            migrationBuilder.DropTable(
                name: "economy_purchase_orders");
        }
    }
}
