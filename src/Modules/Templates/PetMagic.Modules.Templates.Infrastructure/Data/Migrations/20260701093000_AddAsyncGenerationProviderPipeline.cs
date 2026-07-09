using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260701093000_AddAsyncGenerationProviderPipeline")]
    public partial class AddAsyncGenerationProviderPipeline : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CurrentProviderStage",
                table: "templates_generation_jobs",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ImportStartedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MotionProviderResponseUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MotionProviderStatusUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProviderCompletedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProviderStatus",
                table: "templates_generation_jobs",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProviderStatusCheckedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProviderSubmittedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreprocessingProviderResponseUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreprocessingProviderStatusUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "WebhookReceivedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_templates_generation_jobs_UserId_IdempotencyKey_active";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_templates_generation_jobs_UserId_RequestHash_active";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tgj_Status_ProviderStatusCheckedAtUtc"
                ON templates_generation_jobs ("Status", "ProviderStatusCheckedAtUtc");
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_tgj_PreprocessingProviderRequestId"
                ON templates_generation_jobs ("PreprocessingProviderRequestId")
                WHERE "PreprocessingProviderRequestId" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_tgj_MotionProviderRequestId"
                ON templates_generation_jobs ("MotionProviderRequestId")
                WHERE "MotionProviderRequestId" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_templates_generation_jobs_UserId_IdempotencyKey_active"
                ON templates_generation_jobs ("UserId", "IdempotencyKey")
                WHERE "Status" IN (1, 2, 6, 7, 8, 9, 10) AND "IdempotencyKey" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_templates_generation_jobs_UserId_RequestHash_active"
                ON templates_generation_jobs ("UserId", "RequestHash")
                WHERE "Status" IN (1, 2, 6, 7, 8, 9, 10) AND "RequestHash" IS NOT NULL;
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_templates_generation_jobs_UserId_RequestHash_active";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_templates_generation_jobs_UserId_IdempotencyKey_active";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_tgj_MotionProviderRequestId";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_tgj_PreprocessingProviderRequestId";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_Status_ProviderStatusCheckedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_templates_generation_jobs_UserId_IdempotencyKey_active"
                ON templates_generation_jobs ("UserId", "IdempotencyKey")
                WHERE "Status" IN (1, 2) AND "IdempotencyKey" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "UX_templates_generation_jobs_UserId_RequestHash_active"
                ON templates_generation_jobs ("UserId", "RequestHash")
                WHERE "Status" IN (1, 2) AND "RequestHash" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.DropColumn(
                name: "CurrentProviderStage",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ImportStartedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionProviderResponseUrl",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionProviderStatusUrl",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ProviderCompletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ProviderStatus",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ProviderStatusCheckedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ProviderSubmittedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingProviderResponseUrl",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingProviderStatusUrl",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "WebhookReceivedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
