using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Gamification.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class BaselineGamification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "gamification_achievement_definitions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Key = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Category = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Rarity = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    TitleKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    DescriptionKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IconEmoji = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    IconAssetPath = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    RequirementType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    RequirementValue = table.Column<int>(type: "integer", nullable: false),
                    RewardSpark = table.Column<int>(type: "integer", nullable: false),
                    IsSecret = table.Column<bool>(type: "boolean", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_achievement_definitions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "gamification_daily_streaks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CurrentStreak = table.Column<int>(type: "integer", nullable: false),
                    LongestStreak = table.Column<int>(type: "integer", nullable: false),
                    LastActiveDate = table.Column<DateOnly>(type: "date", nullable: false),
                    StreakFreezesAvailable = table.Column<int>(type: "integer", nullable: false),
                    StreakFreezeUsedAt = table.Column<DateOnly>(type: "date", nullable: true),
                    FreezesResetAt = table.Column<DateOnly>(type: "date", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_daily_streaks", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "gamification_pet_progress",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PetId = table.Column<Guid>(type: "uuid", nullable: false),
                    Xp = table.Column<int>(type: "integer", nullable: false),
                    Level = table.Column<int>(type: "integer", nullable: false),
                    EvolutionStage = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    TotalGenerations = table.Column<int>(type: "integer", nullable: false),
                    FavoriteTemplateId = table.Column<Guid>(type: "uuid", nullable: true),
                    FirstGenerationAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastGenerationAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_pet_progress", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "gamification_user_achievements",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    AchievementKey = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    UnlockedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RewardCredited = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_user_achievements", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "gamification_user_challenge_progress",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChallengeId = table.Column<Guid>(type: "uuid", nullable: false),
                    CurrentValue = table.Column<int>(type: "integer", nullable: false),
                    Completed = table.Column<bool>(type: "boolean", nullable: false),
                    CompletedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RewardCredited = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_user_challenge_progress", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "gamification_weekly_challenges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    WeekStartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ChallengeType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    TargetValue = table.Column<int>(type: "integer", nullable: false),
                    TitleKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    DescriptionKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    RewardSpark = table.Column<int>(type: "integer", nullable: false),
                    IconEmoji = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_gamification_weekly_challenges", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_gamification_achievement_definitions_Key",
                table: "gamification_achievement_definitions",
                column: "Key",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_daily_streaks_UserId",
                table: "gamification_daily_streaks",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_pet_progress_UserId",
                table: "gamification_pet_progress",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_pet_progress_UserId_PetId",
                table: "gamification_pet_progress",
                columns: new[] { "UserId", "PetId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_user_achievements_UserId",
                table: "gamification_user_achievements",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_user_achievements_UserId_AchievementKey",
                table: "gamification_user_achievements",
                columns: new[] { "UserId", "AchievementKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_user_challenge_progress_UserId",
                table: "gamification_user_challenge_progress",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_user_challenge_progress_UserId_ChallengeId",
                table: "gamification_user_challenge_progress",
                columns: new[] { "UserId", "ChallengeId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_gamification_weekly_challenges_WeekStartDate",
                table: "gamification_weekly_challenges",
                column: "WeekStartDate");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "gamification_achievement_definitions");

            migrationBuilder.DropTable(
                name: "gamification_daily_streaks");

            migrationBuilder.DropTable(
                name: "gamification_pet_progress");

            migrationBuilder.DropTable(
                name: "gamification_user_achievements");

            migrationBuilder.DropTable(
                name: "gamification_user_challenge_progress");

            migrationBuilder.DropTable(
                name: "gamification_weekly_challenges");
        }
    }
}
