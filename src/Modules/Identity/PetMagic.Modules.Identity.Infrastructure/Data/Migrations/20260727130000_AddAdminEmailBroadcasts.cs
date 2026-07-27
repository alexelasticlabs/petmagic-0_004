using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Identity.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260727130000_AddAdminEmailBroadcasts")]
    public partial class AddAdminEmailBroadcasts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "admin_email_broadcasts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Audience = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    RecipientCount = table.Column<int>(type: "integer", nullable: false),
                    SentCount = table.Column<int>(type: "integer", nullable: false),
                    FailedCount = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_email_broadcasts", x => x.Id);
                    table.CheckConstraint(
                        "CK_admin_email_broadcasts_counts_nonnegative",
                        "\"RecipientCount\" >= 0 AND \"SentCount\" >= 0 AND \"FailedCount\" >= 0");
                    table.CheckConstraint(
                        "CK_admin_email_broadcasts_counts_within_total",
                        "\"SentCount\" + \"FailedCount\" <= \"RecipientCount\"");
                    table.CheckConstraint(
                        "CK_admin_email_broadcasts_status",
                        "\"Status\" >= 0 AND \"Status\" <= 5");
                });

            migrationBuilder.AddColumn<Guid>(
                name: "BroadcastId",
                table: "email_dispatch_jobs",
                type: "uuid",
                nullable: true);

            migrationBuilder.Sql(
                """
                INSERT INTO admin_email_broadcasts
                    ("Id", "ActorUserId", "Audience", "Subject", "RequestHash", "Status",
                     "RecipientCount", "SentCount", "FailedCount", "CreatedAtUtc", "UpdatedAtUtc", "CompletedAtUtc")
                SELECT
                    "Id",
                    "ActorUserId",
                    'legacy',
                    NULL,
                    COALESCE("NewValue", ''),
                    0,
                    CASE
                        WHEN "Details" ~ '^Bulk email queued for [0-9]+ recipients\.'
                            THEN substring("Details" from '^Bulk email queued for ([0-9]+) recipients\.')::integer
                        ELSE 0
                    END,
                    0,
                    0,
                    "OccurredAtUtc",
                    "OccurredAtUtc",
                    NULL
                FROM audit_events
                WHERE "Action" = 'admin.bulk_email.queued'
                ON CONFLICT ("Id") DO NOTHING;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_admin_email_broadcasts_CreatedAtUtc_Id",
                table: "admin_email_broadcasts",
                columns: new[] { "CreatedAtUtc", "Id" },
                descending: new[] { true, true });

            migrationBuilder.CreateIndex(
                name: "IX_admin_email_broadcasts_Status_CreatedAtUtc",
                table: "admin_email_broadcasts",
                columns: new[] { "Status", "CreatedAtUtc" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_BroadcastId_Status",
                table: "email_dispatch_jobs",
                columns: new[] { "BroadcastId", "Status" });

            migrationBuilder.AddForeignKey(
                name: "FK_email_dispatch_jobs_admin_email_broadcasts_BroadcastId",
                table: "email_dispatch_jobs",
                column: "BroadcastId",
                principalTable: "admin_email_broadcasts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_email_dispatch_jobs_admin_email_broadcasts_BroadcastId",
                table: "email_dispatch_jobs");

            migrationBuilder.DropIndex(
                name: "IX_email_dispatch_jobs_BroadcastId_Status",
                table: "email_dispatch_jobs");

            migrationBuilder.DropColumn(
                name: "BroadcastId",
                table: "email_dispatch_jobs");

            migrationBuilder.DropTable(
                name: "admin_email_broadcasts");
        }
    }
}
