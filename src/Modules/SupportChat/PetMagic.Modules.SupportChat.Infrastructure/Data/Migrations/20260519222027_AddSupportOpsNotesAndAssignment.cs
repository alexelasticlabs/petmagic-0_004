using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportOpsNotesAndAssignment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc",
                table: "support_messages");

            migrationBuilder.AddColumn<bool>(
                name: "IsInternalNote",
                table: "support_messages",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_IsInternalNote_~",
                table: "support_messages",
                columns: new[] { "ConversationId", "IsFromAdmin", "IsInternalNote", "ReadAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_IsInternalNote_~",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "IsInternalNote",
                table: "support_messages");

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc",
                table: "support_messages",
                columns: new[] { "ConversationId", "IsFromAdmin", "ReadAtUtc" });
        }
    }
}
