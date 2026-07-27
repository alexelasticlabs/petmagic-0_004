namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FeedbackEndpointsSecurityTests
{
    [Fact]
    public void FeedbackEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Contains("private static ProblemHttpResult ToProblem(Error error)", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.invalid_subject\" => StatusCodes.Status401Unauthorized", source, StringComparison.Ordinal);
        Assert.Contains("\"feedback.refund_unavailable\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"feedback.refund_already_issued\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("extensions: BuildProblemExtensions(error.Code)", source, StringComparison.Ordinal);
        Assert.Contains("private static Dictionary<string, object?> BuildProblemExtensions(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("[\"code\"] = errorCode", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Feedback refund is not available.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Feedback refund amount is invalid.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Feedback was submitted too frequently.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Too many feedback requests", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: GetProblemDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: subjectError.Message", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FeedbackAdminActions_ShouldRejectInvalidAdminSubject()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Contains("var (adminUserId, subjectError) = TryGetAdminUserId(context);", source, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(subjectError);", source, StringComparison.Ordinal);
        Assert.Contains("private static (Guid UserId, Error? Error) TryGetAdminUserId(HttpContext context)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("return Guid.TryParse(subject, out var userId) ? userId : Guid.Empty;", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FeedbackSubmitEndpoint_ShouldHideForbiddenTargetOwnership()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Contains("? ToUserProblem(result.Error)", source, StringComparison.Ordinal);
        Assert.Contains("private static ProblemHttpResult ToUserProblem(Error error)", source, StringComparison.Ordinal);
        Assert.Contains("if (error.Code == \"feedback.forbidden\")", source, StringComparison.Ordinal);
        Assert.Contains("title: \"feedback.not_found\"", source, StringComparison.Ordinal);
        Assert.Contains("statusCode: StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
        Assert.Contains("\"feedback.forbidden\" => StatusCodes.Status403Forbidden", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FeedbackMutationEndpoints_ShouldLimitRequestBodiesBeforeJsonBinding()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Contains("private const int MaxFeedbackRequestBodyBytes = 8 * 1024;", source, StringComparison.Ordinal);
        Assert.Contains("private const int MaxAdminFeedbackMutationRequestBodyBytes = 8 * 1024;", source, StringComparison.Ordinal);
        Assert.Contains(".WithMetadata(new RequestSizeLimitAttribute(MaxFeedbackRequestBodyBytes));", source, StringComparison.Ordinal);
        Assert.Equal(
            2,
            CountOccurrences(source, ".WithMetadata(new RequestSizeLimitAttribute(MaxAdminFeedbackMutationRequestBodyBytes));"));
    }

    [Fact]
    public void FeedbackEndpoints_ShouldApplyPrivateCacheHeadersToAuthenticatedResponses()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Contains("private static async ValueTask<object?> ApplyPrivateFeedbackResponseHeadersAsync", source, StringComparison.Ordinal);
        Assert.Contains("Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
        Assert.Contains("Headers.Pragma = \"no-cache\";", source, StringComparison.Ordinal);
        Assert.Contains("Headers.XContentTypeOptions = \"nosniff\";", source, StringComparison.Ordinal);
        Assert.Equal(3, CountOccurrences(source, ".AddEndpointFilter(ApplyPrivateFeedbackResponseHeadersAsync)"));
        Assert.Contains(".RequireAuthorization()", source, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"ModeratorOrAdmin\")", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FeedbackDetails_ShouldHideRefundContextFromNonAdminViewers()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "FeedbackEndpoints.cs"));

        Assert.Equal(2, CountOccurrences(source, "RestrictAdminFeedbackDetailsForRole(context, result.Value)"));
        Assert.Contains(
            "private static AdminFeedbackDetailsResponse RestrictAdminFeedbackDetailsForRole(",
            source,
            StringComparison.Ordinal);
        Assert.Contains("context.User.IsInRole(\"Admin\")", source, StringComparison.Ordinal);
        Assert.Contains(
            "details with { CanRefund = false, Refund = null, RefundUnavailableReason = null }",
            source,
            StringComparison.Ordinal);
        Assert.Contains("GetAdminFeedbackAsync(", source, StringComparison.Ordinal);
        Assert.Contains("HttpContext context,", source, StringComparison.Ordinal);
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
