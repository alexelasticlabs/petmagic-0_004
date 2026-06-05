using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260601160000_ExpandTemplateLocalizationJson")]
    public partial class ExpandTemplateLocalizationJson : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "LocalizedTextsJson",
                table: "templates_items",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(12000)",
                oldMaxLength: 12000,
                oldNullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "LocalizedTextsJson",
                table: "templates_items",
                type: "character varying(12000)",
                maxLength: 12000,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);
        }
    }
}
