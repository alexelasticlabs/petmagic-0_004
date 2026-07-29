using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationControlFoundation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "AppliedPolicyRevision",
                table: "templates_runtime_config_fingerprints",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GenerationDispatchConcurrency",
                table: "templates_runtime_config_fingerprints",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GenerationMaintenanceConcurrency",
                table: "templates_runtime_config_fingerprints",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "GenerationSchedulerV2Enabled",
                table: "templates_runtime_config_fingerprints",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastProgressAtUtc",
                table: "templates_runtime_config_fingerprints",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MediaImportConcurrency",
                table: "templates_runtime_config_fingerprints",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ProviderReconciliationConcurrency",
                table: "templates_runtime_config_fingerprints",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MediaImportAttemptCount",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "MediaImportNextAttemptAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "OriginalImportedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PreviewImportedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "WatermarkImportedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "templates_generation_control_policy",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Revision = table.Column<long>(type: "bigint", nullable: false, defaultValue: 1L),
                    AdmissionEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    ConfirmedFalConcurrencyLimit = table.Column<int>(type: "integer", nullable: false),
                    ConfirmedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReservedHeadroom = table.Column<int>(type: "integer", nullable: false),
                    ApplicationHardCeiling = table.Column<int>(type: "integer", nullable: false),
                    BaseGlobalMaxConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseImageReservedConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseImageProtectedConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseImageMaxConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseVideoReservedConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseVideoMaxConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseVideoBorrowMaxConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    BaseVideoPreprocessingMaxConcurrentGenerations = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedByAdminUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    LastReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_control_policy", x => x.Id);
                    table.CheckConstraint("CK_tgcp_BaseProfile", "\"BaseGlobalMaxConcurrentGenerations\" > 0 AND \"BaseImageReservedConcurrentGenerations\" > 0 AND \"BaseImageProtectedConcurrentGenerations\" > 0 AND \"BaseImageMaxConcurrentGenerations\" > 0 AND \"BaseVideoReservedConcurrentGenerations\" > 0 AND \"BaseVideoMaxConcurrentGenerations\" > 0 AND \"BaseVideoBorrowMaxConcurrentGenerations\" > 0 AND \"BaseVideoPreprocessingMaxConcurrentGenerations\" > 0");
                    table.CheckConstraint("CK_tgcp_ProviderCapacity", "\"ConfirmedFalConcurrencyLimit\" > 0 AND \"ReservedHeadroom\" >= 0 AND \"ReservedHeadroom\" < \"ConfirmedFalConcurrencyLimit\" AND \"ApplicationHardCeiling\" > 0");
                    table.CheckConstraint("CK_tgcp_Revision", "\"Revision\" > 0");
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_control_receipts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    PolicyRevision = table.Column<long>(type: "bigint", nullable: false),
                    ResponseJson = table.Column<string>(type: "text", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_control_receipts", x => x.Id);
                    table.CheckConstraint("CK_tgcr_PolicyRevision", "\"PolicyRevision\" > 0");
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_provider_attempts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    GenerationJobId = table.Column<Guid>(type: "uuid", nullable: false),
                    Stage = table.Column<int>(type: "integer", nullable: false),
                    Ordinal = table.Column<int>(type: "integer", nullable: false),
                    State = table.Column<int>(type: "integer", nullable: false),
                    IsBorrowedCapacity = table.Column<bool>(type: "boolean", nullable: false),
                    Provider = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    SubmissionTokenHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ProviderRequestId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    ProviderStatusUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    ProviderResponseUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    ProviderCancelUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    NextPollAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SubmissionDeadlineAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ProcessingDeadlineAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReconciliationDeadlineAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SubmitAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    PollAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    CancelAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    LastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    LockedBy = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    LockedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<long>(type: "bigint", nullable: false, defaultValue: 0L),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SubmittedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ProviderCompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_provider_attempts", x => x.Id);
                    table.CheckConstraint("CK_tgpa_AttemptCounts", "\"SubmitAttemptCount\" >= 0 AND \"PollAttemptCount\" >= 0 AND \"CancelAttemptCount\" >= 0");
                    table.CheckConstraint("CK_tgpa_Deadlines", "\"SubmissionDeadlineAtUtc\" <= \"ProcessingDeadlineAtUtc\" AND \"ProcessingDeadlineAtUtc\" <= \"ReconciliationDeadlineAtUtc\"");
                    table.CheckConstraint("CK_tgpa_Ordinal", "\"Ordinal\" > 0");
                    table.CheckConstraint("CK_tgpa_TokenHash", "length(\"SubmissionTokenHash\") = 64");
                    table.ForeignKey(
                        name: "FK_templates_generation_provider_attempts_templates_generation~",
                        column: x => x.GenerationJobId,
                        principalTable: "templates_generation_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "templates_provider_runtime_snapshots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    BalanceState = table.Column<int>(type: "integer", nullable: false),
                    StatusChangedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CurrentBalanceUsd = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: true),
                    LastSuccessfulAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CheckedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ConsecutiveFailures = table.Column<int>(type: "integer", nullable: false),
                    LastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    RefreshLeaseId = table.Column<Guid>(type: "uuid", nullable: true),
                    RefreshLeaseExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_provider_runtime_snapshots", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_provider_webhook_inbox",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ProviderAttemptId = table.Column<Guid>(type: "uuid", nullable: true),
                    GenerationJobId = table.Column<Guid>(type: "uuid", nullable: true),
                    Provider = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DeduplicationKey = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    CallbackTokenHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ProviderRequestId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    PayloadJson = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    SignatureVerifiedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReceivedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    FailureCount = table.Column<int>(type: "integer", nullable: false),
                    LockedBy = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    LockedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ProcessedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeadLetteredAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_provider_webhook_inbox", x => x.Id);
                    table.CheckConstraint("CK_tpwbi_AttemptCount", "\"AttemptCount\" >= 0");
                    table.CheckConstraint("CK_tpwbi_FailureCount", "\"FailureCount\" >= 0");
                    table.ForeignKey(
                        name: "FK_templates_provider_webhook_inbox_templates_generation_jobs_~",
                        column: x => x.GenerationJobId,
                        principalTable: "templates_generation_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_templates_provider_webhook_inbox_templates_generation_provi~",
                        column: x => x.ProviderAttemptId,
                        principalTable: "templates_generation_provider_attempts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_tgj_ImportingMedia_NextAttempt",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "MediaImportNextAttemptAtUtc" },
                filter: "\"Status\" = 10");

            migrationBuilder.CreateIndex(
                name: "IX_tgcp_UpdatedAtUtc",
                table: "templates_generation_control_policy",
                column: "UpdatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_tgcr_PolicyRevision_CreatedAtUtc",
                table: "templates_generation_control_receipts",
                columns: new[] { "PolicyRevision", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "UX_tgcr_ActorUserId_IdempotencyKey",
                table: "templates_generation_control_receipts",
                columns: new[] { "ActorUserId", "IdempotencyKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tgpa_JobId_CreatedAtUtc",
                table: "templates_generation_provider_attempts",
                columns: new[] { "GenerationJobId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_tgpa_State_LockedAtUtc",
                table: "templates_generation_provider_attempts",
                columns: new[] { "State", "LockedAtUtc" },
                filter: "\"State\" IN (1, 2, 3, 4, 5)");

            migrationBuilder.CreateIndex(
                name: "IX_tgpa_State_NextPollAtUtc",
                table: "templates_generation_provider_attempts",
                columns: new[] { "State", "NextPollAtUtc" },
                filter: "\"State\" IN (1, 2, 3, 4, 5)");

            migrationBuilder.CreateIndex(
                name: "UX_tgpa_JobId_Stage_Ordinal",
                table: "templates_generation_provider_attempts",
                columns: new[] { "GenerationJobId", "Stage", "Ordinal" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UX_tgpa_Provider_RequestId",
                table: "templates_generation_provider_attempts",
                columns: new[] { "Provider", "ProviderRequestId" },
                unique: true,
                filter: "\"ProviderRequestId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "UX_tgpa_SubmissionTokenHash",
                table: "templates_generation_provider_attempts",
                column: "SubmissionTokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tprs_RefreshLeaseExpiresAtUtc",
                table: "templates_provider_runtime_snapshots",
                column: "RefreshLeaseExpiresAtUtc");

            migrationBuilder.CreateIndex(
                name: "UX_tprs_Provider",
                table: "templates_provider_runtime_snapshots",
                column: "Provider",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_CallbackTokenHash",
                table: "templates_provider_webhook_inbox",
                column: "CallbackTokenHash",
                filter: "\"CallbackTokenHash\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_GenerationJobId",
                table: "templates_provider_webhook_inbox",
                column: "GenerationJobId");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_ProviderAttemptId",
                table: "templates_provider_webhook_inbox",
                column: "ProviderAttemptId");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_ProviderRequestId",
                table: "templates_provider_webhook_inbox",
                column: "ProviderRequestId",
                filter: "\"ProviderRequestId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_Status_NextAttemptAtUtc",
                table: "templates_provider_webhook_inbox",
                columns: new[] { "Status", "NextAttemptAtUtc" },
                filter: "\"Status\" IN (1, 4)");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_Terminal_UpdatedAtUtc",
                table: "templates_provider_webhook_inbox",
                columns: new[] { "Status", "UpdatedAtUtc" },
                filter: "\"Status\" IN (3, 5)");

            migrationBuilder.CreateIndex(
                name: "UX_tpwbi_Provider_Dedupe",
                table: "templates_provider_webhook_inbox",
                columns: new[] { "Provider", "DeduplicationKey" },
                unique: true);

            migrationBuilder.Sql(
                """
                INSERT INTO templates_generation_control_policy (
                    "Id",
                    "Revision",
                    "AdmissionEnabled",
                    "ConfirmedFalConcurrencyLimit",
                    "ConfirmedAtUtc",
                    "ReservedHeadroom",
                    "ApplicationHardCeiling",
                    "BaseGlobalMaxConcurrentGenerations",
                    "BaseImageReservedConcurrentGenerations",
                    "BaseImageProtectedConcurrentGenerations",
                    "BaseImageMaxConcurrentGenerations",
                    "BaseVideoReservedConcurrentGenerations",
                    "BaseVideoMaxConcurrentGenerations",
                    "BaseVideoBorrowMaxConcurrentGenerations",
                    "BaseVideoPreprocessingMaxConcurrentGenerations",
                    "UpdatedAtUtc",
                    "LastReason")
                VALUES (
                    '4db56d66-a023-4a1c-a28d-174c46d23d61',
                    1,
                    TRUE,
                    10,
                    NOW(),
                    2,
                    38,
                    8,
                    3,
                    3,
                    7,
                    2,
                    4,
                    2,
                    1,
                    NOW(),
                    'scheduler_v2_bootstrap_legacy_admission_open')
                ON CONFLICT ("Id") DO NOTHING;

                INSERT INTO templates_provider_runtime_snapshots (
                    "Id",
                    "Provider",
                    "BalanceState",
                    "StatusChangedAtUtc",
                    "ConsecutiveFailures",
                    "UpdatedAtUtc")
                VALUES (
                    '5a829764-afcb-44dd-91f3-d9f374b8742d',
                    'fal',
                    0,
                    NOW(),
                    0,
                    NOW())
                ON CONFLICT ("Provider") DO NOTHING;
                """);

            migrationBuilder.Sql(
                """
                WITH active_legacy_jobs AS (
                    SELECT
                        job.*,
                        CASE
                            WHEN job."CurrentProviderStage" = 'video_generation'
                                OR job."MotionProviderRequestId" IS NOT NULL THEN 3
                            WHEN job."CurrentProviderStage" = 'video_preprocessing'
                                OR job."QueueMediaType" = 'video' THEN 2
                            ELSE 1
                        END AS provider_stage,
                        COALESCE(
                            job."ProviderSubmittedAtUtc",
                            job."UpdatedAtUtc",
                            job."CreatedAtUtc",
                            NOW()) AS provider_started_at
                    FROM templates_generation_jobs AS job
                    WHERE job."Status" IN (7, 8, 9)
                )
                INSERT INTO templates_generation_provider_attempts (
                    "Id",
                    "GenerationJobId",
                    "Stage",
                    "Ordinal",
                    "State",
                    "IsBorrowedCapacity",
                    "Provider",
                    "SubmissionTokenHash",
                    "ProviderRequestId",
                    "ProviderStatusUrl",
                    "ProviderResponseUrl",
                    "ProviderCancelUrl",
                    "NextPollAtUtc",
                    "SubmissionDeadlineAtUtc",
                    "ProcessingDeadlineAtUtc",
                    "ReconciliationDeadlineAtUtc",
                    "SubmitAttemptCount",
                    "PollAttemptCount",
                    "CancelAttemptCount",
                    "LastErrorCode",
                    "Version",
                    "CreatedAtUtc",
                    "UpdatedAtUtc",
                    "SubmittedAtUtc")
                SELECT
                    md5('legacy-provider-attempt:' || legacy."Id"::text || ':' || legacy.provider_stage::text)::uuid,
                    legacy."Id",
                    legacy.provider_stage,
                    1,
                    CASE legacy."Status"
                        WHEN 8 THEN 3
                        WHEN 9 THEN 4
                        ELSE 5
                    END,
                    FALSE,
                    'fal',
                    upper(
                        md5('legacy-provider-token:' || legacy."Id"::text || ':' || legacy.provider_stage::text)
                        || md5('legacy-provider-token-2:' || legacy."Id"::text || ':' || legacy.provider_stage::text)),
                    CASE
                        WHEN legacy.provider_stage = 3 THEN legacy."MotionProviderRequestId"
                        ELSE legacy."PreprocessingProviderRequestId"
                    END,
                    CASE
                        WHEN legacy.provider_stage = 3 THEN legacy."MotionProviderStatusUrl"
                        ELSE legacy."PreprocessingProviderStatusUrl"
                    END,
                    CASE
                        WHEN legacy.provider_stage = 3 THEN legacy."MotionProviderResponseUrl"
                        ELSE legacy."PreprocessingProviderResponseUrl"
                    END,
                    CASE
                        WHEN legacy.provider_stage = 3 THEN legacy."MotionProviderCancelUrl"
                        ELSE legacy."PreprocessingProviderCancelUrl"
                    END,
                    NOW(),
                    legacy.provider_started_at + INTERVAL '5 minutes',
                    legacy.provider_started_at + INTERVAL '2 hours',
                    legacy.provider_started_at + INTERVAL '24 hours',
                    GREATEST(1, legacy."AttemptCount"),
                    0,
                    0,
                    legacy."LastErrorCode",
                    0,
                    legacy.provider_started_at,
                    NOW(),
                    legacy."ProviderSubmittedAtUtc"
                FROM active_legacy_jobs AS legacy
                ON CONFLICT ("GenerationJobId", "Stage", "Ordinal") DO NOTHING;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_generation_control_policy");

            migrationBuilder.DropTable(
                name: "templates_generation_control_receipts");

            migrationBuilder.DropTable(
                name: "templates_provider_runtime_snapshots");

            migrationBuilder.DropTable(
                name: "templates_provider_webhook_inbox");

            migrationBuilder.DropTable(
                name: "templates_generation_provider_attempts");

            migrationBuilder.DropIndex(
                name: "IX_tgj_ImportingMedia_NextAttempt",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "AppliedPolicyRevision",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "GenerationDispatchConcurrency",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "GenerationMaintenanceConcurrency",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "GenerationSchedulerV2Enabled",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "LastProgressAtUtc",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "MediaImportConcurrency",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "ProviderReconciliationConcurrency",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "MediaImportAttemptCount",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MediaImportNextAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "OriginalImportedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreviewImportedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "WatermarkImportedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
