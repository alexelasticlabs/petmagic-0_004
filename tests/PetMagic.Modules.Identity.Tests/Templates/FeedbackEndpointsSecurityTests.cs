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
        Assert.Contains("\"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"Feedback refund is not available.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"Feedback refund amount is invalid.\"", source, StringComparison.Ordinal);
        Assert.Contains("detail: GetProblemDetail(error.Code, statusCode)", source, StringComparison.Ordinal);
        Assert.Contains("private static string GetProblemDetail(string errorCode, int statusCode)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
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
}
