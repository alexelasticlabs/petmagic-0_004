using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(TemplatesDbContext))]
    [Migration("20260727090000_AddAdminGenerationRefundRetryReceipts")]
    public partial class AddAdminGenerationRefundRetryReceipts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_admin_generation_refund_retry_receipts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    GenerationId = table.Column<Guid>(type: "uuid", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    PreviousRefundAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    PreviousRefundLastAttemptedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    PreviousRefundLastErrorCode = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CorrelationId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_admin_generation_refund_retry_receipts", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_tagrrr_GenerationId_CreatedAtUtc",
                table: "templates_admin_generation_refund_retry_receipts",
                columns: new[] { "GenerationId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "UX_tagrrr_ActorUserId_IdempotencyKey",
                table: "templates_admin_generation_refund_retry_receipts",
                columns: new[] { "ActorUserId", "IdempotencyKey" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_admin_generation_refund_retry_receipts");
        }
    }
}
