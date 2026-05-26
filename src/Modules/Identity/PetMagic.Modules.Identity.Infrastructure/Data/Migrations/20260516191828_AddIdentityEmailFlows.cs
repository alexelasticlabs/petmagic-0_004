using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Identity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddIdentityEmailFlows : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "email_dispatch_jobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    RecipientEmail = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    Kind = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    HtmlBody = table.Column<string>(type: "character varying(20000)", maxLength: 20000, nullable: false),
                    TextBody = table.Column<string>(type: "character varying(20000)", maxLength: 20000, nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    QueuedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SentAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    FailureCode = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    FailureMessage = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_email_dispatch_jobs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "user_email_codes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    Purpose = table.Column<int>(type: "integer", nullable: false),
                    CodeHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    RequestedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ConsumedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastSentAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SendCount = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_email_codes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_NextAttemptAtUtc",
                table: "email_dispatch_jobs",
                column: "NextAttemptAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_Status_QueuedAtUtc",
                table: "email_dispatch_jobs",
                columns: new[] { "Status", "QueuedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_email_dispatch_jobs_UserId",
                table: "email_dispatch_jobs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_user_email_codes_Email_Purpose_ConsumedAtUtc",
                table: "user_email_codes",
                columns: new[] { "Email", "Purpose", "ConsumedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_user_email_codes_UserId_Purpose_ExpiresAtUtc",
                table: "user_email_codes",
                columns: new[] { "UserId", "Purpose", "ExpiresAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "email_dispatch_jobs");

            migrationBuilder.DropTable(
                name: "user_email_codes");
        }
    }
}
