using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260516172000_AddTemplateGenerationJobs")]
public sealed class AddTemplateGenerationJobs : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
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
                AttemptCount = table.Column<int>(type: "integer", nullable: false),
                FailureCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                FailureMessage = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                QueuedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                LastAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                ChargedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                RefundedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                StartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
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

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_Status_QueuedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "Status", "QueuedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_TemplateId_Status_CreatedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "TemplateId", "Status", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_UserId_CreatedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "UserId", "CreatedAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_generation_jobs");
    }
}
