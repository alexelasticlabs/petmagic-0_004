namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationEndpointHardeningTests
{
    [Fact]
    public void AdminGamificationEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Api",
            "Endpoints",
            "AdminGamificationEndpoints.cs"));

        Assert.Contains("private static ProblemHttpResult ToAdminGamificationProblem(Error error)", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminGamificationProblem(result.Error);", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminGamificationDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>, ProblemHttpResult>> ListAchievementsAsync", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>, ProblemHttpResult>> ListCurrentChallengesAsync", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminUserGamificationOverviewResponse>, ProblemHttpResult>> GetUserOverviewAsync", source, StringComparison.Ordinal);
        Assert.Equal(5, CountOccurrences(source, "if (result.IsFailure)"));
        Assert.DoesNotContain("detail: result.Error.Message", source, StringComparison.Ordinal);
    }

    [Fact]
    public void UserGamificationEndpoints_ShouldUseSafeInvalidSubjectProblem()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Api",
            "Endpoints",
            "GamificationEndpoints.cs"));

        Assert.Contains("private static ProblemHttpResult InvalidSubjectProblem()", source, StringComparison.Ordinal);
        Assert.Contains("title: InvalidSubjectCode", source, StringComparison.Ordinal);
        Assert.Contains("detail: \"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Invalid access token subject.\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void UserGamificationEndpoints_ShouldUseSanitizedProblemDetailsForNotFoundResponses()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Api",
            "Endpoints",
            "GamificationEndpoints.cs"));

        Assert.Contains("private const string PetProgressNotFoundCode = \"gamification.pet_progress_not_found\";", source, StringComparison.Ordinal);
        Assert.Contains("private const string StreakNotFoundCode = \"gamification.streak_not_found\";", source, StringComparison.Ordinal);
        Assert.Contains("private static ProblemHttpResult NotFoundProblem(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("return result is null ? NotFoundProblem(PetProgressNotFoundCode) : TypedResults.Ok(result);", source, StringComparison.Ordinal);
        Assert.Contains("return result is null ? NotFoundProblem(StreakNotFoundCode) : TypedResults.Ok(result);", source, StringComparison.Ordinal);
        Assert.Contains("statusCode: StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
        Assert.DoesNotContain("TypedResults.NotFound()", source, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }

    private static int CountOccurrences(string source, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }
}
