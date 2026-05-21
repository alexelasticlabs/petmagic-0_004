using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPremiumSubscriptions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "economy_payment_provider_configs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Platform = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Region = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    RequiresExternalWarning = table.Column<bool>(type: "boolean", nullable: false),
                    RequiresStoreDisclosure = table.Column<bool>(type: "boolean", nullable: false),
                    AllowedFromAppVersion = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ExternalCheckoutAllowed = table.Column<bool>(type: "boolean", nullable: false),
                    Mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Notes = table.Column<string>(type: "character varying(400)", maxLength: 400, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_payment_provider_configs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_subscription_event_logs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    UserSubscriptionId = table.Column<Guid>(type: "uuid", nullable: true),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ExternalEventId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    ExternalSubscriptionId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    PayloadJson = table.Column<string>(type: "character varying(32000)", maxLength: 32000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ProcessedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_subscription_event_logs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_subscription_plans",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    BillingPeriod = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    PriceAmount = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    CurrencyCode = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    MonthlyTokenLimit = table.Column<int>(type: "integer", nullable: false),
                    IsRecommended = table.Column<bool>(type: "boolean", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    AppleProductId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    GoogleProductId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    StripePriceId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    DisplayOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_subscription_plans", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_user_subscriptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    PurchaseChannel = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Region = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    PlanId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ExternalCustomerId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    ExternalSubscriptionId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    ExternalTransactionId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    CurrentPeriodStartUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CurrentPeriodEndUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelAtPeriodEnd = table.Column<bool>(type: "boolean", nullable: false),
                    MonthlyTokenLimit = table.Column<int>(type: "integer", nullable: false),
                    MonthlyTokensGranted = table.Column<int>(type: "integer", nullable: false),
                    LastTokenGrantAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_user_subscriptions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_economy_payment_provider_configs_Platform_IsEnabled",
                table: "economy_payment_provider_configs",
                columns: new[] { "Platform", "IsEnabled" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_payment_provider_configs_Provider_Platform_Region",
                table: "economy_payment_provider_configs",
                columns: new[] { "Provider", "Platform", "Region" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_event_logs_Provider_ExternalEventId",
                table: "economy_subscription_event_logs",
                columns: new[] { "Provider", "ExternalEventId" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_event_logs_Provider_ExternalSubscripti~",
                table: "economy_subscription_event_logs",
                columns: new[] { "Provider", "ExternalSubscriptionId" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_event_logs_UserId_CreatedAtUtc",
                table: "economy_subscription_event_logs",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_subscription_plans_IsActive_DisplayOrder",
                table: "economy_subscription_plans",
                columns: new[] { "IsActive", "DisplayOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_Provider_ExternalSubscriptionId",
                table: "economy_user_subscriptions",
                columns: new[] { "Provider", "ExternalSubscriptionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_UserId_Status_CurrentPeriodEndUtc",
                table: "economy_user_subscriptions",
                columns: new[] { "UserId", "Status", "CurrentPeriodEndUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_user_subscriptions_UserId_UpdatedAtUtc",
                table: "economy_user_subscriptions",
                columns: new[] { "UserId", "UpdatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_payment_provider_configs");

            migrationBuilder.DropTable(
                name: "economy_subscription_event_logs");

            migrationBuilder.DropTable(
                name: "economy_subscription_plans");

            migrationBuilder.DropTable(
                name: "economy_user_subscriptions");
        }
    }
}
