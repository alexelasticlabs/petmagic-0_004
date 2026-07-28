using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationRuntimeControl : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "AppliedSettingsVersion",
                table: "templates_runtime_config_fingerprints",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.AddColumn<int>(
                name: "ConfiguredLoops",
                table: "templates_runtime_config_fingerprints",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "NewClaimsPaused",
                table: "templates_runtime_config_fingerprints",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "templates_fal_provider_health",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BalanceUsd = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: true),
                    Status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    LastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    ConsecutiveFailures = table.Column<int>(type: "integer", nullable: false),
                    CheckedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSuccessAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_fal_provider_health", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_operational_alerts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(96)", maxLength: 96, nullable: false),
                    Severity = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Title = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Message = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    ActivatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastObservedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ResolvedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_operational_alerts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_runtime_settings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    GlobalMaxConcurrent = table.Column<int>(type: "integer", nullable: false),
                    ImageMaxConcurrent = table.Column<int>(type: "integer", nullable: false),
                    ImageProtectedConcurrent = table.Column<int>(type: "integer", nullable: false),
                    VideoGuaranteedConcurrent = table.Column<int>(type: "integer", nullable: false),
                    VideoMaxConcurrent = table.Column<int>(type: "integer", nullable: false),
                    VideoBorrowMaxConcurrent = table.Column<int>(type: "integer", nullable: false),
                    WorkerLoopsPerInstance = table.Column<int>(type: "integer", nullable: false),
                    FalConfiguredConcurrency = table.Column<int>(type: "integer", nullable: false),
                    FalReservedConcurrency = table.Column<int>(type: "integer", nullable: false),
                    FalBalanceLowThresholdUsd = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: false),
                    FalBalanceCriticalThresholdUsd = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: false),
                    NewClaimsPaused = table.Column<bool>(type: "boolean", nullable: false),
                    DrainOperationId = table.Column<Guid>(type: "uuid", nullable: true),
                    LastChangeReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    UpdatedByAdminId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_runtime_settings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_render_scale_operations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    InitialInstances = table.Column<int>(type: "integer", nullable: true),
                    TargetInstances = table.Column<int>(type: "integer", nullable: false),
                    LoopsPerInstance = table.Column<int>(type: "integer", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    CorrelationId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    DrainRuntimeVersion = table.Column<long>(type: "bigint", nullable: true),
                    DrainStartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ScaleRequestedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    VerificationDeadlineAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelledAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    ErrorMessage = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LockId = table.Column<Guid>(type: "uuid", nullable: true),
                    LockExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_render_scale_operations", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_operational_alert_acknowledgements",
                columns: table => new
                {
                    AlertId = table.Column<Guid>(type: "uuid", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    AlertActivatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AcknowledgedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_operational_alert_acknowledgements", x => new { x.AlertId, x.AdminUserId });
                    table.ForeignKey(
                        name: "FK_templates_generation_operational_alert_acknowledgements_tem~",
                        column: x => x.AlertId,
                        principalTable: "templates_generation_operational_alerts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_fal_provider_health_UpdatedAtUtc",
                table: "templates_fal_provider_health",
                column: "UpdatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_tgoaa_AdminUserId_AcknowledgedAtUtc",
                table: "templates_generation_operational_alert_acknowledgements",
                columns: new[] { "AdminUserId", "AcknowledgedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_operational_alerts_Code",
                table: "templates_generation_operational_alerts",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tgoa_ResolvedAtUtc_UpdatedAtUtc",
                table: "templates_generation_operational_alerts",
                columns: new[] { "ResolvedAtUtc", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_runtime_settings_UpdatedAtUtc",
                table: "templates_generation_runtime_settings",
                column: "UpdatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_trso_LockExpiresAtUtc",
                table: "templates_render_scale_operations",
                column: "LockExpiresAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_trso_Status_NextAttemptAtUtc",
                table: "templates_render_scale_operations",
                columns: new[] { "Status", "NextAttemptAtUtc" });

            migrationBuilder.CreateIndex(
                name: "UX_trso_ActorUserId_IdempotencyKey",
                table: "templates_render_scale_operations",
                columns: new[] { "ActorUserId", "IdempotencyKey" },
                unique: true);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX "UX_trso_single_active_operation"
                ON templates_render_scale_operations ((1))
                WHERE "Status" IN ('requested', 'draining', 'scaling', 'verifying')
                   OR ("Status" IN ('cancelled', 'failed')
                       AND "NextAttemptAtUtc" < TIMESTAMPTZ '9999-12-31 23:59:59.999999+00');
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_fal_provider_health");

            migrationBuilder.DropTable(
                name: "templates_generation_operational_alert_acknowledgements");

            migrationBuilder.DropTable(
                name: "templates_generation_runtime_settings");

            migrationBuilder.DropTable(
                name: "templates_render_scale_operations");

            migrationBuilder.DropTable(
                name: "templates_generation_operational_alerts");

            migrationBuilder.DropColumn(
                name: "AppliedSettingsVersion",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "ConfiguredLoops",
                table: "templates_runtime_config_fingerprints");

            migrationBuilder.DropColumn(
                name: "NewClaimsPaused",
                table: "templates_runtime_config_fingerprints");
        }
    }
}
