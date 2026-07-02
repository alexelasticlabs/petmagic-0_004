using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateRuntimeConfigFingerprints : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_runtime_config_fingerprints",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Component = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ProfileName = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Checksum = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ConfigJson = table.Column<string>(type: "text", nullable: false),
                    StartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSeenAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    MismatchDetected = table.Column<bool>(type: "boolean", nullable: false),
                    MismatchDetails = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_runtime_config_fingerprints", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_trcf_Component_ProfileName_StartedAtUtc",
                table: "templates_runtime_config_fingerprints",
                columns: new[] { "Component", "ProfileName", "StartedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_trcf_ProfileName_Checksum_StartedAtUtc",
                table: "templates_runtime_config_fingerprints",
                columns: new[] { "ProfileName", "Checksum", "StartedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_runtime_config_fingerprints");
        }
    }
}
