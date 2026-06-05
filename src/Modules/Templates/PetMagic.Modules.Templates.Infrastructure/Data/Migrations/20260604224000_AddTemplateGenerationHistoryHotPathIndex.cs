using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260604224000_AddTemplateGenerationHistoryHotPathIndex")]
    public partial class AddTemplateGenerationHistoryHotPathIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_tgj_UserId_HiddenByUserAtUtc_CreatedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "HiddenByUserAtUtc", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_tgj_UserId_HiddenByUserAtUtc_CreatedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
