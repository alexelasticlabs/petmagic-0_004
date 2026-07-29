using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260729153000_AddGenerationSchedulerHotPathIndexes")]
    public partial class AddGenerationSchedulerHotPathIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                    name: "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc",
                    table: "templates_generation_provider_attempts",
                    columns: new[] { "Stage", "ProviderCompletedAtUtc" },
                    descending: new[] { false, true },
                    filter: "\"State\" = 6 AND \"SubmittedAtUtc\" IS NOT NULL AND \"ProviderCompletedAtUtc\" IS NOT NULL")
                .Annotation("Npgsql:IndexInclude", new[] { "SubmittedAtUtc" });

            migrationBuilder.CreateIndex(
                    name: "IX_tgj_Completed_MediaType_ImportCompletedAtUtc",
                    table: "templates_generation_jobs",
                    columns: new[] { "QueueMediaType", "MediaImportCompletedAtUtc" },
                    descending: new[] { false, true },
                    filter: "\"Status\" = 3 AND \"ImportStartedAtUtc\" IS NOT NULL AND \"MediaImportCompletedAtUtc\" IS NOT NULL")
                .Annotation("Npgsql:IndexInclude", new[] { "ImportStartedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_tgj_UserId_QueueTier_LastAttemptAtUtc",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "QueueTier", "LastAttemptAtUtc" },
                descending: new[] { false, false, true },
                filter: "\"LastAttemptAtUtc\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc",
                table: "templates_provider_webhook_inbox",
                columns: new[] { "LockedAtUtc", "NextAttemptAtUtc" },
                filter: "\"Status\" = 2 AND \"LockedAtUtc\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc",
                table: "templates_generation_provider_attempts");

            migrationBuilder.DropIndex(
                name: "IX_tgj_Completed_MediaType_ImportCompletedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "IX_tgj_UserId_QueueTier_LastAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc",
                table: "templates_provider_webhook_inbox");
        }
    }
}
