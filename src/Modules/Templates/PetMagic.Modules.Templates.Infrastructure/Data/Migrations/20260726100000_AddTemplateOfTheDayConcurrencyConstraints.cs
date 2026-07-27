using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260726100000_AddTemplateOfTheDayConcurrencyConstraints")]
    public partial class AddTemplateOfTheDayConcurrencyConstraints : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DO $$
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM templates_of_the_day AS first_assignment
                        INNER JOIN templates_of_the_day AS second_assignment
                            ON first_assignment."Id" < second_assignment."Id"
                            AND first_assignment."IsActive"
                            AND second_assignment."IsActive"
                            AND first_assignment."IsManual" = second_assignment."IsManual"
                            AND daterange(
                                first_assignment."StartDate",
                                COALESCE(first_assignment."EndDate", 'infinity'::date),
                                '[]')
                                && daterange(
                                    second_assignment."StartDate",
                                    COALESCE(second_assignment."EndDate", 'infinity'::date),
                                    '[]')
                    ) THEN
                        RAISE EXCEPTION
                            'Cannot add Template of the Day concurrency constraints because active overlapping assignments already exist. Resolve them manually before retrying the migration.';
                    END IF;
                END $$;
                """);

            migrationBuilder.Sql("""
                ALTER TABLE templates_of_the_day
                ADD CONSTRAINT "EX_templates_otd_active_manual_date_range"
                EXCLUDE USING gist (
                    daterange("StartDate", COALESCE("EndDate", 'infinity'::date), '[]') WITH &&
                )
                WHERE ("IsActive" AND "IsManual");
                """);

            migrationBuilder.Sql("""
                ALTER TABLE templates_of_the_day
                ADD CONSTRAINT "EX_templates_otd_active_auto_date_range"
                EXCLUDE USING gist (
                    daterange("StartDate", COALESCE("EndDate", 'infinity'::date), '[]') WITH &&
                )
                WHERE ("IsActive" AND NOT "IsManual");
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                ALTER TABLE templates_of_the_day
                DROP CONSTRAINT IF EXISTS "EX_templates_otd_active_auto_date_range";
                """);

            migrationBuilder.Sql("""
                ALTER TABLE templates_of_the_day
                DROP CONSTRAINT IF EXISTS "EX_templates_otd_active_manual_date_range";
                """);
        }
    }
}
