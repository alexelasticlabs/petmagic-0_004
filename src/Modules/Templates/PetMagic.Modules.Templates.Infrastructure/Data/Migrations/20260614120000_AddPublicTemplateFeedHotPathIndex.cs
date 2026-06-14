using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260614120000_AddPublicTemplateFeedHotPathIndex")]
    public partial class AddPublicTemplateFeedHotPathIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_templates_items_Status_UpdatedAtUtc_Id",
                table: "templates_items",
                columns: new[] { "Status", "UpdatedAtUtc", "Id" },
                filter: """ "DeletedAtUtc" IS NULL """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_items_Status_UpdatedAtUtc_Id",
                table: "templates_items");
        }
    }
}
