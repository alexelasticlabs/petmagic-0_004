using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

public partial class AddGenerateSimilar : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
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
            defaultValue: true);

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

        migrationBuilder.CreateIndex(
            name: "IX_templates_items_generate_similar",
            table: "templates_items",
            columns: new[] { "SupportsGenerateSimilar", "Status" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_SimilarToGenerationId",
            table: "templates_generation_jobs",
            column: "SimilarToGenerationId");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_templates_items_generate_similar",
            table: "templates_items");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_SimilarToGenerationId",
            table: "templates_generation_jobs");

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
            name: "SimilarToGenerationId",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "VariationStrength",
            table: "templates_generation_jobs");
    }
}
