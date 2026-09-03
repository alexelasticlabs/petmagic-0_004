using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260829211500_RenameRefreshSessionAuthenticationProviderIndex")]
    public partial class RenameRefreshSessionAuthenticationProviderIndex : Migration
    {
        private const string LegacyIndexName =
            "IX_refresh_token_sessions_UserId_AuthenticationProvider_Created";

        private const string CurrentIndexName =
            "IX_refresh_token_sessions_UserId_AuthProvider_CreatedAtUtc";

        protected override void Up(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfNeeded(migrationBuilder, LegacyIndexName, CurrentIndexName);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfNeeded(migrationBuilder, CurrentIndexName, LegacyIndexName);
        }

        private static void RenameIndexIfNeeded(
            MigrationBuilder migrationBuilder,
            string sourceIndexName,
            string targetIndexName)
        {
            migrationBuilder.Sql(
                $"""
                DO $$
                BEGIN
                    IF to_regclass('public."{targetIndexName}"') IS NULL THEN
                        IF to_regclass('public."{sourceIndexName}"') IS NULL THEN
                            RAISE EXCEPTION
                                'Cannot rename refresh-session authentication-provider index: source index % does not exist.',
                                '{sourceIndexName}';
                        END IF;

                        ALTER INDEX public."{sourceIndexName}" RENAME TO "{targetIndexName}";
                    END IF;
                END $$;
                """);
        }
    }
}
