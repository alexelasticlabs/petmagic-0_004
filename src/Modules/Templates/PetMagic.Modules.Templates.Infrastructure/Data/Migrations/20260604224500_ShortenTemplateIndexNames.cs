using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260604224500_ShortenTemplateIndexNames")]
    public partial class ShortenTemplateIndexNames : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfExists(
                migrationBuilder,
                "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAt~",
                "IX_tgj_Status_RefundedAtUtc_RefundLastAttemptedAtUtc");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_templates_push_device_tokens_UserId_DisabledAtUtc_LastSeenA~",
                "IX_tpdt_UserId_DisabledAtUtc_LastSeenAtUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfExists(
                migrationBuilder,
                "IX_tgj_Status_RefundedAtUtc_RefundLastAttemptedAtUtc",
                "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAt~");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_tpdt_UserId_DisabledAtUtc_LastSeenAtUtc",
                "IX_templates_push_device_tokens_UserId_DisabledAtUtc_LastSeenA~");
        }

        private static void RenameIndexIfExists(MigrationBuilder migrationBuilder, string oldName, string newName)
        {
            migrationBuilder.Sql(
                $"""
                DO $$
                BEGIN
                    IF to_regclass('public."{oldName}"') IS NOT NULL
                       AND to_regclass('public."{newName}"') IS NULL THEN
                        ALTER INDEX "{oldName}" RENAME TO "{newName}";
                    END IF;
                END $$;
                """);
        }
    }
}
