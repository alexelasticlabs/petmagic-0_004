using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddRedeemCodeRewardPolicies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.RenameColumn(
                name: "RewardSpark",
                table: "economy_redeem_codes",
                newName: "RewardValue");

            migrationBuilder.AddColumn<int>(
                name: "MaxRedemptionsPerUser",
                table: "economy_redeem_codes",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "RewardKind",
                table: "economy_redeem_codes",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AlterColumn<Guid>(
                name: "WalletLedgerEntryId",
                table: "economy_redeem_code_redemptions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<DateTime>(
                name: "PremiumExpiresAtUtc",
                table: "economy_redeem_code_redemptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RewardKind",
                table: "economy_redeem_code_redemptions",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "RewardValue",
                table: "economy_redeem_code_redemptions",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "RedeemCodeId", "UserId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.DropColumn(
                name: "MaxRedemptionsPerUser",
                table: "economy_redeem_codes");

            migrationBuilder.DropColumn(
                name: "RewardKind",
                table: "economy_redeem_codes");

            migrationBuilder.DropColumn(
                name: "PremiumExpiresAtUtc",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.DropColumn(
                name: "RewardKind",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.DropColumn(
                name: "RewardValue",
                table: "economy_redeem_code_redemptions");

            migrationBuilder.RenameColumn(
                name: "RewardValue",
                table: "economy_redeem_codes",
                newName: "RewardSpark");

            migrationBuilder.AlterColumn<Guid>(
                name: "WalletLedgerEntryId",
                table: "economy_redeem_code_redemptions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId",
                table: "economy_redeem_code_redemptions",
                columns: new[] { "RedeemCodeId", "UserId" },
                unique: true);
        }
    }
}
