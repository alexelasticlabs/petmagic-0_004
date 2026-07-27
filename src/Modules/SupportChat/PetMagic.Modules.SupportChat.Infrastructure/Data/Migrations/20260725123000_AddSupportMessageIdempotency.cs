using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(SupportChatDbContext))]
    [Migration("20260725123000_AddSupportMessageIdempotency")]
    public partial class AddSupportMessageIdempotency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ClientIdempotencyKey",
                table: "support_messages",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "UX_support_messages_conversation_sender_idempotency",
                table: "support_messages",
                columns: new[] { "ConversationId", "SenderUserId", "ClientIdempotencyKey" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_support_messages_conversation_sender_idempotency",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "ClientIdempotencyKey",
                table: "support_messages");
        }
    }
}
