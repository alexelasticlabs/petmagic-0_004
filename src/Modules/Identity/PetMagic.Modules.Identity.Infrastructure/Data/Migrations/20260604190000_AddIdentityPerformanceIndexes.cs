using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Identity.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260604190000_AddIdentityPerformanceIndexes")]
    public partial class AddIdentityPerformanceIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_users_CreatedAtUtc",
                table: "users",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_users_AccountStatus_AccountStatusUpdatedAtUtc_CreatedAtUtc",
                table: "users",
                columns: new[] { "AccountStatus", "AccountStatusUpdatedAtUtc", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_audit_events_SubjectUserId_OccurredAtUtc",
                table: "audit_events",
                columns: new[] { "SubjectUserId", "OccurredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_Status_UpdatedAtUtc",
                table: "email_dispatch_jobs",
                columns: new[] { "Status", "UpdatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_users_CreatedAtUtc",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_users_AccountStatus_AccountStatusUpdatedAtUtc_CreatedAtUtc",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_audit_events_SubjectUserId_OccurredAtUtc",
                table: "audit_events");

            migrationBuilder.DropIndex(
                name: "IX_email_dispatch_jobs_Status_UpdatedAtUtc",
                table: "email_dispatch_jobs");
        }
    }
}
