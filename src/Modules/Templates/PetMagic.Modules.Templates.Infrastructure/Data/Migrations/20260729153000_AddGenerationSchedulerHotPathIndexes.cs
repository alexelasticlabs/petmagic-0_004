using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260729153000_AddGenerationSchedulerHotPathIndexes")]
    public partial class AddGenerationSchedulerHotPathIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_ImportingMedia_NextAttempt";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tgj_ImportingMedia_NextAttempt"
                ON templates_generation_jobs ("Status", "MediaImportNextAttemptAtUtc")
                WHERE "Status" = 10;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc"
                ON templates_generation_provider_attempts ("Stage", "ProviderCompletedAtUtc" DESC)
                INCLUDE ("SubmittedAtUtc")
                WHERE "State" = 6
                  AND "SubmittedAtUtc" IS NOT NULL
                  AND "ProviderCompletedAtUtc" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_Completed_MediaType_ImportCompletedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tgj_Completed_MediaType_ImportCompletedAtUtc"
                ON templates_generation_jobs ("QueueMediaType", "MediaImportCompletedAtUtc" DESC)
                INCLUDE ("ImportStartedAtUtc")
                WHERE "Status" = 3
                  AND "ImportStartedAtUtc" IS NOT NULL
                  AND "MediaImportCompletedAtUtc" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_UserId_QueueTier_LastAttemptAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tgj_UserId_QueueTier_LastAttemptAtUtc"
                ON templates_generation_jobs ("UserId", "QueueTier", "LastAttemptAtUtc" DESC)
                WHERE "LastAttemptAtUtc" IS NOT NULL;
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                CREATE INDEX CONCURRENTLY "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc"
                ON templates_provider_webhook_inbox ("LockedAtUtc", "NextAttemptAtUtc")
                WHERE "Status" = 2 AND "LockedAtUtc" IS NOT NULL;
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_ImportingMedia_NextAttempt";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_Completed_MediaType_ImportCompletedAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tgj_UserId_QueueTier_LastAttemptAtUtc";
                """,
                suppressTransaction: true);

            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc";
                """,
                suppressTransaction: true);
        }
    }
}
