using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260729184500_EnforceGenerationResultMediaIdentity")]
    public partial class EnforceGenerationResultMediaIdentity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE templates_media_records
                SET "GenerationId" = "GenerationJobId"
                WHERE "SourceType" = 'generation_result'
                  AND "GenerationId" IS NULL
                  AND "GenerationJobId" IS NOT NULL;

                DO $migration$
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM templates_media_records
                        WHERE "SourceType" = 'generation_result'
                          AND "GenerationId" IS NOT NULL
                        GROUP BY "GenerationId", "MediaType"
                        HAVING COUNT(*) > 1
                    ) THEN
                        RAISE EXCEPTION
                            'Generation-result media identity migration found duplicate rows.'
                            USING HINT = 'Reconcile duplicate templates_media_records by GenerationId and MediaType before rerunning the migration; preserve original, watermarked and preview paths on the retained row.';
                    END IF;
                END
                $migration$;
                """);

            // A generation output owns one record per media type. Original, watermarked and
            // preview artifacts remain checkpoints on that record and are not separate identities.
            // Drop first so a retry can recover an invalid index left by an interrupted concurrent
            // build. Both operations must remain outside the EF migration transaction.
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_tmr_GenerationResult_GenerationId_MediaType";
                """,
                suppressTransaction: true);
            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX CONCURRENTLY "UX_tmr_GenerationResult_GenerationId_MediaType"
                ON templates_media_records ("GenerationId", "MediaType")
                WHERE "GenerationId" IS NOT NULL AND "SourceType" = 'generation_result';
                """,
                suppressTransaction: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX CONCURRENTLY IF EXISTS "UX_tmr_GenerationResult_GenerationId_MediaType";
                """,
                suppressTransaction: true);
        }
    }
}
