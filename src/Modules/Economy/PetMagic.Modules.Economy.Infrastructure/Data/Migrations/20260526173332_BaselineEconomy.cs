using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class BaselineEconomy : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "economy_currency_packs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    CurrencyCode = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    PriceAmount = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    GrantedSpark = table.Column<int>(type: "integer", nullable: false),
                    BonusSpark = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_currency_packs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_payment_customers",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    ExternalCustomerId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_payment_customers", x => new { x.UserId, x.Provider });
                });

            migrationBuilder.CreateTable(
                name: "economy_payment_provider_configs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Platform = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Region = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    IsRecommended = table.Column<bool>(type: "boolean", nullable: false),
                    IsSelectedByDefault = table.Column<bool>(type: "boolean", nullable: false),
                    RequiresExternalWarning = table.Column<bool>(type: "boolean", nullable: false),
                    RequiresStoreDisclosure = table.Column<bool>(type: "boolean", nullable: false),
                    AllowedFromAppVersion = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ExternalCheckoutAllowed = table.Column<bool>(type: "boolean", nullable: false),
                    BonusTokensPercent = table.Column<int>(type: "integer", nullable: false),
                    DisplayLabel = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    DisplaySubtitle = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    WarningTitle = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    WarningMessage = table.Column<string>(type: "character varying(800)", maxLength: 800, nullable: true),
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
                    SavedPaymentMethodId = table.Column<Guid>(type: "uuid", nullable: true),
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

            migrationBuilder.CreateTable(
                name: "economy_redeem_code_redemptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RedeemCodeId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RewardKind = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    RewardValue = table.Column<int>(type: "integer", nullable: false),
                    WalletLedgerEntryId = table.Column<Guid>(type: "uuid", nullable: true),
                    PremiumExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RedeemedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_redeem_code_redemptions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_redeem_codes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CodeHash = table.Column<string>(type: "character varying(96)", maxLength: 96, nullable: false),
                    CodePrefix = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Description = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    CampaignName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    CampaignChannel = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    MinimumSuccessfulPurchases = table.Column<int>(type: "integer", nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    RewardKind = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    RewardValue = table.Column<int>(type: "integer", nullable: false),
                    MaxRedemptions = table.Column<int>(type: "integer", nullable: false),
                    MaxRedemptionsPerUser = table.Column<int>(type: "integer", nullable: false),
                    RedeemedCount = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    StartsAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_redeem_codes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_referral_attributions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ReferrerUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RefereeUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReferrerCode = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    RewardSpark = table.Column<int>(type: "integer", nullable: false),
                    ReferrerLedgerEntryId = table.Column<Guid>(type: "uuid", nullable: true),
                    RefereeLedgerEntryId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    QualifiedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_referral_attributions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_referral_profiles",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_referral_profiles", x => x.UserId);
                });

            migrationBuilder.CreateTable(
                name: "economy_saved_payment_methods",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    ExternalPaymentMethodId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Brand = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Last4 = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    ExpMonth = table.Column<long>(type: "bigint", nullable: true),
                    ExpYear = table.Column<long>(type: "bigint", nullable: true),
                    IsDefault = table.Column<bool>(type: "boolean", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_saved_payment_methods", x => x.Id);
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

            migrationBuilder.CreateTable(
                name: "economy_wallet_ledger",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Delta = table.Column<int>(type: "integer", nullable: false),
                    BalanceAfter = table.Column<int>(type: "integer", nullable: false),
                    Source = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Reason = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_wallet_ledger", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "economy_wallets",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Balance = table.Column<int>(type: "integer", nullable: false),
                    LastWeeklyGrantAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AdRewardWindowStartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AdRewardsClaimedInWindow = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_wallets", x => x.UserId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_economy_currency_packs_Code_CurrencyCode",
                table: "economy_currency_packs",
                columns: new[] { "Code", "CurrencyCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_currency_packs_CurrencyCode_IsActive_SortOrder",
                table: "economy_currency_packs",
                columns: new[] { "CurrencyCode", "IsActive", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_payment_customers_Provider_ExternalCustomerId",
                table: "economy_payment_customers",
                columns: new[] { "Provider", "ExternalCustomerId" },
                unique: true);

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
                name: "IX_economy_processed_webhook_events_ProcessedAtUtc",
                table: "economy_processed_webhook_events",
                column: "ProcessedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_economy_processed_webhook_events_Provider_EventId",
                table: "economy_processed_webhook_events",
                columns: new[] { "Provider", "EventId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId",
                table: "economy_purchase_orders",
                columns: new[] { "PaymentProvider", "ExternalPaymentId" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_SavedPaymentMethodId",
                table: "economy_purchase_orders",
                column: "SavedPaymentMethodId");

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_UserId_CreatedAtUtc",
                table: "economy_purchase_orders",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "RedeemCodeId", "UserId" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_UserId_RedeemedAtUtc",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "UserId", "RedeemedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_codes_CodeHash",
                table: "economy_redeem_codes",
                column: "CodeHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_codes_IsActive_ExpiresAtUtc",
                table: "economy_redeem_codes",
                columns: new[] { "IsActive", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_referral_attributions_RefereeUserId",
                table: "economy_referral_attributions",
                column: "RefereeUserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_referral_attributions_ReferrerUserId",
                table: "economy_referral_attributions",
                column: "ReferrerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_economy_referral_attributions_ReferrerUserId_Status",
                table: "economy_referral_attributions",
                columns: new[] { "ReferrerUserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_referral_profiles_Code",
                table: "economy_referral_profiles",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~",
                table: "economy_saved_payment_methods",
                columns: new[] { "Provider", "ExternalPaymentMethodId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_saved_payment_methods_UserId_IsActive_IsDefault",
                table: "economy_saved_payment_methods",
                columns: new[] { "UserId", "IsActive", "IsDefault" });

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

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_ledger_UserId_CreatedAtUtc",
                table: "economy_wallet_ledger",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallets_UpdatedAtUtc",
                table: "economy_wallets",
                column: "UpdatedAtUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_currency_packs");

            migrationBuilder.DropTable(
                name: "economy_payment_customers");

            migrationBuilder.DropTable(
                name: "economy_payment_provider_configs");

            migrationBuilder.DropTable(
                name: "economy_processed_webhook_events");

            migrationBuilder.DropTable(
                name: "economy_purchase_orders");

            migrationBuilder.DropTable(
                name: "economy_redeem_code_redemptions");

            migrationBuilder.DropTable(
                name: "economy_redeem_codes");

            migrationBuilder.DropTable(
                name: "economy_referral_attributions");

            migrationBuilder.DropTable(
                name: "economy_referral_profiles");

            migrationBuilder.DropTable(
                name: "economy_saved_payment_methods");

            migrationBuilder.DropTable(
                name: "economy_subscription_event_logs");

            migrationBuilder.DropTable(
                name: "economy_subscription_plans");

            migrationBuilder.DropTable(
                name: "economy_user_subscriptions");

            migrationBuilder.DropTable(
                name: "economy_wallet_ledger");

            migrationBuilder.DropTable(
                name: "economy_wallets");
        }
    }
}
