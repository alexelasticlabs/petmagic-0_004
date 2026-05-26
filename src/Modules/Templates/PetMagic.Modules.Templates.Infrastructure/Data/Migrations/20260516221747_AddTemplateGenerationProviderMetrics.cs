using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateGenerationProviderMetrics : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "MotionInferenceTimeSeconds",
                table: "templates_generation_jobs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "MotionProviderCostUsd",
                table: "templates_generation_jobs",
                type: "numeric(12,4)",
                precision: 12,
                scale: 4,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MotionProviderRequestId",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "OutputVideoDurationSeconds",
                table: "templates_generation_jobs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "PreprocessingInferenceTimeSeconds",
                table: "templates_generation_jobs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreprocessingProviderRequestId",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MotionInferenceTimeSeconds",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionProviderCostUsd",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionProviderRequestId",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "OutputVideoDurationSeconds",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingInferenceTimeSeconds",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingProviderRequestId",
                table: "templates_generation_jobs");
        }
    }
}
