using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGamificationSyncDeliveryState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "GamificationAttemptCount",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "GamificationLastErrorCode",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GamificationNextAttemptAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GamificationProcessedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            // Existing completed generations may already have applied this side effect. Suppress
            // automatic replay to avoid duplicate XP or wallet rewards, and mark the row for an
            // explicit audited admin reconciliation decision.
            migrationBuilder.Sql(
                """
                UPDATE templates_generation_jobs
                SET "GamificationProcessedAtUtc" = COALESCE("CompletedAtUtc", "UpdatedAtUtc", "CreatedAtUtc"),
                    "GamificationAttemptCount" = -1,
                    "GamificationLastErrorCode" = 'templates.gamification_legacy_review_required'
                WHERE "Status" = 3
                  AND "GamificationProcessedAtUtc" IS NULL;
                """);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY IF NOT EXISTS "IX_tgj_PendingGamification"
                ON templates_generation_jobs ("Status", "GamificationNextAttemptAtUtc", "CompletedAtUtc")
                WHERE "Status" = 3 AND "GamificationProcessedAtUtc" IS NULL;
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_PendingGamification";
                """,
                suppressTransaction: true);

            migrationBuilder.DropColumn(
                name: "GamificationAttemptCount",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationLastErrorCode",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationNextAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationProcessedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
