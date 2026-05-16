using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateMediaLifecycleTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LastUserMediaCleanupAttemptAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UserMediaDeletedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UserMediaCleanupFailureCode",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

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
                name: "IX_templates_generation_jobs_LastUserMediaCleanupAttemptAtUtc",
                table: "templates_generation_jobs",
                column: "LastUserMediaCleanupAttemptAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserMediaDeletedAtUtc",
                table: "templates_generation_jobs",
                column: "UserMediaDeletedAtUtc");

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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_media_records");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_LastUserMediaCleanupAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_UserMediaDeletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "LastUserMediaCleanupAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "UserMediaDeletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "UserMediaCleanupFailureCode",
                table: "templates_generation_jobs");
        }
    }
}
