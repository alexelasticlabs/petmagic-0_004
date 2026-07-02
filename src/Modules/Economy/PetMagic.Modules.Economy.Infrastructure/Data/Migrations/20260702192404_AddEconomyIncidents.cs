using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Economy.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddEconomyIncidents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "economy_incidents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Severity = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    DeduplicationKey = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    PurchaseOrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    UserSubscriptionId = table.Column<Guid>(type: "uuid", nullable: true),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    ExternalReferenceId = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    Summary = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    DetailsJson = table.Column<string>(type: "character varying(32000)", maxLength: 32000, nullable: true),
                    DetectionCount = table.Column<int>(type: "integer", nullable: false),
                    RetryCount = table.Column<int>(type: "integer", nullable: false),
                    FirstDetectedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastDetectedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    NextRetryAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResolvedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResolutionNote = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    AutoFixApplied = table.Column<bool>(type: "boolean", nullable: false),
                    LastError = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_economy_incidents", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_DeduplicationKey",
                table: "economy_incidents",
                column: "DeduplicationKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_PurchaseOrderId",
                table: "economy_incidents",
                column: "PurchaseOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_Status_LastDetectedAtUtc",
                table: "economy_incidents",
                columns: new[] { "Status", "LastDetectedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_Type_Status_LastDetectedAtUtc",
                table: "economy_incidents",
                columns: new[] { "Type", "Status", "LastDetectedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_UserId_Status_LastDetectedAtUtc",
                table: "economy_incidents",
                columns: new[] { "UserId", "Status", "LastDetectedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_economy_incidents_UserSubscriptionId",
                table: "economy_incidents",
                column: "UserSubscriptionId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "economy_incidents");
        }
    }
}
