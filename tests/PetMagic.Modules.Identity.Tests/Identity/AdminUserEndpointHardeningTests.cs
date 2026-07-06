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
            10,
            CountOccurrences(source, "IdentityClientProblems.ToProblem(result.Error"));
        Assert.Contains("Task<Results<Ok<AdminUserDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("IdentityClientProblems.ToProblem(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Only Admin can assign Admin or Moderator roles.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source);
    }

    [Fact]
    public void AdminUserEndpoints_ShouldApplyPrivateCacheHeaders()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.Contains(".AddEndpointFilter(ApplyPrivateAdminUserResponseHeadersAsync)", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.Pragma = \"no-cache\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.XContentTypeOptions = \"nosniff\";", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminUserEndpoints_ShouldRequireAdminOnlyForUserProfileData()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.Contains(".RequireAuthorization(\"AdminOnly\")", source, StringComparison.Ordinal);
        Assert.DoesNotContain(".RequireAuthorization(\"ModeratorOrAdmin\")", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"\", ListUsersAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/dashboard/metrics\", GetDashboardMetricsAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/{userId:guid}\", GetUserAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/{userId:guid}/analytics\", GetUserAnalyticsAsync);", source, StringComparison.Ordinal);
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
        Assert.Contains("extensions: BuildProblemExtensions(error.Code)", source, StringComparison.Ordinal);
        Assert.Contains("return new Dictionary<string, object?> { [\"code\"] = errorCode };", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail:", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source);
        Assert.DoesNotContain("At least one Admin must remain active.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Current legal documents are temporarily unavailable.", source, StringComparison.Ordinal);
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

    [Fact]
    public void AdminUserList_ShouldKeepAuthoritativeBackendSortModesExplicit()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "IdentityService.AdminUsers.cs"));

        Assert.Contains("last_activity_desc", source, StringComparison.Ordinal);
        Assert.Contains("last_activity_asc", source, StringComparison.Ordinal);
        Assert.Contains("IsAdminUsersLastActivitySort(normalizedSort)", source, StringComparison.Ordinal);
        Assert.Contains("LoadAdminUserLastActivityAsync(candidateUserIds, cancellationToken)", source, StringComparison.Ordinal);
        Assert.Contains("ResolveAdminUserLastActivity(lastActivityByUserId, user.Id)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminUserMutationEndpoints_ShouldLimitRequestBodiesBeforeJsonBinding()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.Contains("private const int MaxAdminUserMutationRequestBodyBytes = 8 * 1024;", source, StringComparison.Ordinal);
        Assert.Contains("private const int MaxAdminBulkEmailRequestBodyBytes = 64 * 1024;", source, StringComparison.Ordinal);
        Assert.Equal(
            5,
            CountOccurrences(source, ".WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));"));
        Assert.Contains(".WithMetadata(new RequestSizeLimitAttribute(MaxAdminBulkEmailRequestBodyBytes));", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminUserEndpoints_ShouldNotExposeDirectPremiumGrantRoute()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.DoesNotContain("MapPut(\"/{userId:guid}/premium\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("SetPremiumStatusRequest", source, StringComparison.Ordinal);
        Assert.DoesNotContain("SetPremiumStatusAsync(", source, StringComparison.Ordinal);
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
