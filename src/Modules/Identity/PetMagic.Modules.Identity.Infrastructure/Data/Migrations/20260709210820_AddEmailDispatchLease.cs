using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailDispatchLease : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LockExpiresAtUtc",
                table: "email_dispatch_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LockId",
                table: "email_dispatch_jobs",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_Status_LockExpiresAtUtc_QueuedAtUtc",
                table: "email_dispatch_jobs",
                columns: new[] { "Status", "LockExpiresAtUtc", "QueuedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_email_dispatch_jobs_Status_LockExpiresAtUtc_QueuedAtUtc",
                table: "email_dispatch_jobs");

            migrationBuilder.DropColumn(
                name: "LockExpiresAtUtc",
                table: "email_dispatch_jobs");

            migrationBuilder.DropColumn(
                name: "LockId",
                table: "email_dispatch_jobs");
        }
    }
}
