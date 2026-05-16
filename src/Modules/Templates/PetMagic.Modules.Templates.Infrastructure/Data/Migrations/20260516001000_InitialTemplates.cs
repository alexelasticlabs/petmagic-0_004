using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260516001000_InitialTemplates")]
public sealed class InitialTemplates : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "templates_items",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                TemplateType = table.Column<int>(type: "integer", nullable: false),
                Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                ShortDescription = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: false),
                Category = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                Tags = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                IsPremium = table.Column<bool>(type: "boolean", nullable: false),
                TokenCost = table.Column<int>(type: "integer", nullable: false),
                Status = table.Column<int>(type: "integer", nullable: false),
                MusicDescription = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: true),
                ReferenceVideoDurationSeconds = table.Column<double>(type: "double precision", nullable: true),
                CharacterOrientation = table.Column<int>(type: "integer", nullable: true),
                PreprocessingModel = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                PreprocessingPrompt = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                KlingModel = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                KlingPrompt = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                KeepOriginalSound = table.Column<bool>(type: "boolean", nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_items", x => x.Id);
            });

        migrationBuilder.CreateTable(
            name: "templates_assets",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                TemplateId = table.Column<Guid>(type: "uuid", nullable: false),
                AssetKind = table.Column<int>(type: "integer", nullable: false),
                Url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                FileName = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                ContentType = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                FileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                DurationSeconds = table.Column<double>(type: "double precision", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_assets", x => x.Id);
                table.ForeignKey(
                    name: "FK_templates_assets_templates_items_TemplateId",
                    column: x => x.TemplateId,
                    principalTable: "templates_items",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_templates_assets_TemplateId_AssetKind",
            table: "templates_assets",
            columns: new[] { "TemplateId", "AssetKind" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_templates_items_Status_Category",
            table: "templates_items",
            columns: new[] { "Status", "Category" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_items_TemplateType_Status_UpdatedAtUtc",
            table: "templates_items",
            columns: new[] { "TemplateType", "Status", "UpdatedAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_assets");
        migrationBuilder.DropTable(name: "templates_items");
    }
}
