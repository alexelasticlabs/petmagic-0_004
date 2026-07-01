namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatEndpointHardeningTests
{
    [Fact]
    public void SupportChatEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = ReadEndpointSource("SupportChatEndpoints.AdminTicketActions.cs");
        var managementSource = ReadEndpointSource("SupportChatEndpoints.AdminConversationManagement.cs");
        var accessSource = ReadEndpointSource("SupportChatEndpoints.AdminConversationAccess.cs");

        Assert.Contains("detail: GetProblemDetail(error.Code, statusCode)", source, StringComparison.Ordinal);
        Assert.Contains("private static string GetProblemDetail(string errorCode, int statusCode)", source, StringComparison.Ordinal);
        Assert.Contains("\"support.invalid_subject\" => StatusCodes.Status401Unauthorized", source, StringComparison.Ordinal);
        Assert.Contains("\"support.invalid_subject\" => \"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.Contains("unauthorized = ToProblem(new Error(", source, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(new Error(", managementSource, StringComparison.Ordinal);
        Assert.Contains("\"support.status_invalid\"", managementSource, StringComparison.Ordinal);
        Assert.Contains("\"support.priority_invalid\"", managementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support conversation status is not supported.\"", managementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support conversation priority is not supported.\"", managementSource, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(new Error(", accessSource, StringComparison.Ordinal);
        Assert.Contains("\"support.assignment_invalid\"", accessSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support inbox assignment filter is not supported.\"", accessSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Invalid access token subject.\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SupportChatAdminAccessEndpoints_ShouldGuardServiceFailures()
    {
        var source = ReadEndpointSource("SupportChatEndpoints.AdminConversationAccess.cs");

        Assert.Contains("Task<Results<Ok<AdminSupportInboxMetricsResponse>, ProblemHttpResult>> GetAdminInboxMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", source, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(result.Error);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminInboxMetricsAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    private static string ReadEndpointSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Endpoints",
            fileName));
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
