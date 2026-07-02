using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

/// <inheritdoc />
public partial class AddGalleryCursorPaginationIndex : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateIndex(
            name: "IX_tgj_UserId_Hidden_Status_CreatedAt_Id",
            table: "templates_generation_jobs",
            columns: new[] { "UserId", "HiddenByUserAtUtc", "Status", "CreatedAtUtc", "Id" });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_tgj_UserId_Hidden_Status_CreatedAt_Id",
            table: "templates_generation_jobs");
    }
}
