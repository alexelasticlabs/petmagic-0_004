using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportMessageReply : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ReplyToMessageId",
                table: "support_messages",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReplyToPreview",
                table: "support_messages",
                type: "character varying(280)",
                maxLength: 280,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ConversationId_ReplyToMessageId",
                table: "support_messages",
                columns: new[] { "ConversationId", "ReplyToMessageId" });

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ReplyToMessageId",
                table: "support_messages",
                column: "ReplyToMessageId");

            migrationBuilder.AddForeignKey(
                name: "FK_support_messages_support_messages_ReplyToMessageId",
                table: "support_messages",
                column: "ReplyToMessageId",
                principalTable: "support_messages",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_support_messages_support_messages_ReplyToMessageId",
                table: "support_messages");

            migrationBuilder.DropIndex(
                name: "IX_support_messages_ConversationId_ReplyToMessageId",
                table: "support_messages");

            migrationBuilder.DropIndex(
                name: "IX_support_messages_ReplyToMessageId",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "ReplyToMessageId",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "ReplyToPreview",
                table: "support_messages");
        }
    }
}
