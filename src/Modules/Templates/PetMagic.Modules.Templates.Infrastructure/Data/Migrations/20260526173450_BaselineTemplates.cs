using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class BaselineTemplates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_categories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    NormalizedName = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    IsArchived = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_categories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateType = table.Column<int>(type: "integer", nullable: false),
                    Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    ShortDescription = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: false),
                    PetPhotoRequirements = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Category = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Tags = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    IsPremium = table.Column<bool>(type: "boolean", nullable: false),
                    TokenCost = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    PromoBadgeMode = table.Column<int>(type: "integer", nullable: false),
                    MusicDescription = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: true),
                    ReferenceVideoDurationSeconds = table.Column<double>(type: "double precision", nullable: true),
                    CharacterOrientation = table.Column<int>(type: "integer", nullable: true),
                    ImageModel = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    ImagePrompt = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    PreprocessingModel = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    PreprocessingPrompt = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    KlingModel = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    KlingPrompt = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    KeepOriginalSound = table.Column<bool>(type: "boolean", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_items", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_push_device_tokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Token = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: false),
                    Platform = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    DeviceId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    AppVersion = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Locale = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSeenAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    DisabledAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_push_device_tokens", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "templates_analytics_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Source = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DeviceClass = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    CountryCode = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    FeedbackMessage = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_analytics_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_analytics_events_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "templates_assets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    AssetKind = table.Column<int>(type: "integer", nullable: false),
                    Url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                    FileName = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    ContentType = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    DurationSeconds = table.Column<double>(type: "double precision", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_assets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_assets_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_jobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    TokenCost = table.Column<int>(type: "integer", nullable: false),
                    SourceImageUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                    SourceImageFileName = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    SourceImageContentType = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    SourceImageFileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    NormalizedImageUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    ReferenceMotionUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    OutputUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    UsedPreprocessingModel = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    UsedKlingModel = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    PreprocessingProviderRequestId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    PreprocessingInferenceTimeSeconds = table.Column<double>(type: "double precision", nullable: true),
                    MotionProviderRequestId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    MotionInferenceTimeSeconds = table.Column<double>(type: "double precision", nullable: true),
                    OutputVideoDurationSeconds = table.Column<double>(type: "double precision", nullable: true),
                    MotionProviderCostUsd = table.Column<decimal>(type: "numeric(12,4)", precision: 12, scale: 4, nullable: true),
                    PreprocessingCompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    MotionGenerationCompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    MediaImportCompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    FailureCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    FailureMessage = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    QueuedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ChargedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RefundedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RefundAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    RefundLastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    RefundLastAttemptedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    StartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResultViewedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UserMediaDeletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastUserMediaCleanupAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UserMediaCleanupFailureCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_jobs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_generation_jobs_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "templates_generation_feedback",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    Rating = table.Column<int>(type: "integer", nullable: false),
                    SelectedReasons = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    Comment = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    InputPhotoQualityScore = table.Column<double>(type: "double precision", nullable: true),
                    ModelUsed = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    GenerationDurationSeconds = table.Column<double>(type: "double precision", nullable: true),
                    ProviderRequestId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_generation_feedback", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_generation_feedback_templates_generation_jobs_Gen~",
                        column: x => x.GenerationId,
                        principalTable: "templates_generation_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_templates_generation_feedback_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "templates_media_records",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                    FileName = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    ContentType = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    Role = table.Column<int>(type: "integer", nullable: false),
                    LifecycleState = table.Column<int>(type: "integer", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: true),
                    GenerationJobId = table.Column<Guid>(type: "uuid", nullable: true),
                    UploadedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AttachedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastCleanupAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    FailureCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    FailureMessage = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_media_records", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_media_records_templates_generation_jobs_Generatio~",
                        column: x => x.GenerationJobId,
                        principalTable: "templates_generation_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_templates_media_records_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_CountryCode",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "CountryCode" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_CreatedAtUtc",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_DeviceClass",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "DeviceClass" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_EventType_CreatedAtUtc",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "EventType", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_Source",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "Source" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_assets_TemplateId_AssetKind",
                table: "templates_assets",
                columns: new[] { "TemplateId", "AssetKind" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_categories_IsArchived_Name",
                table: "templates_categories",
                columns: new[] { "IsArchived", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_categories_NormalizedName",
                table: "templates_categories",
                column: "NormalizedName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_feedback_GenerationId_UserId",
                table: "templates_generation_feedback",
                columns: new[] { "GenerationId", "UserId" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_feedback_TemplateId_CreatedAtUtc",
                table: "templates_generation_feedback",
                columns: new[] { "TemplateId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_feedback_TemplateId_Rating_CreatedAtUtc",
                table: "templates_generation_feedback",
                columns: new[] { "TemplateId", "Rating", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_LastUserMediaCleanupAttemptAtUtc",
                table: "templates_generation_jobs",
                column: "LastUserMediaCleanupAttemptAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_Status_CompletedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "CompletedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_Status_QueuedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "QueuedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAt~",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "RefundedAtUtc", "RefundLastAttemptedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_TemplateId_Status_CreatedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "TemplateId", "Status", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserId_CreatedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserId_Status_ResultViewedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "Status", "ResultViewedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserMediaDeletedAtUtc",
                table: "templates_generation_jobs",
                column: "UserMediaDeletedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_Status_Category",
                table: "templates_items",
                columns: new[] { "Status", "Category" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_items_TemplateType_Status_UpdatedAtUtc",
                table: "templates_items",
                columns: new[] { "TemplateType", "Status", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_media_records_GenerationJobId_LifecycleState",
                table: "templates_media_records",
                columns: new[] { "GenerationJobId", "LifecycleState" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_media_records_LifecycleState_ExpiresAtUtc",
                table: "templates_media_records",
                columns: new[] { "LifecycleState", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_media_records_TemplateId_LifecycleState",
                table: "templates_media_records",
                columns: new[] { "TemplateId", "LifecycleState" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_media_records_Url",
                table: "templates_media_records",
                column: "Url",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_device_tokens_Token",
                table: "templates_push_device_tokens",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_device_tokens_UserId_DisabledAtUtc_LastSeenA~",
                table: "templates_push_device_tokens",
                columns: new[] { "UserId", "DisabledAtUtc", "LastSeenAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_analytics_events");

            migrationBuilder.DropTable(
                name: "templates_assets");

            migrationBuilder.DropTable(
                name: "templates_categories");

            migrationBuilder.DropTable(
                name: "templates_generation_feedback");

            migrationBuilder.DropTable(
                name: "templates_media_records");

            migrationBuilder.DropTable(
                name: "templates_push_device_tokens");

            migrationBuilder.DropTable(
                name: "templates_generation_jobs");

            migrationBuilder.DropTable(
                name: "templates_items");
        }
    }
}
