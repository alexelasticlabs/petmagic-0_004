using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateGenerationDiagnostics : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "MediaImportCompletedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "MotionGenerationCompletedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PreprocessingCompletedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UsedKlingModel",
                table: "templates_generation_jobs",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UsedPreprocessingModel",
                table: "templates_generation_jobs",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MediaImportCompletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionGenerationCompletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingCompletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "UsedKlingModel",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "UsedPreprocessingModel",
                table: "templates_generation_jobs");
        }
    }
}
