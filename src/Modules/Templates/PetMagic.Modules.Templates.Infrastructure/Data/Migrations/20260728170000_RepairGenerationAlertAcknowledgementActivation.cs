using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260728170000_RepairGenerationAlertAcknowledgementActivation")]
    public partial class RepairGenerationAlertAcknowledgementActivation : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE templates_generation_operational_alert_acknowledgements
                ADD COLUMN IF NOT EXISTS "AlertActivatedAtUtc" timestamp with time zone;

                UPDATE templates_generation_operational_alert_acknowledgements AS acknowledgement
                SET "AlertActivatedAtUtc" = alert."ActivatedAtUtc"
                FROM templates_generation_operational_alerts AS alert
                WHERE alert."Id" = acknowledgement."AlertId"
                  AND acknowledgement."AlertActivatedAtUtc" IS NULL;

                UPDATE templates_generation_operational_alert_acknowledgements
                SET "AlertActivatedAtUtc" = "AcknowledgedAtUtc"
                WHERE "AlertActivatedAtUtc" IS NULL;

                ALTER TABLE templates_generation_operational_alert_acknowledgements
                ALTER COLUMN "AlertActivatedAtUtc" SET NOT NULL;
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally irreversible: the original runtime-control migration already defines
            // this required column, and removing it would recreate the schema drift being repaired.
        }
    }
}
