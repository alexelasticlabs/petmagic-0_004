using System;

using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614174500_AddPetAnalyticsEvents")]
public partial class AddPetAnalyticsEvents : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            CREATE TABLE IF NOT EXISTS templates_pet_analytics_events (
                "Id" uuid NOT NULL,
                "UserId" uuid NOT NULL,
                "PetId" uuid NOT NULL,
                "PetPhotoId" uuid,
                "TemplateId" uuid,
                "GenerationId" uuid,
                "EventType" character varying(64) NOT NULL,
                "PetType" character varying(16) NOT NULL,
                "PhotosCount" integer NOT NULL,
                "UserPlan" character varying(32) NOT NULL,
                "SourceScreen" character varying(64) NOT NULL,
                "CreatedAtUtc" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_templates_pet_analytics_events" PRIMARY KEY ("Id")
            );

            CREATE INDEX IF NOT EXISTS "IX_tpae_EventType_CreatedAtUtc"
                ON templates_pet_analytics_events ("EventType", "CreatedAtUtc");

            CREATE INDEX IF NOT EXISTS "IX_tpae_PetId_CreatedAtUtc"
                ON templates_pet_analytics_events ("PetId", "CreatedAtUtc");

            CREATE INDEX IF NOT EXISTS "IX_tpae_UserId_CreatedAtUtc"
                ON templates_pet_analytics_events ("UserId", "CreatedAtUtc");

            CREATE INDEX IF NOT EXISTS "IX_templates_pet_analytics_events_GenerationId"
                ON templates_pet_analytics_events ("GenerationId");

            CREATE INDEX IF NOT EXISTS "IX_templates_pet_analytics_events_TemplateId"
                ON templates_pet_analytics_events ("TemplateId");
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_pet_analytics_events");
    }
}
