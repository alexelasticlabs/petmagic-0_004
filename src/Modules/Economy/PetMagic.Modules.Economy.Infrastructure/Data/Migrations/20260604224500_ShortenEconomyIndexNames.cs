using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Economy.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(EconomyDbContext))]
    [Migration("20260604224500_ShortenEconomyIndexNames")]
    public partial class ShortenEconomyIndexNames : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfExists(
                migrationBuilder,
                "IX_economy_push_device_tokens_UserId_DisabledAtUtc_LastSeenAtU~",
                "IX_epdt_UserId_DisabledAtUtc_LastSeenAtUtc");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~",
                "UX_espm_Provider_ExternalPaymentMethodId");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_economy_subscription_event_logs_UserId_Provider_CreatedAtUtc",
                "IX_esel_UserId_Provider_CreatedAtUtc");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_economy_subscription_event_logs_Provider_ExternalSubscripti~",
                "IX_esel_Provider_ExternalSubscriptionId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            RenameIndexIfExists(
                migrationBuilder,
                "IX_epdt_UserId_DisabledAtUtc_LastSeenAtUtc",
                "IX_economy_push_device_tokens_UserId_DisabledAtUtc_LastSeenAtU~");
            RenameIndexIfExists(
                migrationBuilder,
                "UX_espm_Provider_ExternalPaymentMethodId",
                "IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_esel_UserId_Provider_CreatedAtUtc",
                "IX_economy_subscription_event_logs_UserId_Provider_CreatedAtUtc");
            RenameIndexIfExists(
                migrationBuilder,
                "IX_esel_Provider_ExternalSubscriptionId",
                "IX_economy_subscription_event_logs_Provider_ExternalSubscripti~");
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
