using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.SupportChat.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportAssistantContext : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SenderType",
                table: "support_messages",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "AssistantScenario",
                table: "support_conversations",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RelatedGenerationId",
                table: "support_conversations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RelatedPaymentId",
                table: "support_conversations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RelatedSubscriptionId",
                table: "support_conversations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Source",
                table: "support_conversations",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SenderType",
                table: "support_messages");

            migrationBuilder.DropColumn(
                name: "AssistantScenario",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "RelatedGenerationId",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "RelatedPaymentId",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "RelatedSubscriptionId",
                table: "support_conversations");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "support_conversations");
        }
    }
}
