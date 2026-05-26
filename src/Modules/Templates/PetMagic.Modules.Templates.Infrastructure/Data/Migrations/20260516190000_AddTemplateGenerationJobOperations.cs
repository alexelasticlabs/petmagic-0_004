using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260516190000_AddTemplateGenerationJobOperations")]
public sealed class AddTemplateGenerationJobOperations : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<int>(
            name: "RefundAttemptCount",
            table: "templates_generation_jobs",
            type: "integer",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.AddColumn<string>(
            name: "RefundLastErrorCode",
            table: "templates_generation_jobs",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "RefundLastAttemptedAtUtc",
            table: "templates_generation_jobs",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_Status_CompletedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "Status", "CompletedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAttemptedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "Status", "RefundedAtUtc", "RefundLastAttemptedAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_Status_CompletedAtUtc",
            table: "templates_generation_jobs");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAttemptedAtUtc",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "RefundAttemptCount",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "RefundLastErrorCode",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "RefundLastAttemptedAtUtc",
            table: "templates_generation_jobs");
    }
}
