using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260702093000_AddTemplatePublishedAtUtc")]
    public partial class AddTemplatePublishedAtUtc : Migration
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

            migrationBuilder.AddColumn<DateTime>(
                name: "PublishedAtUtc",
                table: "templates_items",
                type: "timestamp with time zone",
                nullable: true);

            // One-time backfill: existing active templates keep their original creation order.
            migrationBuilder.Sql("""
                UPDATE "templates_items"
                SET "PublishedAtUtc" = "CreatedAtUtc"
                WHERE "Status" = 2
                  AND "PublishedAtUtc" IS NULL
                  AND "DeletedAtUtc" IS NULL;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_Status_PublishedAtUtc_Id",
                table: "templates_items",
                columns: new[] { "Status", "PublishedAtUtc", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items",
                columns: new[] { "Status", "IsQaOnly", "Category", "PublishedAtUtc", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items",
                columns: new[] { "Status", "IsQaOnly", "TemplateType", "IsPremium", "PublishedAtUtc", "Id" },
                filter: " \"DeletedAtUtc\" IS NULL ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_items_Status_PublishedAtUtc_Id",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedCategoryOrder",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_PublicFeedFilters",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "PublishedAtUtc",
                table: "templates_items");

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
    }
}
