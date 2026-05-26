using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentProviderCheckoutControls : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BonusTokensPercent",
                table: "economy_payment_provider_configs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "DisplayLabel",
                table: "economy_payment_provider_configs",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DisplaySubtitle",
                table: "economy_payment_provider_configs",
                type: "character varying(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsRecommended",
                table: "economy_payment_provider_configs",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsSelectedByDefault",
                table: "economy_payment_provider_configs",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "WarningMessage",
                table: "economy_payment_provider_configs",
                type: "character varying(800)",
                maxLength: 800,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WarningTitle",
                table: "economy_payment_provider_configs",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BonusTokensPercent",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "DisplayLabel",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "DisplaySubtitle",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "IsRecommended",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "IsSelectedByDefault",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "WarningMessage",
                table: "economy_payment_provider_configs");

            migrationBuilder.DropColumn(
                name: "WarningTitle",
                table: "economy_payment_provider_configs");
        }
    }
}
