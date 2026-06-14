using System;

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

public partial class AddPetAnalyticsEvents : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "templates_pet_analytics_events",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                PetId = table.Column<Guid>(type: "uuid", nullable: false),
                PetPhotoId = table.Column<Guid>(type: "uuid", nullable: true),
                TemplateId = table.Column<Guid>(type: "uuid", nullable: true),
                GenerationId = table.Column<Guid>(type: "uuid", nullable: true),
                EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                PetType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                PhotosCount = table.Column<int>(type: "integer", nullable: false),
                UserPlan = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                SourceScreen = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_pet_analytics_events", x => x.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_tpae_EventType_CreatedAtUtc",
            table: "templates_pet_analytics_events",
            columns: new[] { "EventType", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_tpae_PetId_CreatedAtUtc",
            table: "templates_pet_analytics_events",
            columns: new[] { "PetId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_tpae_UserId_CreatedAtUtc",
            table: "templates_pet_analytics_events",
            columns: new[] { "UserId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_pet_analytics_events_GenerationId",
            table: "templates_pet_analytics_events",
            column: "GenerationId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_pet_analytics_events_TemplateId",
            table: "templates_pet_analytics_events",
            column: "TemplateId");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_pet_analytics_events");
    }
}
