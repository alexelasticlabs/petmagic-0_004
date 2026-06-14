using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614160000_AddGenerationWatermarkUnlocks")]
public partial class AddGenerationWatermarkUnlocks : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "IsWatermarkRemoved",
            table: "templates_generation_jobs",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<bool>(
            name: "IsWatermarkRequired",
            table: "templates_generation_jobs",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<string>(
            name: "WatermarkFailureCode",
            table: "templates_generation_jobs",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "WatermarkedResultUrl",
            table: "templates_generation_jobs",
            type: "character varying(2048)",
            maxLength: 2048,
            nullable: true);

        migrationBuilder.CreateTable(
            name: "templates_watermark_settings",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                Enabled = table.Column<bool>(type: "boolean", nullable: false),
                Text = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                LogoUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                Opacity = table.Column<double>(type: "double precision", nullable: false),
                Position = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                Size = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                CostCredits = table.Column<int>(type: "integer", nullable: false),
                ApplyToImages = table.Column<bool>(type: "boolean", nullable: false),
                ApplyToVideos = table.Column<bool>(type: "boolean", nullable: false),
                PreviewImageUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                PreviewVideoFrameUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_watermark_settings", x => x.Id);
            });

        migrationBuilder.CreateTable(
            name: "templates_generation_watermark_unlocks",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                GenerationJobId = table.Column<Guid>(type: "uuid", nullable: false),
                UnlockedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                UnlockMethod = table.Column<int>(type: "integer", nullable: false),
                CreditsSpent = table.Column<int>(type: "integer", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_generation_watermark_unlocks", x => x.Id);
                table.ForeignKey(
                    name: "FK_templates_generation_watermark_unlocks_templates_generation_~",
                    column: x => x.GenerationJobId,
                    principalTable: "templates_generation_jobs",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_tgj_UserId_WatermarkState",
            table: "templates_generation_jobs",
            columns: new[] { "UserId", "IsWatermarkRequired", "IsWatermarkRemoved" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_watermark_settings_UpdatedAtUtc",
            table: "templates_watermark_settings",
            column: "UpdatedAtUtc");

        migrationBuilder.CreateIndex(
            name: "IX_tgwu_GenerationJobId_CreatedAtUtc",
            table: "templates_generation_watermark_unlocks",
            columns: new[] { "GenerationJobId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "UX_tgwu_UserId_GenerationJobId",
            table: "templates_generation_watermark_unlocks",
            columns: new[] { "UserId", "GenerationJobId" },
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_generation_watermark_unlocks");

        migrationBuilder.DropTable(name: "templates_watermark_settings");

        migrationBuilder.DropIndex(
            name: "IX_tgj_UserId_WatermarkState",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "IsWatermarkRemoved",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "IsWatermarkRequired",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "WatermarkFailureCode",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "WatermarkedResultUrl",
            table: "templates_generation_jobs");
    }
}
