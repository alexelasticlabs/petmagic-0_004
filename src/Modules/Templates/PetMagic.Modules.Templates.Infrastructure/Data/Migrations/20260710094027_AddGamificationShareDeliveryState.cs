using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGamificationShareDeliveryState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "GamificationShareAttemptCount",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "GamificationShareLastErrorCode",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GamificationShareNextAttemptAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GamificationShareProcessedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GamificationShareRequestedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY IF NOT EXISTS "IX_tgj_PendingGamificationShare"
                ON templates_generation_jobs ("GamificationShareNextAttemptAtUtc", "GamificationShareRequestedAtUtc")
                WHERE "GamificationShareRequestedAtUtc" IS NOT NULL
                  AND "GamificationShareProcessedAtUtc" IS NULL;
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_PendingGamificationShare";
                """,
                suppressTransaction: true);

            migrationBuilder.DropColumn(
                name: "GamificationShareAttemptCount",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationShareLastErrorCode",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationShareNextAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationShareProcessedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "GamificationShareRequestedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
