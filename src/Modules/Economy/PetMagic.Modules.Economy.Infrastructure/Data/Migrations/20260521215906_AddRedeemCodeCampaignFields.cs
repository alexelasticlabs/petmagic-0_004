using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddRedeemCodeCampaignFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CampaignChannel",
                table: "economy_redeem_codes",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CampaignName",
                table: "economy_redeem_codes",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CreatedBy",
                table: "economy_redeem_codes",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MinimumSuccessfulPurchases",
                table: "economy_redeem_codes",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CampaignChannel",
                table: "economy_redeem_codes");

            migrationBuilder.DropColumn(
                name: "CampaignName",
                table: "economy_redeem_codes");

            migrationBuilder.DropColumn(
                name: "CreatedBy",
                table: "economy_redeem_codes");

            migrationBuilder.DropColumn(
                name: "MinimumSuccessfulPurchases",
                table: "economy_redeem_codes");
        }
    }
}
