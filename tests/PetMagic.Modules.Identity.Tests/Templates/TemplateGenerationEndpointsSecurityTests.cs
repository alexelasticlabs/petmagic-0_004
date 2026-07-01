using System.IO;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationEndpointsSecurityTests
{
    [Fact]
    public void TemplateGenerationUserEndpoints_ShouldSanitizeProblemDetails()
    {
        var source = ReadEndpointSource("TemplateGenerationEndpoints");

        Assert.Contains("private static ProblemHttpResult ToClientGenerationProblem(Error error)", source);
        Assert.Contains("\"templates.invalid_subject\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("return ToClientGenerationProblem(result.Error);", source);
        Assert.Contains("return ToClientGenerationProblem(new Error(", source, StringComparison.Ordinal);
        Assert.Contains("PremiumRequiredCode,", source, StringComparison.Ordinal);
        Assert.Contains("private static ProblemHttpResult InvalidGenerationFilterProblem()", source, StringComparison.Ordinal);
        Assert.Contains(": InvalidGenerationFilterProblem();", source, StringComparison.Ordinal);
        Assert.Contains("\"Authentication failed.\"", source);
        Assert.Contains("\"GENERATION_QUEUE_OVERLOADED\" or \"GENERATION_WAIT_TOO_LONG\" => \"Generation queue is busy. Please try again later.\"", source);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: PremiumRequiredCode", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: PremiumRequiredMessage", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: subjectError.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "detail: result.Error.Message,\r\n                statusCode: ResolveFailureStatusCode(result.Error)",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "detail: storeResult.Error.Message",
            source,
            StringComparison.Ordinal);
    }

    private static string ReadEndpointSource(string baseFileName)
    {
        var root = FindRepositoryRoot();
        var dir = Path.Combine(
            root,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints");
        var files = Directory.GetFiles(dir, $"{baseFileName}*.cs");
        return string.Join("\n", files.Select(File.ReadAllText));
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
