using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTemplateDiscoveryConfiguration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "templates_discovery_revisions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Number = table.Column<long>(type: "bigint", nullable: false),
                    EditVersion = table.Column<long>(type: "bigint", nullable: false),
                    State = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    DocumentJson = table.Column<string>(type: "text", nullable: false),
                    BasedOnRevisionId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    PublishedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_discovery_revisions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_discovery_revisions_templates_discovery_revisions~",
                        column: x => x.BasedOnRevisionId,
                        principalTable: "templates_discovery_revisions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "templates_discovery_command_receipts",
                columns: table => new
                {
                    ActorId = table.Column<Guid>(type: "uuid", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RevisionId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_discovery_command_receipts", x => new { x.ActorId, x.IdempotencyKey });
                    table.ForeignKey(
                        name: "FK_templates_discovery_command_receipts_templates_discovery_re~",
                        column: x => x.RevisionId,
                        principalTable: "templates_discovery_revisions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "templates_discovery_pages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    LastRevisionNumber = table.Column<long>(type: "bigint", nullable: false),
                    PublishedRevisionId = table.Column<Guid>(type: "uuid", nullable: true),
                    DraftRevisionId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_templates_discovery_pages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_templates_discovery_pages_templates_discovery_revisions_Dra~",
                        column: x => x.DraftRevisionId,
                        principalTable: "templates_discovery_revisions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_templates_discovery_pages_templates_discovery_revisions_Pub~",
                        column: x => x.PublishedRevisionId,
                        principalTable: "templates_discovery_revisions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "templates_discovery_pages",
                columns: new[] { "Id", "DraftRevisionId", "LastRevisionNumber", "PublishedRevisionId", "Version" },
                values: new object[] { 1, null, 0L, null, 0L });

            migrationBuilder.CreateIndex(
                name: "IX_templates_discovery_command_receipts_RevisionId",
                table: "templates_discovery_command_receipts",
                column: "RevisionId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_discovery_pages_DraftRevisionId",
                table: "templates_discovery_pages",
                column: "DraftRevisionId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_discovery_pages_PublishedRevisionId",
                table: "templates_discovery_pages",
                column: "PublishedRevisionId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_discovery_revisions_BasedOnRevisionId",
                table: "templates_discovery_revisions",
                column: "BasedOnRevisionId");

            migrationBuilder.CreateIndex(
                name: "IX_templates_discovery_revisions_Number",
                table: "templates_discovery_revisions",
                column: "Number",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "templates_discovery_command_receipts");

            migrationBuilder.DropTable(
                name: "templates_discovery_pages");

            migrationBuilder.DropTable(
                name: "templates_discovery_revisions");
        }
    }
}
