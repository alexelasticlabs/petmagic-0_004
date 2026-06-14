using System;

using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.Modules.Templates.Infrastructure.Data;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations;

[DbContext(typeof(TemplatesDbContext))]
[Migration("20260614233000_AddFeedbackSystem")]
public partial class AddFeedbackSystem : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_templates_generation_feedback_templates_generation_jobs_Gen~",
            table: "templates_generation_feedback");

        migrationBuilder.DropForeignKey(
            name: "FK_templates_generation_feedback_templates_items_TemplateId",
            table: "templates_generation_feedback");

        migrationBuilder.AlterColumn<Guid>(
            name: "UserId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: true,
            oldClrType: typeof(Guid),
            oldType: "uuid");

        migrationBuilder.AlterColumn<Guid>(
            name: "TemplateId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: true,
            oldClrType: typeof(Guid),
            oldType: "uuid");

        migrationBuilder.AlterColumn<int>(
            name: "Rating",
            table: "templates_generation_feedback",
            type: "integer",
            nullable: true,
            oldClrType: typeof(int),
            oldType: "integer");

        migrationBuilder.AlterColumn<Guid>(
            name: "GenerationId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: true,
            oldClrType: typeof(Guid),
            oldType: "uuid");

        migrationBuilder.AddColumn<string>(
            name: "AdminNote",
            table: "templates_generation_feedback",
            type: "character varying(2000)",
            maxLength: 2000,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "AppVersion",
            table: "templates_generation_feedback",
            type: "character varying(64)",
            maxLength: 64,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Category",
            table: "templates_generation_feedback",
            type: "character varying(80)",
            maxLength: 80,
            nullable: false,
            defaultValue: "");

        migrationBuilder.AddColumn<string>(
            name: "DeviceModel",
            table: "templates_generation_feedback",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "ErrorCode",
            table: "templates_generation_feedback",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Locale",
            table: "templates_generation_feedback",
            type: "character varying(16)",
            maxLength: 16,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Message",
            table: "templates_generation_feedback",
            type: "character varying(2000)",
            maxLength: 2000,
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "PetId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Platform",
            table: "templates_generation_feedback",
            type: "character varying(32)",
            maxLength: 32,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Priority",
            table: "templates_generation_feedback",
            type: "character varying(24)",
            maxLength: 24,
            nullable: false,
            defaultValue: "Low");

        migrationBuilder.AddColumn<string>(
            name: "ProviderName",
            table: "templates_generation_feedback",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "ReviewedByAdminId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "ReviewedAtUtc",
            table: "templates_generation_feedback",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "SourceScreen",
            table: "templates_generation_feedback",
            type: "character varying(80)",
            maxLength: 80,
            nullable: false,
            defaultValue: "");

        migrationBuilder.AddColumn<string>(
            name: "Status",
            table: "templates_generation_feedback",
            type: "character varying(24)",
            maxLength: 24,
            nullable: false,
            defaultValue: "New");

        migrationBuilder.AddColumn<string>(
            name: "Type",
            table: "templates_generation_feedback",
            type: "character varying(32)",
            maxLength: 32,
            nullable: false,
            defaultValue: "GenerationResult");

        migrationBuilder.CreateTable(
            name: "templates_credit_refunds",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                FeedbackId = table.Column<Guid>(type: "uuid", nullable: true),
                GenerationId = table.Column<Guid>(type: "uuid", nullable: true),
                Amount = table.Column<int>(type: "integer", nullable: false),
                Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                AdminId = table.Column<Guid>(type: "uuid", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_templates_credit_refunds", x => x.Id);
                table.ForeignKey(
                    name: "FK_templates_credit_refunds_templates_generation_feedback_FeedbackId",
                    column: x => x.FeedbackId,
                    principalTable: "templates_generation_feedback",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
                table.ForeignKey(
                    name: "FK_templates_credit_refunds_templates_generation_jobs_GenerationId",
                    column: x => x.GenerationId,
                    principalTable: "templates_generation_jobs",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
            });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_feedback_Status_Priority_CreatedAtUtc",
            table: "templates_generation_feedback",
            columns: new[] { "Status", "Priority", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_feedback_Type_Category_CreatedAtUtc",
            table: "templates_generation_feedback",
            columns: new[] { "Type", "Category", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_generation_feedback_UserId_CreatedAtUtc",
            table: "templates_generation_feedback",
            columns: new[] { "UserId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_templates_credit_refunds_UserId_CreatedAtUtc",
            table: "templates_credit_refunds",
            columns: new[] { "UserId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "UX_templates_credit_refunds_FeedbackId",
            table: "templates_credit_refunds",
            column: "FeedbackId",
            unique: true,
            filter: "\"FeedbackId\" IS NOT NULL");

        migrationBuilder.CreateIndex(
            name: "UX_templates_credit_refunds_GenerationId",
            table: "templates_credit_refunds",
            column: "GenerationId",
            unique: true,
            filter: "\"GenerationId\" IS NOT NULL");

        migrationBuilder.AddForeignKey(
            name: "FK_templates_generation_feedback_templates_generation_jobs_Gen~",
            table: "templates_generation_feedback",
            column: "GenerationId",
            principalTable: "templates_generation_jobs",
            principalColumn: "Id",
            onDelete: ReferentialAction.SetNull);

        migrationBuilder.AddForeignKey(
            name: "FK_templates_generation_feedback_templates_items_TemplateId",
            table: "templates_generation_feedback",
            column: "TemplateId",
            principalTable: "templates_items",
            principalColumn: "Id",
            onDelete: ReferentialAction.SetNull);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_templates_generation_feedback_templates_generation_jobs_Gen~",
            table: "templates_generation_feedback");

        migrationBuilder.DropForeignKey(
            name: "FK_templates_generation_feedback_templates_items_TemplateId",
            table: "templates_generation_feedback");

        migrationBuilder.DropTable(name: "templates_credit_refunds");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_feedback_Status_Priority_CreatedAtUtc",
            table: "templates_generation_feedback");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_feedback_Type_Category_CreatedAtUtc",
            table: "templates_generation_feedback");

        migrationBuilder.DropIndex(
            name: "IX_templates_generation_feedback_UserId_CreatedAtUtc",
            table: "templates_generation_feedback");

        migrationBuilder.DropColumn(name: "AdminNote", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "AppVersion", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Category", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "DeviceModel", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "ErrorCode", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Locale", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Message", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "PetId", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Platform", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Priority", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "ProviderName", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "ReviewedAtUtc", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "ReviewedByAdminId", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "SourceScreen", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Status", table: "templates_generation_feedback");
        migrationBuilder.DropColumn(name: "Type", table: "templates_generation_feedback");

        migrationBuilder.AlterColumn<Guid>(
            name: "UserId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: false,
            defaultValue: Guid.Empty,
            oldClrType: typeof(Guid),
            oldType: "uuid",
            oldNullable: true);

        migrationBuilder.AlterColumn<Guid>(
            name: "TemplateId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: false,
            defaultValue: Guid.Empty,
            oldClrType: typeof(Guid),
            oldType: "uuid",
            oldNullable: true);

        migrationBuilder.AlterColumn<int>(
            name: "Rating",
            table: "templates_generation_feedback",
            type: "integer",
            nullable: false,
            defaultValue: 0,
            oldClrType: typeof(int),
            oldType: "integer",
            oldNullable: true);

        migrationBuilder.AlterColumn<Guid>(
            name: "GenerationId",
            table: "templates_generation_feedback",
            type: "uuid",
            nullable: false,
            defaultValue: Guid.Empty,
            oldClrType: typeof(Guid),
            oldType: "uuid",
            oldNullable: true);

        migrationBuilder.AddForeignKey(
            name: "FK_templates_generation_feedback_templates_generation_jobs_Gen~",
            table: "templates_generation_feedback",
            column: "GenerationId",
            principalTable: "templates_generation_jobs",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_templates_generation_feedback_templates_items_TemplateId",
            table: "templates_generation_feedback",
            column: "TemplateId",
            principalTable: "templates_items",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);
    }
}
