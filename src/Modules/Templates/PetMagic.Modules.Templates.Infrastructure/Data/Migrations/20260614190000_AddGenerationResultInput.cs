using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614190000_AddGenerationResultInput")]
public partial class AddGenerationResultInput : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "RecommendedAfterImageGeneration",
            table: "templates_items",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<int>(
            name: "RequiredInputMediaType",
            table: "templates_items",
            type: "integer",
            nullable: true);

        migrationBuilder.AddColumn<bool>(
            name: "SupportsGenerationResultInput",
            table: "templates_items",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<Guid>(
            name: "InputMediaAssetId",
            table: "templates_generation_jobs",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "InputSourceType",
            table: "templates_generation_jobs",
            type: "character varying(32)",
            maxLength: 32,
            nullable: false,
            defaultValue: "user_upload");

        migrationBuilder.AddColumn<Guid>(
            name: "ParentGenerationId",
            table: "templates_generation_jobs",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "ParentGenerationResultId",
            table: "templates_generation_jobs",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "GenerationId",
            table: "templates_media_records",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<bool>(
            name: "IsDeleted",
            table: "templates_media_records",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<string>(
            name: "MediaType",
            table: "templates_media_records",
            type: "character varying(16)",
            maxLength: 16,
            nullable: false,
            defaultValue: "image");

        migrationBuilder.AddColumn<string>(
            name: "SourceType",
            table: "templates_media_records",
            type: "character varying(32)",
            maxLength: 32,
            nullable: false,
            defaultValue: "user_upload");

        migrationBuilder.AddColumn<string>(
            name: "StoragePath",
            table: "templates_media_records",
            type: "character varying(2048)",
            maxLength: 2048,
            nullable: false,
            defaultValue: string.Empty);

        migrationBuilder.AddColumn<Guid>(
            name: "UserId",
            table: "templates_media_records",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "WatermarkedStoragePath",
            table: "templates_media_records",
            type: "character varying(2048)",
            maxLength: 2048,
            nullable: true);

        migrationBuilder.Sql("""
            UPDATE templates_media_records
            SET "StoragePath" = "Url",
                "MediaType" = CASE WHEN lower("ContentType") LIKE 'video/%' THEN 'video' ELSE 'image' END
            WHERE "StoragePath" = ''
            """);

        migrationBuilder.CreateIndex(
            name: "IX_templates_items_generation_result_input",
            table: "templates_items",
            columns: new[] { "SupportsGenerationResultInput", "RequiredInputMediaType", "Status" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_ParentGenerationId",
            table: "templates_generation_jobs",
            column: "ParentGenerationId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_ParentGenerationResultId",
            table: "templates_generation_jobs",
            column: "ParentGenerationResultId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_InputMediaAssetId",
            table: "templates_generation_jobs",
            column: "InputMediaAssetId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_media_records_GenerationId",
            table: "templates_media_records",
            column: "GenerationId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_media_records_UserId_MediaType_IsDeleted",
            table: "templates_media_records",
            columns: new[] { "UserId", "MediaType", "IsDeleted" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_templates_items_generation_result_input",
            table: "templates_items");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_ParentGenerationId",
            table: "templates_generation_jobs");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_ParentGenerationResultId",
            table: "templates_generation_jobs");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_InputMediaAssetId",
            table: "templates_generation_jobs");

        migrationBuilder.DropIndex(
            name: "IX_templates_media_records_GenerationId",
            table: "templates_media_records");

        migrationBuilder.DropIndex(
            name: "IX_templates_media_records_UserId_MediaType_IsDeleted",
            table: "templates_media_records");

        migrationBuilder.DropColumn(name: "RecommendedAfterImageGeneration", table: "templates_items");
        migrationBuilder.DropColumn(name: "RequiredInputMediaType", table: "templates_items");
        migrationBuilder.DropColumn(name: "SupportsGenerationResultInput", table: "templates_items");
        migrationBuilder.DropColumn(name: "InputMediaAssetId", table: "templates_generation_jobs");
        migrationBuilder.DropColumn(name: "InputSourceType", table: "templates_generation_jobs");
        migrationBuilder.DropColumn(name: "ParentGenerationId", table: "templates_generation_jobs");
        migrationBuilder.DropColumn(name: "ParentGenerationResultId", table: "templates_generation_jobs");
        migrationBuilder.DropColumn(name: "GenerationId", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "IsDeleted", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "MediaType", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "SourceType", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "StoragePath", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "UserId", table: "templates_media_records");
        migrationBuilder.DropColumn(name: "WatermarkedStoragePath", table: "templates_media_records");
    }
}
