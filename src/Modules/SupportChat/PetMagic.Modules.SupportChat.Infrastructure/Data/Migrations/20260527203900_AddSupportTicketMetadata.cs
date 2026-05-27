using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportTicketMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DeliveredAtUtc",
                table: "support_messages",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsInternalNote",
                table: "support_messages",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<Guid>(
                name: "ClosedByUserId",
                table: "support_conversations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LastMessagePreview",
                table: "support_conversations",
                type: "character varying(280)",
                maxLength: 280,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "LastMessageSenderType",
                table: "support_conversations",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ReopenedAtUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ReopenedByUserId",
                table: "support_conversations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "WaitingSinceUtc",
                table: "support_conversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_WaitingSinceUtc",
                table: "support_conversations",
                column: "WaitingSinceUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_conversations_WaitingSinceUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "DeliveredAtUtc",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "IsInternalNote",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "ClosedByUserId",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "LastMessagePreview",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "LastMessageSenderType",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ReopenedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "ReopenedByUserId",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "WaitingSinceUtc",
                table: "support_conversations");
        }
    }
}
