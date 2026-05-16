using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    public partial class InitialEconomy : Migration
    {
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
                name: "IX_economy_wallet_ledger_UserId_CreatedAtUtc",
                table: "economy_wallet_ledger",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallets_UpdatedAtUtc",
                table: "economy_wallets",
                column: "UpdatedAtUtc");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "economy_currency_packs");
            migrationBuilder.DropTable(name: "economy_wallet_ledger");
            migrationBuilder.DropTable(name: "economy_wallets");
        }
    }
}
