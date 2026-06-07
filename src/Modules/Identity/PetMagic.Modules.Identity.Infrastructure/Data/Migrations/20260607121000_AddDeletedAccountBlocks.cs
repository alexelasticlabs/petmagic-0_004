using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Identity.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260607121000_AddDeletedAccountBlocks")]
    public partial class AddDeletedAccountBlocks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "deleted_account_blocks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: true),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    ProviderUserId = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    DeletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_deleted_account_blocks", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_deleted_account_blocks_Email",
                table: "deleted_account_blocks",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_deleted_account_blocks_Provider_ProviderUserId",
                table: "deleted_account_blocks",
                columns: new[] { "Provider", "ProviderUserId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "deleted_account_blocks");
        }
    }
}
