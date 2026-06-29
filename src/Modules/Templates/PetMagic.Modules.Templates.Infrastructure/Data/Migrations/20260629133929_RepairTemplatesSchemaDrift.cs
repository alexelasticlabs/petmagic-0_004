using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RepairTemplatesSchemaDrift : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE templates_items
                ADD COLUMN IF NOT EXISTS "PetPhotoRequirements" character varying(1000);
                """);

            migrationBuilder.Sql(
                """
                ALTER TABLE templates_items
                ADD COLUMN IF NOT EXISTS "LocalizedTextsJson" text;
                """);

            migrationBuilder.Sql(
                """
                ALTER TABLE templates_items
                ALTER COLUMN "LocalizedTextsJson" TYPE text USING "LocalizedTextsJson"::text;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
