using System.IO;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class PublicTemplateEndpointsSecurityTests
{
    [Fact]
    public void PublicTemplateEndpoints_ShouldSanitizeProblemDetailsForAnonymousReadRoutes()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));

        Assert.Contains("return ToPublicTemplateProblem(result.Error.Code, StatusCodes.Status404NotFound);", source);
        Assert.Contains("extensions: BuildPublicProblemExtensions(errorCode)", source);
        Assert.Contains("[\"code\"] = errorCode", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Template was not found.\"", source);
        Assert.DoesNotContain("Template request could not be completed.", source);
        Assert.DoesNotContain(
            "TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);",
            source);
    }

    [Fact]
    public void PublicTemplateCatalogEndpoints_ShouldHandleFailuresBeforeReadingResultValue()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));

        Assert.Contains("return ToPublicCatalogProblem(result.Error.Code);", source);
        Assert.Contains("private static ProblemHttpResult ToPublicCatalogProblem(string errorCode)", source);
        Assert.Contains("private static ProblemHttpResult ToPublicValidationProblem(string errorCode)", source);
        Assert.Contains("private static Dictionary<string, object?> BuildPublicProblemExtensions(string errorCode)", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_since_version\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_cursor\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_access\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_event_type\");", source);
        Assert.DoesNotContain("private static string GetPublicValidationProblemDetail(string errorCode)", source);
        Assert.DoesNotContain("Template catalog version filter is invalid.", source);
        Assert.DoesNotContain("Template catalog type filter is invalid.", source);
        Assert.DoesNotContain("Template catalog cursor is invalid.", source);
        Assert.DoesNotContain("Template catalog access filter is invalid.", source);
        Assert.DoesNotContain("Template analytics event type is invalid.", source);
        Assert.DoesNotContain("Template content was not found.", source);
        Assert.DoesNotContain("Template catalog is temporarily unavailable.", source);
        Assert.DoesNotContain("title: \"templates.invalid_since_version\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_cursor\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_access\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_event_type\"", source);
        Assert.DoesNotContain("Query parameter sinceVersion must be a non-negative integer.", source);
        Assert.DoesNotContain("Query parameter type must be Image, Video, or all.", source);
        Assert.DoesNotContain("Query parameter cursor must be the nextCursor value returned by a previous feed response.", source);
        Assert.DoesNotContain("Query parameter access must be all, free, or premium.", source);
        Assert.DoesNotContain("Request field eventType must be a supported analytics event name.", source);
        Assert.Contains("private static async Task<Results<Ok<PublicTemplatesCatalogVersionResponse>, ProblemHttpResult>> GetCatalogVersionAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<IReadOnlyList<PublicTemplateCategoryResponse>>, ProblemHttpResult>> ListCategoriesAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<PublicTemplateOfTheDayResponse>, ProblemHttpResult>> GetTemplateOfTheDayAsync(", source);
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
