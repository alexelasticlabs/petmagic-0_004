using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Gamification.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddGamificationDeliveryIdempotency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "WeeklyFreezeAllowance",
                table: "gamification_daily_streaks",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.CreateTable(
                name: "gamification_generation_events",
                columns: table => new
                {
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    WeekStartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ProcessedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_generation_events", x => x.GenerationId);
                });

            migrationBuilder.CreateTable(
                name: "gamification_share_events",
                columns: table => new
                {
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    WeekStartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    SharedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_share_events", x => x.GenerationId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_gamification_generation_events_UserId_ProcessedAtUtc",
                table: "gamification_generation_events",
                columns: new[] { "UserId", "ProcessedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_gamification_generation_events_UserId_WeekStartDate_Templat~",
                table: "gamification_generation_events",
                columns: new[] { "UserId", "WeekStartDate", "TemplateId" });

            migrationBuilder.CreateIndex(
                name: "IX_gamification_share_events_UserId_WeekStartDate",
                table: "gamification_share_events",
                columns: new[] { "UserId", "WeekStartDate" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "gamification_generation_events");

            migrationBuilder.DropTable(
                name: "gamification_share_events");

            migrationBuilder.DropColumn(
                name: "WeeklyFreezeAllowance",
                table: "gamification_daily_streaks");
        }
    }
}
