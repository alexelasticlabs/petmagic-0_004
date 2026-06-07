using System;

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    public partial class AddStoreBillingLedgerAndSubscriptionFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SourceProvider",
                table: "economy_wallet_ledger",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SourceTransactionId",
                table: "economy_wallet_ledger",
                type: "character varying(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAtUtc",
                table: "economy_user_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpiredAtUtc",
                table: "economy_user_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastValidatedAtUtc",
                table: "economy_user_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProductId",
                table: "economy_user_subscriptions",
                type: "character varying(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "UX_ewl_SourceProvider_SourceTransactionId",
                table: "economy_wallet_ledger",
                columns: new[] { "SourceProvider", "SourceTransactionId" },
                unique: true,
                filter: "\"SourceProvider\" IS NOT NULL AND \"SourceTransactionId\" IS NOT NULL");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_ewl_SourceProvider_SourceTransactionId",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "SourceProvider",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "SourceTransactionId",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "CancelledAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropColumn(
                name: "ExpiredAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropColumn(
                name: "LastValidatedAtUtc",
                table: "economy_user_subscriptions");

            migrationBuilder.DropColumn(
                name: "ProductId",
                table: "economy_user_subscriptions");
        }
    }
}
