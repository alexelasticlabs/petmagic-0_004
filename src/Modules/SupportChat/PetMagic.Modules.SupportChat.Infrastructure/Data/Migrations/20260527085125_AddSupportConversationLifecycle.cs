using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportConversationLifecycle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ClosedAtUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FeedbackComment",
                table: "support_conversations",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FeedbackRating",
                table: "support_conversations",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "FeedbackSubmittedAtUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ReopenUntilUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_ReopenUntilUtc",
                table: "support_conversations",
                column: "ReopenUntilUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_conversations_ReopenUntilUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ClosedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "FeedbackComment",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "FeedbackRating",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "FeedbackSubmittedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ReopenUntilUtc",
                table: "support_conversations");
        }
    }
}
