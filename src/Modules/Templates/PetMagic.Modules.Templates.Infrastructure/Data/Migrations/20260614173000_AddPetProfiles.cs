using System;

using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614173000_AddPetProfiles")]
public partial class AddPetProfiles : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<Guid>(
            name: "PetId",
            table: "templates_generation_jobs",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "PetPhotoId",
            table: "templates_generation_jobs",
            type: "uuid",
            nullable: true);

        migrationBuilder.CreateTable(
            name: "templates_pets",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                Name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                Type = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                Breed = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                AvatarMediaAssetId = table.Column<Guid>(type: "uuid", nullable: true),
                Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false, defaultValue: "active"),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                IsDeleted = table.Column<bool>(type: "boolean", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_pets", x => x.Id);
            });

        migrationBuilder.CreateTable(
            name: "templates_pet_photos",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                PetId = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                MediaAssetId = table.Column<Guid>(type: "uuid", nullable: false),
                ThumbnailUrl = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                ThumbnailStoragePath = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                IsFavorite = table.Column<bool>(type: "boolean", nullable: false),
                IsAvatar = table.Column<bool>(type: "boolean", nullable: false),
                SortOrder = table.Column<int>(type: "integer", nullable: false),
                Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false, defaultValue: "active"),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                IsDeleted = table.Column<bool>(type: "boolean", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_pet_photos", x => x.Id);
                table.ForeignKey(
                    name: "FK_templates_pet_photos_templates_media_records_MediaAssetId",
                    column: x => x.MediaAssetId,
                    principalTable: "templates_media_records",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_templates_pet_photos_templates_pets_PetId",
                    column: x => x.PetId,
                    principalTable: "templates_pets",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_tgj_UserId_PetId_CreatedAtUtc",
            table: "templates_generation_jobs",
            columns: new[] { "UserId", "PetId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_jobs_PetPhotoId",
            table: "templates_generation_jobs",
            column: "PetPhotoId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_pets_AvatarMediaAssetId",
            table: "templates_pets",
            column: "AvatarMediaAssetId");

        migrationBuilder.CreateIndex(
            name: "IX_templates_pets_UserId_IsDeleted_CreatedAtUtc",
            table: "templates_pets",
            columns: new[] { "UserId", "IsDeleted", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_pet_photos_MediaAssetId",
            table: "templates_pet_photos",
            column: "MediaAssetId",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_templates_pet_photos_PetId_IsDeleted_SortOrder",
            table: "templates_pet_photos",
            columns: new[] { "PetId", "IsDeleted", "SortOrder" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_pet_photos_UserId_IsDeleted_CreatedAtUtc",
            table: "templates_pet_photos",
            columns: new[] { "UserId", "IsDeleted", "CreatedAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "templates_pet_photos");

        migrationBuilder.DropTable(name: "templates_pets");

        migrationBuilder.DropIndex(
            name: "IX_tgj_UserId_PetId_CreatedAtUtc",
            table: "templates_generation_jobs");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_jobs_PetPhotoId",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "PetId",
            table: "templates_generation_jobs");

        migrationBuilder.DropColumn(
            name: "PetPhotoId",
            table: "templates_generation_jobs");
    }
}
