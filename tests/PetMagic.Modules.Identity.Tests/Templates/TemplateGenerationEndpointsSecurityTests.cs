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
        Assert.Contains("extensions: BuildClientGenerationProblemExtensions(error)", source, StringComparison.Ordinal);
        Assert.Contains("extensions: BuildClientGenerationProblemExtensions(\"templates.invalid_status\")", source, StringComparison.Ordinal);
        Assert.Contains("[\"code\"] = error.Code", source, StringComparison.Ordinal);
        Assert.Contains("\"PROVIDER_CAPACITY_UNAVAILABLE\" => StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.ai_provider_transient\" => StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.generation_attempts_exceeded\" => StatusCodes.Status503ServiceUnavailable", source, StringComparison.Ordinal);
        Assert.Contains("templates.source_image_empty", source, StringComparison.Ordinal);
        Assert.Contains("templates.source_image_type_not_allowed", source, StringComparison.Ordinal);
        Assert.Contains("templates.source_image_too_large", source, StringComparison.Ordinal);
        Assert.Contains("uploadValidation[\"Idempotency-Key\"] = [\"templates.idempotency_key_invalid\"];", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Source image is required.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Source image content type is not allowed.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Source image exceeds the maximum allowed size", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Idempotency-Key must be at most", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: PremiumRequiredCode", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: PremiumRequiredMessage", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: GetClientGenerationProblemDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("private static string GetClientGenerationProblemDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Generation queue is busy. Please try again later.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Too many feedback requests. Please try again later.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: subjectError.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Generation filter is invalid.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Query parameter status must be one of:", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "detail: result.Error.Message,\r\n                statusCode: ResolveFailureStatusCode(result.Error)",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "detail: storeResult.Error.Message",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateGenerationUploadValidation_ShouldRejectOversizedSourceBeforeSniffingContent()
    {
        var source = ReadEndpointSource("TemplateGenerationEndpoints");
        var validationBody = ExtractMethodBody(
            source,
            "private static async Task<Dictionary<string, string[]>> ValidateSourceImageAsync");
        var tooLargeIndex = validationBody.IndexOf(
            "templates.source_image_too_large",
            StringComparison.Ordinal);
        var sniffIndex = validationBody.IndexOf(
            "TemplateUploadSniffer.DetectContentTypeAsync",
            StringComparison.Ordinal);

        Assert.True(tooLargeIndex >= 0, "Expected source image size validation.");
        Assert.True(sniffIndex >= 0, "Expected source image content sniffing.");
        Assert.True(tooLargeIndex < sniffIndex, "Oversized uploads must be rejected before opening the file stream.");
    }

    [Fact]
    public void TemplateGenerationPrivateEndpoints_ShouldApplyPrivateCacheHeadersAtGroupLevel()
    {
        var source = ReadEndpointSource("TemplateGenerationEndpoints");

        Assert.Contains(".AddEndpointFilter(ApplyPrivateGenerationResponseHeadersAsync)", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.Pragma = \"no-cache\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.XContentTypeOptions = \"nosniff\";", source, StringComparison.Ordinal);
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

    private static string ExtractMethodBody(string source, string methodName)
    {
        var methodIndex = source.IndexOf(methodName, StringComparison.Ordinal);
        Assert.True(methodIndex >= 0, $"Method {methodName} was not found.");

        var openBraceIndex = source.IndexOf('{', methodIndex);
        Assert.True(openBraceIndex >= 0, $"Method {methodName} has no body.");

        var depth = 0;
        for (var index = openBraceIndex; index < source.Length; index++)
        {
            if (source[index] == '{')
            {
                depth++;
            }
            else if (source[index] == '}')
            {
                depth--;
                if (depth == 0)
                {
                    return source[openBraceIndex..(index + 1)];
                }
            }
        }

        throw new InvalidOperationException($"Method {methodName} body was not closed.");
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
