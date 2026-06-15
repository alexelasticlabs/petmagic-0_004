using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260614121000_AddPublicTemplateFeedFilterIndex")]
    public partial class AddPublicTemplateFeedFilterIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items",
                columns: new[] { "Status", "TemplateType", "IsPremium", "UpdatedAtUtc", "Version", "Id" },
                filter: """ "DeletedAtUtc" IS NULL """);

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items",
                columns: new[] { "Status", "Category", "UpdatedAtUtc", "Version", "Id" },
                filter: """ "DeletedAtUtc" IS NULL """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items");
        }
    }
}
