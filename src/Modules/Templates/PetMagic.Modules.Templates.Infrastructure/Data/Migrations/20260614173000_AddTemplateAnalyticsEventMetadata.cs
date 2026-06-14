using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614173000_AddTemplateAnalyticsEventMetadata")]
public partial class AddTemplateAnalyticsEventMetadata : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "MetadataJson",
            table: "templates_analytics_events",
            type: "character varying(2000)",
            maxLength: 2000,
            nullable: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "MetadataJson",
            table: "templates_analytics_events");
    }
}
