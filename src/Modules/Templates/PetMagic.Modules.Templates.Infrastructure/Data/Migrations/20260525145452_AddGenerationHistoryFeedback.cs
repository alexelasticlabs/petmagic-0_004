using System;

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGenerationHistoryFeedback : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ResultViewedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

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

            migrationBuilder.CreateIndex(
                name: "IX_templates_generation_jobs_UserId_Status_ResultViewedAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "Status", "ResultViewedAtUtc" });

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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_generation_feedback");

            migrationBuilder.DropIndex(
                name: "IX_templates_generation_jobs_UserId_Status_ResultViewedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "ResultViewedAtUtc",
                table: "templates_generation_jobs");
        }
    }
}
