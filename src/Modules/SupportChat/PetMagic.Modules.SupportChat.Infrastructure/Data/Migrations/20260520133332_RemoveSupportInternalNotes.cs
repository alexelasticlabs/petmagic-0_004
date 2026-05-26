using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RemoveSupportInternalNotes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM support_reply_templates WHERE \"Kind\" = 1;");
            migrationBuilder.Sql("DELETE FROM support_messages WHERE \"IsInternalNote\" = TRUE;");

            migrationBuilder.DropIndex(
                name: "IX_support_reply_templates_Kind_SortOrder_IsEnabled",
                table: "support_reply_templates");

            migrationBuilder.DropIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_IsInternalNote_ReadAtUtc",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "Kind",
                table: "support_reply_templates");

            migrationBuilder.DropColumn(
                name: "IsInternalNote",
                table: "support_messages");

            migrationBuilder.CreateIndex(
                name: "IX_support_reply_templates_SortOrder_IsEnabled",
                table: "support_reply_templates",
                columns: ["SortOrder", "IsEnabled"]);

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc",
                table: "support_messages",
                columns: ["ConversationId", "IsFromAdmin", "ReadAtUtc"]);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_reply_templates_SortOrder_IsEnabled",
                table: "support_reply_templates");

            migrationBuilder.DropIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc",
                table: "support_messages");

            migrationBuilder.AddColumn<int>(
                name: "Kind",
                table: "support_reply_templates",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "IsInternalNote",
                table: "support_messages",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_support_reply_templates_Kind_SortOrder_IsEnabled",
                table: "support_reply_templates",
                columns: ["Kind", "SortOrder", "IsEnabled"]);

            migrationBuilder.CreateIndex(
                name: "IX_support_messages_ConversationId_IsFromAdmin_IsInternalNote_ReadAtUtc",
                table: "support_messages",
                columns: ["ConversationId", "IsFromAdmin", "IsInternalNote", "ReadAtUtc"]);
        }
    }
}
