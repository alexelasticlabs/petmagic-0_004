using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Identity.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(IdentityDbContext))]
    [Migration("20260606120000_AddAdminAuditContext")]
    public partial class AddAdminAuditContext : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ActorUserId",
                table: "audit_events",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ActorRole",
                table: "audit_events",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TargetType",
                table: "audit_events",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TargetId",
                table: "audit_events",
                type: "character varying(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OldValue",
                table: "audit_events",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NewValue",
                table: "audit_events",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "IpAddress",
                table: "audit_events",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UserAgent",
                table: "audit_events",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CorrelationId",
                table: "audit_events",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAtUtc",
                table: "audit_events",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE audit_events
                SET "CreatedAtUtc" = "OccurredAtUtc"
                WHERE "CreatedAtUtc" IS NULL;
                """);

            migrationBuilder.AlterColumn<DateTime>(
                name: "CreatedAtUtc",
                table: "audit_events",
                type: "timestamp with time zone",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_audit_events_CreatedAtUtc",
                table: "audit_events",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_audit_events_CorrelationId",
                table: "audit_events",
                column: "CorrelationId");

            migrationBuilder.CreateIndex(
                name: "IX_audit_events_ActorUserId_CreatedAtUtc",
                table: "audit_events",
                columns: new[] { "ActorUserId", "CreatedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_audit_events_CreatedAtUtc",
                table: "audit_events");

            migrationBuilder.DropIndex(
                name: "IX_audit_events_CorrelationId",
                table: "audit_events");

            migrationBuilder.DropIndex(
                name: "IX_audit_events_ActorUserId_CreatedAtUtc",
                table: "audit_events");

            migrationBuilder.DropColumn(name: "ActorUserId", table: "audit_events");
            migrationBuilder.DropColumn(name: "ActorRole", table: "audit_events");
            migrationBuilder.DropColumn(name: "TargetType", table: "audit_events");
            migrationBuilder.DropColumn(name: "TargetId", table: "audit_events");
            migrationBuilder.DropColumn(name: "OldValue", table: "audit_events");
            migrationBuilder.DropColumn(name: "NewValue", table: "audit_events");
            migrationBuilder.DropColumn(name: "IpAddress", table: "audit_events");
            migrationBuilder.DropColumn(name: "UserAgent", table: "audit_events");
            migrationBuilder.DropColumn(name: "CorrelationId", table: "audit_events");
            migrationBuilder.DropColumn(name: "CreatedAtUtc", table: "audit_events");
        }
    }
}
