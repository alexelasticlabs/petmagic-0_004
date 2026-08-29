using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260829020000_AddRefreshSessionAuthenticationProvider")]
    public partial class AddRefreshSessionAuthenticationProvider : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AuthenticationProvider",
                table: "refresh_token_sessions",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_refresh_token_sessions_UserId_AuthenticationProvider_CreatedAtUtc",
                table: "refresh_token_sessions",
                columns: new[] { "UserId", "AuthenticationProvider", "CreatedAtUtc" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_refresh_token_sessions_UserId_AuthenticationProvider_CreatedAtUtc",
                table: "refresh_token_sessions");

            migrationBuilder.DropColumn(
                name: "AuthenticationProvider",
                table: "refresh_token_sessions");
        }
    }
}
