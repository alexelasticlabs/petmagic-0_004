using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Gamification.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RemoveAchievementIconAssetPath : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IconAssetPath",
                table: "gamification_achievement_definitions");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "IconAssetPath",
                table: "gamification_achievement_definitions",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }
    }
}
