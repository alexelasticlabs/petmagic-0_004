using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddAccountStatusAndCodeAttempts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "AccountStatus",
                table: "users",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<DateTime>(
                name: "AccountStatusUpdatedAtUtc",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FailedAttemptCount",
                table: "user_email_codes",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "LockedAtUtc",
                table: "user_email_codes",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_AccountStatus",
                table: "users",
                column: "AccountStatus");

            migrationBuilder.CreateIndex(
                name: "IX_user_email_codes_UserId_Purpose_LockedAtUtc",
                table: "user_email_codes",
                columns: new[] { "UserId", "Purpose", "LockedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_users_AccountStatus",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_user_email_codes_UserId_Purpose_LockedAtUtc",
                table: "user_email_codes");

            migrationBuilder.DropColumn(
                name: "AccountStatus",
                table: "users");

            migrationBuilder.DropColumn(
                name: "AccountStatusUpdatedAtUtc",
                table: "users");

            migrationBuilder.DropColumn(
                name: "FailedAttemptCount",
                table: "user_email_codes");

            migrationBuilder.DropColumn(
                name: "LockedAtUtc",
                table: "user_email_codes");
        }
    }
}
