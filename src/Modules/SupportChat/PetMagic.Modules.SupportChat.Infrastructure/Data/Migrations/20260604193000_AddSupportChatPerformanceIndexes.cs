using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    [DbContext(typeof(SupportChatDbContext))]
    [Migration("20260604193000_AddSupportChatPerformanceIndexes")]
    public partial class AddSupportChatPerformanceIndexes : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_conversations_AssignedAdminId_Status",
                table: "support_conversations");

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_AssignedAdminId_Status_UpdatedAtUtc",
                table: "support_conversations",
                columns: new[] { "AssignedAdminId", "Status", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_Source_Status_UpdatedAtUtc",
                table: "support_conversations",
                columns: new[] { "Source", "Status", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_Status_Priority_UpdatedAtUtc",
                table: "support_conversations",
                columns: new[] { "Status", "Priority", "UpdatedAtUtc" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_support_conversations_AssignedAdminId_Status_UpdatedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropIndex(
                name: "IX_support_conversations_Source_Status_UpdatedAtUtc",
                table: "support_conversations");

            migrationBuilder.DropIndex(
                name: "IX_support_conversations_Status_Priority_UpdatedAtUtc",
                table: "support_conversations");

            migrationBuilder.CreateIndex(
                name: "IX_support_conversations_AssignedAdminId_Status",
                table: "support_conversations",
                columns: new[] { "AssignedAdminId", "Status" });
        }
    }
}
