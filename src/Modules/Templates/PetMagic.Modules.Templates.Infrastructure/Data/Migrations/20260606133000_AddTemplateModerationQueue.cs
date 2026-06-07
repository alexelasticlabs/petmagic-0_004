using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260606133000_AddTemplateModerationQueue")]
    public partial class AddTemplateModerationQueue : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ModerationStatus",
                table: "templates_analytics_events",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "pending");

            migrationBuilder.AddColumn<string>(
                name: "ModerationComment",
                table: "templates_analytics_events",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ModeratedAtUtc",
                table: "templates_analytics_events",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_ModerationStatus_CreatedAtUtc",
                table: "templates_analytics_events",
                columns: new[] { "ModerationStatus", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_analytics_events_ModerationStatus_CreatedAtUtc",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModeratedAtUtc",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationComment",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationStatus",
                table: "templates_analytics_events");
        }
    }
}
