using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateQaOnlyVisibility : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items");

            migrationBuilder.AddColumn<bool>(
                name: "IsQaOnly",
                table: "templates_items",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items",
                columns: new[] { "Status", "IsQaOnly", "Category", "UpdatedAtUtc", "Version", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items",
                columns: new[] { "Status", "IsQaOnly", "TemplateType", "IsPremium", "UpdatedAtUtc", "Version", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "IsQaOnly",
                table: "templates_items");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items",
                columns: new[] { "Status", "Category", "UpdatedAtUtc", "Version", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items",
                columns: new[] { "Status", "TemplateType", "IsPremium", "UpdatedAtUtc", "Version", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");
        }
    }
}
