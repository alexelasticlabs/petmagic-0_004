using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateCatalogVersioning : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAtUtc",
                table: "templates_items",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "Version",
                table: "templates_items",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.CreateTable(
                name: "templates_catalog_changes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    ChangeType = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_catalog_changes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_DeletedAtUtc",
                table: "templates_items",
                column: "DeletedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_Version",
                table: "templates_items",
                column: "Version");

            migrationBuilder.CreateIndex(
                name: "IX_templates_catalog_changes_TemplateId",
                table: "templates_catalog_changes",
                column: "TemplateId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_catalog_changes_TemplateId_Version",
                table: "templates_catalog_changes",
                columns: new[] { "TemplateId", "Version" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_catalog_changes_Version",
                table: "templates_catalog_changes",
                column: "Version",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_catalog_changes");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_DeletedAtUtc",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_Version",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "DeletedAtUtc",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "templates_items");
        }
    }
}
