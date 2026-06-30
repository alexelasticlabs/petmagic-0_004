using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RepairSupportChatSchemaDrift : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                CREATE TABLE IF NOT EXISTS support_message_attachments
                (
                    "Id" uuid,
                    "MessageId" uuid,
                    "FileUrl" character varying(2048),
                    "MimeType" character varying(128),
                    "FileName" character varying(256),
                    "SizeBytes" bigint,
                    "StorageKey" character varying(1024),
                    "ExpiresAtUtc" timestamp with time zone,
                    "DeletedAtUtc" timestamp with time zone,
                    "IsDeleted" boolean,
                    "DurationSeconds" double precision,
                    "Width" integer,
                    "Height" integer,
                    "SortOrder" integer,
                    "CreatedAtUtc" timestamp with time zone
                );

                ALTER TABLE support_message_attachments
                    ADD COLUMN IF NOT EXISTS "Id" uuid NULL,
                    ADD COLUMN IF NOT EXISTS "MessageId" uuid NULL,
                    ADD COLUMN IF NOT EXISTS "FileUrl" character varying(2048) NULL,
                    ADD COLUMN IF NOT EXISTS "MimeType" character varying(128) NULL,
                    ADD COLUMN IF NOT EXISTS "FileName" character varying(256) NULL,
                    ADD COLUMN IF NOT EXISTS "SizeBytes" bigint NULL,
                    ADD COLUMN IF NOT EXISTS "StorageKey" character varying(1024) NULL,
                    ADD COLUMN IF NOT EXISTS "ExpiresAtUtc" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "DeletedAtUtc" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "IsDeleted" boolean NULL,
                    ADD COLUMN IF NOT EXISTS "DurationSeconds" double precision NULL,
                    ADD COLUMN IF NOT EXISTS "Width" integer NULL,
                    ADD COLUMN IF NOT EXISTS "Height" integer NULL,
                    ADD COLUMN IF NOT EXISTS "SortOrder" integer NULL,
                    ADD COLUMN IF NOT EXISTS "CreatedAtUtc" timestamp with time zone NULL;

                ALTER TABLE support_message_attachments
                    ALTER COLUMN "IsDeleted" SET DEFAULT false;

                ALTER TABLE support_messages
                    ADD COLUMN IF NOT EXISTS "ReplyToMessageId" uuid NULL,
                    ADD COLUMN IF NOT EXISTS "ReplyToPreview" character varying(280) NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: schema repair backfills drifted
            // columns/table shape without tracking a lossless prior schema.
        }
    }
}
