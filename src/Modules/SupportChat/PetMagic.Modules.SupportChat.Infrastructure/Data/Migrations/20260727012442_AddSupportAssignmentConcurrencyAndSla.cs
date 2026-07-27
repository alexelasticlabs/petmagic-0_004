using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportAssignmentConcurrencyAndSla : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "FirstResponseAtUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ResolutionSlaPausedAtUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ResolutionSlaPausedSeconds",
                table: "support_conversations",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.AddColumn<long>(
                name: "Version",
                table: "support_conversations",
                type: "bigint",
                nullable: false,
                defaultValue: 1L);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FirstResponseAtUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ResolutionSlaPausedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ResolutionSlaPausedSeconds",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "support_conversations");
        }
    }
}
