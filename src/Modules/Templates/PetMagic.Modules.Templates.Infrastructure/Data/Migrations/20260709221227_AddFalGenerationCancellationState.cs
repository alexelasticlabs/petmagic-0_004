using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Templates.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFalGenerationCancellationState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs");

            migrationBuilder.AddColumn<DateTime>(
                name: "CancellationAcceptedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CancellationAttemptCount",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancellationLastAttemptedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancellationLastErrorCode",
                table: "templates_generation_jobs",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancellationNextAttemptAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CancellationPreviousStatus",
                table: "templates_generation_jobs",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancellationRequestedAtUtc",
                table: "templates_generation_jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CancellationRequestedByAdminUserId",
                table: "templates_generation_jobs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MotionProviderCancelUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreprocessingProviderCancelUrl",
                table: "templates_generation_jobs",
                type: "character varying(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_tgj_PendingCancellation",
                table: "templates_generation_jobs",
                columns: new[] { "Status", "CancellationNextAttemptAtUtc" },
                filter: "\"Status\" = 11");

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "IdempotencyKey" },
                unique: true,
                filter: " \"Status\" IN (1, 2, 6, 7, 8, 9, 10, 11) AND \"IdempotencyKey\" IS NOT NULL ");

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "RequestHash" },
                unique: true,
                filter: " \"Status\" IN (1, 2, 6, 7, 8, 9, 10, 11) AND \"RequestHash\" IS NOT NULL ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_tgj_PendingCancellation",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs");

            migrationBuilder.DropIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationAcceptedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationAttemptCount",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationLastAttemptedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationLastErrorCode",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationNextAttemptAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationPreviousStatus",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationRequestedAtUtc",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "CancellationRequestedByAdminUserId",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "MotionProviderCancelUrl",
                table: "templates_generation_jobs");

            migrationBuilder.DropColumn(
                name: "PreprocessingProviderCancelUrl",
                table: "templates_generation_jobs");

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_IdempotencyKey_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "IdempotencyKey" },
                unique: true,
                filter: " \"Status\" IN (1, 2, 6, 7, 8, 9, 10) AND \"IdempotencyKey\" IS NOT NULL ");

            migrationBuilder.CreateIndex(
                name: "UX_templates_generation_jobs_UserId_RequestHash_active",
                table: "templates_generation_jobs",
                columns: new[] { "UserId", "RequestHash" },
                unique: true,
                filter: " \"Status\" IN (1, 2, 6, 7, 8, 9, 10) AND \"RequestHash\" IS NOT NULL ");
        }
    }
}
