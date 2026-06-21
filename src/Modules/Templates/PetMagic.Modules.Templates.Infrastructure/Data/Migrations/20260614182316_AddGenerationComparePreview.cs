using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationComparePreview : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PreviewUrl",
                table: "templates_media_records",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WatermarkedPreviewUrl",
                table: "templates_media_records",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DefaultVariationStrength",
                table: "templates_items",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "medium");

            migrationBuilder.AddColumn<bool>(
                name: "SupportsGenerateSimilar",
                table: "templates_items",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "GenerationMode",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "GenerationSeed",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PromptAfterVariation",
                table: "templates_generation_jobs",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PromptBeforeVariation",
                table: "templates_generation_jobs",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ResultMediaAssetId",
                table: "templates_generation_jobs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SimilarToGenerationId",
                table: "templates_generation_jobs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VariationStrength",
                table: "templates_generation_jobs",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.Sql(
                """
                CREATE TABLE IF NOT EXISTS templates_pet_analytics_events (
                    "Id" uuid NOT NULL,
                    "UserId" uuid NOT NULL,
                    "PetId" uuid NOT NULL,
                    "PetPhotoId" uuid,
                    "TemplateId" uuid,
                    "GenerationId" uuid,
                    "EventType" character varying(64) NOT NULL,
                    "PetType" character varying(16) NOT NULL,
                    "PhotosCount" integer NOT NULL,
                    "UserPlan" character varying(32) NOT NULL,
                    "SourceScreen" character varying(64) NOT NULL,
                    "CreatedAtUtc" timestamp with time zone NOT NULL,
                    CONSTRAINT "PK_templates_pet_analytics_events" PRIMARY KEY ("Id")
                );
                """);

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_generate_similar",
                table: "templates_items",
                columns: new[] { "SupportsGenerateSimilar", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_ResultMediaAssetId",
                table: "templates_generation_jobs",
                column: "ResultMediaAssetId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_SimilarToGenerationId",
                table: "templates_generation_jobs",
                column: "SimilarToGenerationId");

            migrationBuilder.Sql(
                """
                CREATE INDEX IF NOT EXISTS "IX_templates_pet_analytics_events_GenerationId"
                    ON templates_pet_analytics_events ("GenerationId");

                CREATE INDEX IF NOT EXISTS "IX_templates_pet_analytics_events_TemplateId"
                    ON templates_pet_analytics_events ("TemplateId");

                CREATE INDEX IF NOT EXISTS "IX_tpae_EventType_CreatedAtUtc"
                    ON templates_pet_analytics_events ("EventType", "CreatedAtUtc");

                CREATE INDEX IF NOT EXISTS "IX_tpae_PetId_CreatedAtUtc"
                    ON templates_pet_analytics_events ("PetId", "CreatedAtUtc");

                CREATE INDEX IF NOT EXISTS "IX_tpae_UserId_CreatedAtUtc"
                    ON templates_pet_analytics_events ("UserId", "CreatedAtUtc");
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_pet_analytics_events");

            migrationBuilder.DropIndex(
                name: "IX_templates_items_generate_similar",
                table: "templates_items");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_ResultMediaAssetId",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_SimilarToGenerationId",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreviewUrl",
                table: "templates_media_records");

            migrationBuilder.DropColumn(
                name: "WatermarkedPreviewUrl",
                table: "templates_media_records");

            migrationBuilder.DropColumn(
                name: "DefaultVariationStrength",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "SupportsGenerateSimilar",
                table: "templates_items");

            migrationBuilder.DropColumn(
                name: "GenerationMode",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GenerationSeed",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PromptAfterVariation",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PromptBeforeVariation",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ResultMediaAssetId",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "SimilarToGenerationId",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "VariationStrength",
                table: "templates_generation_jobs");
        }
    }
}
