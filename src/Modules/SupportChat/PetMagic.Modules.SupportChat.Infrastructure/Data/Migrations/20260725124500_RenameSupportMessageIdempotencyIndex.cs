using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(SupportChatDbContext))]
    [Migration("20260725124500_RenameSupportMessageIdempotencyIndex")]
    public partial class RenameSupportMessageIdempotencyIndex : Migration
    {
        private const string CurrentIndexName = "UX_support_messages_conversation_sender_idempotency";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            RenameLegacyIndexIfNeeded(
                migrationBuilder,
                "UX_support_messages_ConversationId_SenderUserId_ClientIdempoten");
            RenameLegacyIndexIfNeeded(
                migrationBuilder,
                "IX_support_messages_ConversationId_SenderUserId_ClientIdempoten");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: the preceding migration's Down operation expects
            // CurrentIndexName, so restoring PostgreSQL's truncated legacy name would make it fail.
        }

        private static void RenameLegacyIndexIfNeeded(MigrationBuilder migrationBuilder, string legacyIndexName)
        {
            migrationBuilder.Sql(
                $"""
                DO $$
                BEGIN
                    IF to_regclass('public."{legacyIndexName}"') IS NOT NULL
                       AND to_regclass('public."{CurrentIndexName}"') IS NULL THEN
                        ALTER INDEX public."{legacyIndexName}" RENAME TO "{CurrentIndexName}";
                    END IF;
                END $$;
                """);
        }
    }
}
