using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <summary>
    /// Repairs existing deployments where the Scheduler V2 foundation and hot-index migrations
    /// were already recorded before legacy policy carry-forward and retry-safe index replacement
    /// were added to their sources.
    /// </summary>
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260729213000_RepairGenerationSchedulerV2ExistingDeployments")]
    public partial class RepairGenerationSchedulerV2ExistingDeployments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DO $migration$
                BEGIN
                    IF to_regclass('templates_generation_runtime_settings') IS NOT NULL THEN
                        EXECUTE $legacy$
                            UPDATE templates_generation_control_policy AS policy
                            SET
                                "Revision" = GREATEST(1, legacy."Version"),
                                "AdmissionEnabled" = NOT legacy."NewClaimsPaused",
                                "ConfirmedFalConcurrencyLimit" = GREATEST(1, legacy."FalConfiguredConcurrency"),
                                "ConfirmedAtUtc" = legacy."UpdatedAtUtc",
                                "ReservedHeadroom" = LEAST(
                                    GREATEST(0, legacy."FalReservedConcurrency"),
                                    GREATEST(0, legacy."FalConfiguredConcurrency" - 1)),
                                "ApplicationHardCeiling" = GREATEST(1, legacy."GlobalMaxConcurrent"),
                                "BaseGlobalMaxConcurrentGenerations" = GREATEST(1, legacy."GlobalMaxConcurrent"),
                                "BaseImageReservedConcurrentGenerations" = GREATEST(
                                    1,
                                    LEAST(legacy."ImageProtectedConcurrent", legacy."ImageMaxConcurrent")),
                                "BaseImageProtectedConcurrentGenerations" = GREATEST(
                                    1,
                                    LEAST(legacy."ImageProtectedConcurrent", legacy."ImageMaxConcurrent")),
                                "BaseImageMaxConcurrentGenerations" = GREATEST(1, legacy."ImageMaxConcurrent"),
                                "BaseVideoReservedConcurrentGenerations" = GREATEST(
                                    1,
                                    LEAST(legacy."VideoGuaranteedConcurrent", legacy."VideoMaxConcurrent")),
                                "BaseVideoMaxConcurrentGenerations" = GREATEST(1, legacy."VideoMaxConcurrent"),
                                "BaseVideoBorrowMaxConcurrentGenerations" = GREATEST(1, legacy."VideoBorrowMaxConcurrent"),
                                "BaseVideoPreprocessingMaxConcurrentGenerations" = 1,
                                "UpdatedAtUtc" = legacy."UpdatedAtUtc",
                                "UpdatedByAdminUserId" = legacy."UpdatedByAdminId",
                                "LastReason" = COALESCE(
                                    NULLIF(legacy."LastChangeReason", ''),
                                    'scheduler_v2_migrated_from_v1_existing_deployment')
                            FROM templates_generation_runtime_settings AS legacy
                            WHERE policy."Id" = '4db56d66-a023-4a1c-a28d-174c46d23d61'::uuid
                              AND legacy."Id" = 'f4d755ca-bf45-4ab7-92bf-b7a7ef6844c1'::uuid
                              AND policy."Revision" = 1
                              AND policy."AdmissionEnabled" = TRUE
                              AND policy."ConfirmedFalConcurrencyLimit" = 10
                              AND policy."ReservedHeadroom" = 2
                              AND policy."ApplicationHardCeiling" = 38
                              AND policy."BaseGlobalMaxConcurrentGenerations" = 8
                              AND policy."BaseImageReservedConcurrentGenerations" = 3
                              AND policy."BaseImageProtectedConcurrentGenerations" = 3
                              AND policy."BaseImageMaxConcurrentGenerations" = 7
                              AND policy."BaseVideoReservedConcurrentGenerations" = 2
                              AND policy."BaseVideoMaxConcurrentGenerations" = 4
                              AND policy."BaseVideoBorrowMaxConcurrentGenerations" = 2
                              AND policy."BaseVideoPreprocessingMaxConcurrentGenerations" = 1
                              AND policy."UpdatedByAdminUserId" IS NULL
                              AND policy."LastReason" IN (
                                  'scheduler_v2_bootstrap_legacy_admission_open',
                                  'scheduler_v2_bootstrap_default_admission_open')
                        $legacy$;
                    END IF;
                END
                $migration$;
                """);

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
            // The migration repairs indexes already present in the model and conditionally carries
            // forward operator state. Reversing either action would corrupt the previous schema or
            // overwrite runtime policy, so rollback intentionally leaves the repaired state intact.
        }

    }
}
