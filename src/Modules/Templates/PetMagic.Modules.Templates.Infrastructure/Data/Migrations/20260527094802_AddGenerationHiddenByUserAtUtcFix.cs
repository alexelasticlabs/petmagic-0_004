using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationHiddenByUserAtUtcFix : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "HiddenByUserAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_HiddenByUserAtUtc",
                table: "templates_generation_jobs",
                column: "HiddenByUserAtUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_HiddenByUserAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "HiddenByUserAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
