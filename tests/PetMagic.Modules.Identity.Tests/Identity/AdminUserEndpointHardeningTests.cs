namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminUserEndpointHardeningTests
{
    [Fact]
    public void AdminUserMutations_ShouldMapStableFailureCodesToClientUsefulStatuses()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.Equal(
            11,
            CountOccurrences(source, "IdentityClientProblems.ToProblem(result.Error"));
        Assert.Contains("Task<Results<Ok<AdminUserDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("IdentityClientProblems.ToProblem(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Only Admin can assign Admin or Moderator roles.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source);
    }

    [Fact]
    public void IdentityClientProblems_ShouldCoverAdminIdentityFailureCodes()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "IdentityClientProblems.cs"));

        Assert.Contains("\"users.cannot_remove_last_admin\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"users.not_found\" => StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
        Assert.Contains("\"users.role_not_allowed\" => StatusCodes.Status403Forbidden", source, StringComparison.Ordinal);
        Assert.Contains("\"legal.catalog_unavailable\" => StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.insufficient_balance\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"At least one Admin must remain active.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"Current legal documents are temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source);
    }

    [Fact]
    public void AdminUserSearch_ShouldUseNormalizedCaseInsensitiveFallbackWithoutLegacyNullCrashes()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "IdentityService.AdminUsers.cs"));

        Assert.Contains("var normalizedSearchLower = normalizedSearch.ToLowerInvariant();", source, StringComparison.Ordinal);
        Assert.Contains("((user.Email ?? string.Empty).ToLower().Contains(normalizedSearchLower))", source, StringComparison.Ordinal);
        Assert.Contains("((user.DisplayName ?? string.Empty).ToLower().Contains(normalizedSearchLower))", source, StringComparison.Ordinal);
        Assert.DoesNotContain("normalizedSearch.ToLower()", source, StringComparison.Ordinal);
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
