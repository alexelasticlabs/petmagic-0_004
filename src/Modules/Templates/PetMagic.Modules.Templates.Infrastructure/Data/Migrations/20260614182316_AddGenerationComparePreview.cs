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

            migrationBuilder.CreateTable(
                name: "templates_pet_analytics_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PetId = table.Column<Guid>(type: "uuid", nullable: false),
                    PetPhotoId = table.Column<Guid>(type: "uuid", nullable: true),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: true),
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    PetType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    PhotosCount = table.Column<int>(type: "integer", nullable: false),
                    UserPlan = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    SourceScreen = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_pet_analytics_events", x => x.Id);
                });

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

            migrationBuilder.CreateIndex(
                name: "IX_templates_pet_analytics_events_GenerationId",
                table: "templates_pet_analytics_events",
                column: "GenerationId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_pet_analytics_events_TemplateId",
                table: "templates_pet_analytics_events",
                column: "TemplateId");

            migrationBuilder.CreateIndex(
                name: "IX_tpae_EventType_CreatedAtUtc",
                table: "templates_pet_analytics_events",
                columns: new[] { "EventType", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_tpae_PetId_CreatedAtUtc",
                table: "templates_pet_analytics_events",
                columns: new[] { "PetId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_tpae_UserId_CreatedAtUtc",
                table: "templates_pet_analytics_events",
                columns: new[] { "UserId", "CreatedAtUtc" });
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
