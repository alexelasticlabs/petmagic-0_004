using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260727153000_AddTemplateModerationLeases")]
    public partial class AddTemplateModerationLeases : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ModerationLeaseClaimedAtUtc",
                table: "templates_analytics_events",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ModerationLeaseExpiresAtUtc",
                table: "templates_analytics_events",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ModerationLeaseOwnerUserId",
                table: "templates_analytics_events",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ModerationVersion",
                table: "templates_analytics_events",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_moderation_lease",
                table: "templates_analytics_events",
                columns: new[] { "ModerationStatus", "ModerationLeaseExpiresAtUtc", "CreatedAtUtc" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_templates_analytics_events_moderation_lease",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationLeaseClaimedAtUtc",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationLeaseExpiresAtUtc",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationLeaseOwnerUserId",
                table: "templates_analytics_events");

            migrationBuilder.DropColumn(
                name: "ModerationVersion",
                table: "templates_analytics_events");
        }
    }
}
