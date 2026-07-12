using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Gamification.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class PreserveGamificationEventOccurrence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_gamification_generation_events_UserId_ProcessedAtUtc",
                table: "gamification_generation_events");

            migrationBuilder.AddColumn<DateTime>(
                name: "OccurredAtUtc",
                table: "gamification_generation_events",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<Guid>(
                name: "PetId",
                table: "gamification_generation_events",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.Sql(
                """
                UPDATE gamification_generation_events
                SET "OccurredAtUtc" = "ProcessedAtUtc",
                    "PetId" = "UserId"
                WHERE "PetId" = '00000000-0000-0000-0000-000000000000'
                   OR "OccurredAtUtc" = '-infinity'
                   OR "OccurredAtUtc" < TIMESTAMPTZ '2000-01-01 00:00:00+00';
                """);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_generation_events_UserId_PetId_OccurredAtUtc",
                table: "gamification_generation_events",
                columns: new[] { "UserId", "PetId", "OccurredAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_gamification_generation_events_UserId_PetId_OccurredAtUtc",
                table: "gamification_generation_events");

            migrationBuilder.DropColumn(
                name: "OccurredAtUtc",
                table: "gamification_generation_events");

            migrationBuilder.DropColumn(
                name: "PetId",
                table: "gamification_generation_events");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_generation_events_UserId_ProcessedAtUtc",
                table: "gamification_generation_events",
                columns: new[] { "UserId", "ProcessedAtUtc" });
        }
    }
}
