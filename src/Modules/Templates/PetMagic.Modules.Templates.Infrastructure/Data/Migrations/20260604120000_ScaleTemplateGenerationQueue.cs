using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260604120000_ScaleTemplateGenerationQueue")]
    public partial class ScaleTemplateGenerationQueue : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "OutputUrl",
                table: "templates_generation_jobs",
                newName: "ResultUrl");

            migrationBuilder.RenameColumn(
                name: "FailureMessage",
                table: "templates_generation_jobs",
                newName: "LastErrorMessage");

            migrationBuilder.RenameColumn(
                name: "FailureCode",
                table: "templates_generation_jobs",
                newName: "LastErrorCode");

            migrationBuilder.Sql(
                """
                UPDATE templates_generation_jobs
                SET "Status" = 2
                WHERE "Status" IN (5, 6, 7, 8);
                """);

            migrationBuilder.AddColumn<string>(
                name: "IdempotencyKey",
                table: "templates_generation_jobs",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LockedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LockedBy",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RequestHash",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "templates_ai_provider_request_permits",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    BucketUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PermitNumber = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_ai_provider_request_permits", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_ai_provider_permits_CreatedAtUtc",
                table: "templates_ai_provider_request_permits",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "UX_templates_ai_provider_permits_provider_bucket_slot",
                table: "templates_ai_provider_request_permits",
                columns: new[] { "Provider", "BucketUtc", "PermitNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_Status_LockedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "LockedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserId_Status",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "IdempotencyKey" },
                unique: true,
                filter: """ "Status" IN (1, 2) AND "IdempotencyKey" IS NOT NULL """);

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "RequestHash" },
                unique: true,
                filter: """ "Status" IN (1, 2) AND "RequestHash" IS NOT NULL """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_ai_provider_request_permits");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_Status_LockedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_UserId_Status",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "IdempotencyKey",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "LockedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "LockedBy",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "RequestHash",
                table: "templates_generation_jobs");

            migrationBuilder.RenameColumn(
                name: "ResultUrl",
                table: "templates_generation_jobs",
                newName: "OutputUrl");

            migrationBuilder.RenameColumn(
                name: "LastErrorMessage",
                table: "templates_generation_jobs",
                newName: "FailureMessage");

            migrationBuilder.RenameColumn(
                name: "LastErrorCode",
                table: "templates_generation_jobs",
                newName: "FailureCode");
        }
    }
}
