using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PetMagic.Modules.Gamification.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class HardenGamificationWeeklyChallengeUniqueness : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                CREATE TEMP TABLE tmp_gamification_challenge_merge ON COMMIT DROP AS
                SELECT
                    challenge."Id" AS "ChallengeId",
                    FIRST_VALUE(challenge."Id") OVER (
                        PARTITION BY challenge."WeekStartDate", challenge."ChallengeType"
                        ORDER BY challenge."CreatedAtUtc", challenge."Id") AS "CanonicalChallengeId"
                FROM gamification_weekly_challenges AS challenge
                WHERE (challenge."WeekStartDate", challenge."ChallengeType") IN (
                    SELECT duplicate."WeekStartDate", duplicate."ChallengeType"
                    FROM gamification_weekly_challenges AS duplicate
                    GROUP BY duplicate."WeekStartDate", duplicate."ChallengeType"
                    HAVING COUNT(*) > 1
                );

                CREATE TEMP TABLE tmp_gamification_progress_merge ON COMMIT DROP AS
                SELECT
                    mapping."CanonicalChallengeId",
                    progress."UserId",
                    (ARRAY_AGG(progress."Id" ORDER BY progress."Id"))[1] AS "KeepProgressId",
                    LEAST(SUM(progress."CurrentValue"), MAX(canonical."TargetValue"))::integer AS "CurrentValue",
                    (BOOL_OR(progress."Completed") OR SUM(progress."CurrentValue") >= MAX(canonical."TargetValue")) AS "Completed",
                    CASE
                        WHEN BOOL_OR(progress."Completed") OR SUM(progress."CurrentValue") >= MAX(canonical."TargetValue")
                            THEN COALESCE(
                                MIN(progress."CompletedAtUtc") FILTER (WHERE progress."CompletedAtUtc" IS NOT NULL),
                                CURRENT_TIMESTAMP)
                        ELSE NULL
                    END AS "CompletedAtUtc",
                    BOOL_OR(progress."RewardCredited") AS "RewardCredited"
                FROM gamification_user_challenge_progress AS progress
                INNER JOIN tmp_gamification_challenge_merge AS mapping
                    ON mapping."ChallengeId" = progress."ChallengeId"
                INNER JOIN gamification_weekly_challenges AS canonical
                    ON canonical."Id" = mapping."CanonicalChallengeId"
                GROUP BY mapping."CanonicalChallengeId", progress."UserId";

                DELETE FROM gamification_user_challenge_progress AS progress
                USING tmp_gamification_challenge_merge AS mapping,
                      tmp_gamification_progress_merge AS merged
                WHERE mapping."ChallengeId" = progress."ChallengeId"
                  AND merged."CanonicalChallengeId" = mapping."CanonicalChallengeId"
                  AND merged."UserId" = progress."UserId"
                  AND progress."Id" <> merged."KeepProgressId";

                UPDATE gamification_user_challenge_progress AS progress
                SET "ChallengeId" = merged."CanonicalChallengeId",
                    "CurrentValue" = merged."CurrentValue",
                    "Completed" = merged."Completed",
                    "CompletedAtUtc" = merged."CompletedAtUtc",
                    "RewardCredited" = merged."RewardCredited"
                FROM tmp_gamification_progress_merge AS merged
                WHERE progress."Id" = merged."KeepProgressId";

                DELETE FROM gamification_weekly_challenges AS challenge
                USING tmp_gamification_challenge_merge AS mapping
                WHERE challenge."Id" = mapping."ChallengeId"
                  AND mapping."ChallengeId" <> mapping."CanonicalChallengeId";
                """);

            migrationBuilder.DropIndex(
                name: "IX_gamification_weekly_challenges_WeekStartDate",
                table: "gamification_weekly_challenges");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_weekly_challenges_WeekStartDate_ChallengeType",
                table: "gamification_weekly_challenges",
                columns: new[] { "WeekStartDate", "ChallengeType" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_gamification_weekly_challenges_WeekStartDate_ChallengeType",
                table: "gamification_weekly_challenges");

            migrationBuilder.CreateIndex(
                name: "IX_gamification_weekly_challenges_WeekStartDate",
                table: "gamification_weekly_challenges",
                column: "WeekStartDate");
        }
    }
}
