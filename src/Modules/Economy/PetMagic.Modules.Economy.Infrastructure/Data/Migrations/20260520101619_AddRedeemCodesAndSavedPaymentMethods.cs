using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddRedeemCodesAndSavedPaymentMethods : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "SavedPaymentMethodId",
                table: "economy_purchase_orders",
                type: "uuid",
                nullable: true);

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
                name: "economy_redeem_code_redemptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RedeemCodeId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    WalletLedgerEntryId = table.Column<Guid>(type: "uuid", nullable: false),
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
                    CodeHash = table.Column<string>(type: "character varying(96)", maxLength: 96, nullable: false),
                    CodePrefix = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Description = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    RewardSpark = table.Column<int>(type: "integer", nullable: false),
                    MaxRedemptions = table.Column<int>(type: "integer", nullable: false),
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

            migrationBuilder.CreateIndex(
                name: "IX_economy_purchase_orders_SavedPaymentMethodId",
                table: "economy_purchase_orders",
                column: "SavedPaymentMethodId");

            migrationBuilder.CreateIndex(
                name: "IX_economy_payment_customers_Provider_ExternalCustomerId",
                table: "economy_payment_customers",
                columns: new[] { "Provider", "ExternalCustomerId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "RedeemCodeId", "UserId" },
                unique: true);

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
                name: "IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~",
                table: "economy_saved_payment_methods",
                columns: new[] { "Provider", "ExternalPaymentMethodId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_saved_payment_methods_UserId_IsActive_IsDefault",
                table: "economy_saved_payment_methods",
                columns: new[] { "UserId", "IsActive", "IsDefault" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_payment_customers");

            migrationBuilder.DropTable(
                name: "economy_redeem_code_redemptions");

            migrationBuilder.DropTable(
                name: "economy_redeem_codes");

            migrationBuilder.DropTable(
                name: "economy_saved_payment_methods");

            migrationBuilder.DropIndex(
                name: "IX_economy_purchase_orders_SavedPaymentMethodId",
                table: "economy_purchase_orders");

            migrationBuilder.DropColumn(
                name: "SavedPaymentMethodId",
                table: "economy_purchase_orders");
        }
    }
}
