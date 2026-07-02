using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260702120000_BackfillQaOnlyTemplateVisibility")]
    public partial class BackfillQaOnlyTemplateVisibility : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                UPDATE "templates_items"
                SET "IsQaOnly" = TRUE
                WHERE "IsQaOnly" = FALSE
                  AND (
                    "Title" ILIKE '%local qa%'
                    OR "Title" ILIKE '%local smoke%'
                    OR "Title" ILIKE '%smoke%'
                    OR "Title" ILIKE '%failing%'
                    OR "Title" ILIKE '%test%'
                    OR "Title" ILIKE '%тест%'
                    OR "Title" ILIKE '%впавпав%'
                  );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                UPDATE "templates_items"
                SET "IsQaOnly" = FALSE
                WHERE "IsQaOnly" = TRUE
                  AND (
                    "Title" ILIKE '%local qa%'
                    OR "Title" ILIKE '%local smoke%'
                    OR "Title" ILIKE '%smoke%'
                    OR "Title" ILIKE '%failing%'
                    OR "Title" ILIKE '%test%'
                    OR "Title" ILIKE '%тест%'
                    OR "Title" ILIKE '%впавпав%'
                  );
                """);
        }
    }
}
