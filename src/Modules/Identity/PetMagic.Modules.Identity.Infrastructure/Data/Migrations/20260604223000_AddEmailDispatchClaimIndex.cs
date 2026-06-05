using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Identity.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260604223000_AddEmailDispatchClaimIndex")]
    public partial class AddEmailDispatchClaimIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_Status_NextAttemptAtUtc_QueuedAtUtc",
                table: "email_dispatch_jobs",
                columns: new[] { "Status", "NextAttemptAtUtc", "QueuedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_email_dispatch_jobs_Status_NextAttemptAtUtc_QueuedAtUtc",
                table: "email_dispatch_jobs");
        }
    }
}
