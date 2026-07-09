using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplatesPushOutbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_push_outbox",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DeduplicationKey = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    Kind = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PayloadJson = table.Column<string>(type: "character varying(16000)", maxLength: 16000, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LockId = table.Column<Guid>(type: "uuid", nullable: true),
                    LockExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SentAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_push_outbox", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_outbox_DeduplicationKey",
                table: "templates_push_outbox",
                column: "DeduplicationKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_outbox_Status_LockExpiresAtUtc",
                table: "templates_push_outbox",
                columns: new[] { "Status", "LockExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_outbox_Status_NextAttemptAtUtc_CreatedAtUtc",
                table: "templates_push_outbox",
                columns: new[] { "Status", "NextAttemptAtUtc", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_templates_push_outbox_UserId",
                table: "templates_push_outbox",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_push_outbox");
        }
    }
}
