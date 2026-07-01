using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationSchedulerQueueFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EstimatedCompletionAtQueueUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "EstimatedWaitSecondsAtQueue",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "QueueMediaType",
                table: "templates_generation_jobs",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "image");

            migrationBuilder.AddColumn<string>(
                name: "QueueTier",
                table: "templates_generation_jobs",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "free");

            migrationBuilder.Sql(
                """
                UPDATE templates_generation_jobs AS jobs
                SET "QueueMediaType" = CASE
                    WHEN templates."TemplateType" = 2 THEN 'video'
                    ELSE 'image'
                END
                FROM templates_items AS templates
                WHERE jobs."TemplateId" = templates."Id";
                """);

            migrationBuilder.Sql(
                """
                UPDATE templates_generation_jobs
                SET "QueueTier" = 'admin'
                WHERE "UserId" = '00000000-0000-0000-0000-000000000000';
                """);

            // Production rollout: these indexes can be large on templates_generation_jobs.
            // PostgreSQL CREATE INDEX CONCURRENTLY must run outside the normal EF migration transaction.
            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY IF NOT EXISTS "IX_tgj_Status_QueueMediaType_QueueTier_QueuedAtUtc"
                ON templates_generation_jobs ("Status", "QueueMediaType", "QueueTier", "QueuedAtUtc");
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY IF NOT EXISTS "IX_tgj_Status_QueueMediaType_StartedAtUtc"
                ON templates_generation_jobs ("Status", "QueueMediaType", "StartedAtUtc");
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_Status_QueueMediaType_QueueTier_QueuedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_Status_QueueMediaType_StartedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.DropColumn(
                name: "CancelledAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "EstimatedCompletionAtQueueUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "EstimatedWaitSecondsAtQueue",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "QueueMediaType",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "QueueTier",
                table: "templates_generation_jobs");
        }
    }
}
