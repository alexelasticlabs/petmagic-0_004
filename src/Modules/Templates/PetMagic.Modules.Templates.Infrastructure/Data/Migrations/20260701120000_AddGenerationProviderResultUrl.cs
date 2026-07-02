using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260701120000_AddGenerationProviderResultUrl")]
    public partial class AddGenerationProviderResultUrl : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ProviderResultUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ProviderResultUrl",
                table: "templates_generation_jobs");
        }
    }
}
