using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminNotificationInbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "admin_notification_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    SchemaVersion = table.Column<int>(type: "integer", nullable: false),
                    PayloadJson = table.Column<string>(type: "jsonb", nullable: false),
                    Category = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Priority = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    AudienceRoles = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    TargetUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Href = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true),
                    Source = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    DeduplicationKey = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AcknowledgedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    AcknowledgedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AcknowledgementReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Version = table.Column<int>(type: "integer", nullable: false, defaultValue: 1)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_notification_events", x => x.Id);
                    table.CheckConstraint("CK_admin_notification_events_acknowledgement", "(\"AcknowledgedAtUtc\" IS NULL AND \"AcknowledgedByUserId\" IS NULL AND \"AcknowledgementReason\" IS NULL) OR (\"AcknowledgedAtUtc\" IS NOT NULL AND \"AcknowledgedByUserId\" IS NOT NULL AND \"AcknowledgementReason\" IS NOT NULL)");
                    table.CheckConstraint("CK_admin_notification_events_schema_version", "\"SchemaVersion\" > 0");
                    table.CheckConstraint("CK_admin_notification_events_version", "\"Version\" > 0");
                });

            migrationBuilder.CreateTable(
                name: "admin_notification_receipts",
                columns: table => new
                {
                    EventId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReadAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ArchivedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_notification_receipts", x => new { x.EventId, x.UserId });
                    table.ForeignKey(
                        name: "FK_admin_notification_receipts_admin_notification_events_Event~",
                        column: x => x.EventId,
                        principalTable: "admin_notification_events",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_admin_notification_events_CreatedAtUtc_Id",
                table: "admin_notification_events",
                columns: new[] { "CreatedAtUtc", "Id" },
                descending: new bool[0]);

            migrationBuilder.CreateIndex(
                name: "IX_admin_notification_events_ExpiresAtUtc",
                table: "admin_notification_events",
                column: "ExpiresAtUtc",
                filter: "\"ExpiresAtUtc\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_admin_notif_priority_ack_created",
                table: "admin_notification_events",
                columns: new[] { "Priority", "AcknowledgedAtUtc", "CreatedAtUtc" },
                filter: "\"Priority\" = 'critical' AND \"AcknowledgedAtUtc\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_admin_notification_events_Source_DeduplicationKey",
                table: "admin_notification_events",
                columns: new[] { "Source", "DeduplicationKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_admin_notification_events_TargetUserId",
                table: "admin_notification_events",
                column: "TargetUserId");

            migrationBuilder.CreateIndex(
                name: "IX_admin_notif_receipt_user_state",
                table: "admin_notification_receipts",
                columns: new[] { "UserId", "ArchivedAtUtc", "ReadAtUtc", "EventId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "admin_notification_receipts");

            migrationBuilder.DropTable(
                name: "admin_notification_events");
        }
    }
}
