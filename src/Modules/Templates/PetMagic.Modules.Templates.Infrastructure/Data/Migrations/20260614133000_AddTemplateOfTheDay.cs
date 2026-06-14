using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260614133000_AddTemplateOfTheDay")]
    public partial class AddTemplateOfTheDay : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_of_the_day",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    IsManual = table.Column<bool>(type: "boolean", nullable: false),
                    Priority = table.Column<int>(type: "integer", nullable: false),
                    TitleOverride = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    SubtitleOverride = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: true),
                    BadgeTextOverride = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedByAdminId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_of_the_day", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_of_the_day_templates_items_TemplateId",
                        column: x => x.TemplateId,
                        principalTable: "templates_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_otd_active_manual_dates",
                table: "templates_of_the_day",
                columns: new[] { "IsActive", "IsManual", "StartDate", "EndDate" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_otd_template_start_date",
                table: "templates_of_the_day",
                columns: new[] { "TemplateId", "StartDate" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "templates_of_the_day");
        }
    }
}
