using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class NormalizeLegacyConversationEnums : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                UPDATE support_conversations
                SET "Status" = 3
                WHERE "Status" = 2;
                """);

            migrationBuilder.Sql("""
                UPDATE support_conversations
                SET "Status" = CASE
                    WHEN "AssignedAdminId" IS NULL THEN 0
                    ELSE 1
                END
                WHERE "Status" = 4;
                """);

            migrationBuilder.Sql("""
                UPDATE support_conversations
                SET "Source" = 2
                WHERE "Source" = 0;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: legacy enum values are normalized
            // in-place and the previous semantic mapping is not preserved.
        }
    }
}
