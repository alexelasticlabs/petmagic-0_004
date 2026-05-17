using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateAnalyticsEvents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_analytics_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventType = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Source = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DeviceClass = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    CountryCode = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_analytics_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_analytics_events_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_CountryCode",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "CountryCode" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_DeviceClass",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "DeviceClass" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_EventType_CreatedAtUtc",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "EventType", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_Source",
                table: "templates_analytics_events",
                columns: new[] { "TemplateId", "Source" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_analytics_events");
        }
    }
}
