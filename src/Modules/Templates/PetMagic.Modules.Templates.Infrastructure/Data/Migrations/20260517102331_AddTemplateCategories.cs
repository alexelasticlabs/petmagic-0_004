using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateCategories : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_categories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    NormalizedName = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    IsArchived = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_categories", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_categories_IsArchived_Name",
                table: "templates_categories",
                columns: new[] { "IsArchived", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_categories_NormalizedName",
                table: "templates_categories",
                column: "NormalizedName",
                unique: true);

            migrationBuilder.Sql(
                """
                WITH normalized_categories AS (
                    SELECT
                        MIN(BTRIM("Category")) AS canonical_name,
                        UPPER(BTRIM("Category")) AS normalized_name
                    FROM templates_items
                    WHERE BTRIM("Category") <> ''
                    GROUP BY UPPER(BTRIM("Category"))
                )
                UPDATE templates_items AS items
                SET "Category" = categories.canonical_name
                FROM normalized_categories AS categories
                WHERE UPPER(BTRIM(items."Category")) = categories.normalized_name;

                WITH normalized_categories AS (
                    SELECT
                        MIN(BTRIM("Category")) AS canonical_name,
                        UPPER(BTRIM("Category")) AS normalized_name
                    FROM templates_items
                    WHERE BTRIM("Category") <> ''
                    GROUP BY UPPER(BTRIM("Category"))
                )
                INSERT INTO templates_categories ("Id", "Name", "NormalizedName", "IsArchived", "CreatedAtUtc", "UpdatedAtUtc")
                SELECT
                    (
                        substr(md5(normalized_name), 1, 8)
                        || '-'
                        || substr(md5(normalized_name), 9, 4)
                        || '-4'
                        || substr(md5(normalized_name), 14, 3)
                        || '-a'
                        || substr(md5(normalized_name), 18, 3)
                        || '-'
                        || substr(md5(normalized_name), 21, 12)
                    )::uuid,
                    canonical_name,
                    normalized_name,
                    FALSE,
                    NOW(),
                    NOW()
                FROM normalized_categories;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_categories");
        }
    }
}
