using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddWalletTokenAccounting : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "BucketDeltasJson",
                table: "economy_wallet_ledger",
                type: "character varying(4000)",
                maxLength: 4000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpiresAtUtc",
                table: "economy_wallet_ledger",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OperationKind",
                table: "economy_wallet_ledger",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "credit");

            migrationBuilder.AddColumn<Guid>(
                name: "TokenBucketId",
                table: "economy_wallet_ledger",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TokenKind",
                table: "economy_wallet_ledger",
                type: "character varying(40)",
                maxLength: 40,
                nullable: false,
                defaultValue: "legacy");

            migrationBuilder.CreateTable(
                name: "economy_wallet_token_buckets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Kind = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    InitialAmount = table.Column<int>(type: "integer", nullable: false),
                    RemainingAmount = table.Column<int>(type: "integer", nullable: false),
                    SourceLedgerEntryId = table.Column<Guid>(type: "uuid", nullable: true),
                    Source = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Reason = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_wallet_token_buckets", x => x.Id);
                    table.CheckConstraint("CK_ewtb_RemainingAmount_NonNegative", "\"RemainingAmount\" >= 0");
                });

            migrationBuilder.Sql(
                """
                UPDATE economy_wallet_ledger
                SET
                    "TokenKind" = CASE "Source"
                        WHEN 'pack_purchase' THEN 'purchased'
                        WHEN 'premium_subscription_grant' THEN 'subscription_allowance'
                        WHEN 'premium_subscription_weekly_grant' THEN 'subscription_allowance'
                        WHEN 'referral_bonus' THEN 'referral'
                        WHEN 'redeem_code' THEN 'promo'
                        WHEN 'admin_grant' THEN 'admin_adjustment'
                        WHEN 'admin_debit' THEN 'admin_adjustment'
                        WHEN 'generation_refund' THEN 'refund_adjustment'
                        WHEN 'purchase_refund' THEN 'refund_adjustment'
                        WHEN 'weekly_grant' THEN 'bonus'
                        WHEN 'ad_reward' THEN 'bonus'
                        WHEN 'generation_spend' THEN 'mixed_spend'
                        WHEN 'watermark_unlock' THEN 'mixed_spend'
                        ELSE 'legacy'
                    END,
                    "OperationKind" = CASE
                        WHEN "Source" = 'purchase_refund' THEN 'refund'
                        WHEN "Source" IN ('generation_spend', 'watermark_unlock') THEN 'spend'
                        WHEN "Source" IN ('admin_grant', 'admin_debit') THEN 'adjustment'
                        WHEN "Delta" >= 0 THEN 'credit'
                        ELSE 'debit'
                    END
                """);

            migrationBuilder.Sql(
                """
                INSERT INTO economy_wallet_token_buckets (
                    "Id",
                    "UserId",
                    "Kind",
                    "InitialAmount",
                    "RemainingAmount",
                    "SourceLedgerEntryId",
                    "Source",
                    "Reason",
                    "ExpiresAtUtc",
                    "CreatedAtUtc",
                    "UpdatedAtUtc")
                SELECT
                    CAST(
                        substr(md5("UserId"::text || ':legacy_wallet_bucket'), 1, 8) || '-' ||
                        substr(md5("UserId"::text || ':legacy_wallet_bucket'), 9, 4) || '-' ||
                        substr(md5("UserId"::text || ':legacy_wallet_bucket'), 13, 4) || '-' ||
                        substr(md5("UserId"::text || ':legacy_wallet_bucket'), 17, 4) || '-' ||
                        substr(md5("UserId"::text || ':legacy_wallet_bucket'), 21, 12)
                        AS uuid),
                    "UserId",
                    'legacy',
                    "Balance",
                    "Balance",
                    NULL,
                    'legacy_projection',
                    'migration balance projection',
                    NULL,
                    "UpdatedAtUtc",
                    "UpdatedAtUtc"
                FROM economy_wallets
                WHERE "Balance" > 0
                """);

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_ledger_TokenBucketId",
                table: "economy_wallet_ledger",
                column: "TokenBucketId");

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_ledger_TokenKind_CreatedAtUtc",
                table: "economy_wallet_ledger",
                columns: new[] { "TokenKind", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_wallet_token_buckets_SourceLedgerEntryId",
                table: "economy_wallet_token_buckets",
                column: "SourceLedgerEntryId");

            migrationBuilder.CreateIndex(
                name: "IX_ewtb_UserId_Kind_ExpiresAtUtc",
                table: "economy_wallet_token_buckets",
                columns: new[] { "UserId", "Kind", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_ewtb_UserId_Remaining_ExpiresAtUtc",
                table: "economy_wallet_token_buckets",
                columns: new[] { "UserId", "RemainingAmount", "ExpiresAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_wallet_token_buckets");

            migrationBuilder.DropIndex(
                name: "IX_economy_wallet_ledger_TokenBucketId",
                table: "economy_wallet_ledger");

            migrationBuilder.DropIndex(
                name: "IX_economy_wallet_ledger_TokenKind_CreatedAtUtc",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "BucketDeltasJson",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "ExpiresAtUtc",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "OperationKind",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "TokenBucketId",
                table: "economy_wallet_ledger");

            migrationBuilder.DropColumn(
                name: "TokenKind",
                table: "economy_wallet_ledger");
        }
    }
}
