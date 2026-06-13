using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddIdentityModelCompatibility : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                          AND table_name = 'users'
                          AND column_name = 'LastLoginAtUtc'
                    ) THEN
                        ALTER TABLE "users" ADD "LastLoginAtUtc" timestamp with time zone;
                    END IF;
                END $$;
                """);

            migrationBuilder.Sql(
                """
                CREATE TABLE IF NOT EXISTS "deleted_account_blocks" (
                    "Id" uuid NOT NULL,
                    "Email" character varying(320),
                    "Provider" character varying(32),
                    "ProviderUserId" character varying(256),
                    "DeletedAtUtc" timestamp with time zone NOT NULL,
                    CONSTRAINT "PK_deleted_account_blocks" PRIMARY KEY ("Id")
                );

                CREATE UNIQUE INDEX IF NOT EXISTS "IX_deleted_account_blocks_Email"
                    ON "deleted_account_blocks" ("Email");

                CREATE UNIQUE INDEX IF NOT EXISTS "IX_deleted_account_blocks_Provider_ProviderUserId"
                    ON "deleted_account_blocks" ("Provider", "ProviderUserId");
                """);

            migrationBuilder.Sql(
                """
                CREATE TABLE IF NOT EXISTS "external_auth_providers" (
                    "Id" uuid NOT NULL,
                    "UserId" uuid NOT NULL,
                    "Provider" character varying(32) NOT NULL,
                    "ProviderUserId" character varying(256) NOT NULL,
                    "Email" character varying(320),
                    "CreatedAt" timestamp with time zone NOT NULL,
                    "LastUsedAt" timestamp with time zone NOT NULL,
                    CONSTRAINT "PK_external_auth_providers" PRIMARY KEY ("Id"),
                    CONSTRAINT "FK_external_auth_providers_users_UserId"
                        FOREIGN KEY ("UserId") REFERENCES "users" ("Id") ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS "IX_external_auth_providers_Email"
                    ON "external_auth_providers" ("Email");

                CREATE UNIQUE INDEX IF NOT EXISTS "IX_external_auth_providers_Provider_ProviderUserId"
                    ON "external_auth_providers" ("Provider", "ProviderUserId");

                CREATE INDEX IF NOT EXISTS "IX_external_auth_providers_UserId"
                    ON "external_auth_providers" ("UserId");
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""deleted_account_blocks"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""external_auth_providers"" CASCADE;");
            migrationBuilder.Sql(@"ALTER TABLE ""users"" DROP COLUMN IF EXISTS ""LastLoginAtUtc"";");
        }
    }
}
