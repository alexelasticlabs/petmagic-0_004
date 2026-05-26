using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260517124500_AddTemplateAnalyticsFeedbackSearchIndexes")]
    public partial class AddTemplateAnalyticsFeedbackSearchIndexes : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_templates_analytics_events_TemplateId_CreatedAtUtc",
                table: "templates_analytics_events",
                columns: ["TemplateId", "CreatedAtUtc"]);

            migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS pg_trgm;");
            migrationBuilder.Sql(
                "CREATE INDEX IF NOT EXISTS \"IX_templates_analytics_events_FeedbackMessage_trgm\" " +
                "ON templates_analytics_events USING gin (lower(\"FeedbackMessage\") gin_trgm_ops) " + Environment.NewLine +
                "WHERE \"FeedbackMessage\" IS NOT NULL AND (\"EventType\" = 'complaint' OR \"EventType\" = 'feedback');");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_templates_analytics_events_FeedbackMessage_trgm\";");

            migrationBuilder.DropIndex(
                name: "IX_templates_analytics_events_TemplateId_CreatedAtUtc",
                table: "templates_analytics_events");
        }
    }
}
