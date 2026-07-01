using System.IO;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class PublicTemplateEndpointsSecurityTests
{
    [Fact]
    public void PublicTemplateEndpoints_ShouldSanitizeProblemDetailsForAnonymousReadRoutes()
    {
        var source = File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            "..",
            "..",
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));

        Assert.Contains("return ToPublicTemplateProblem(result.Error.Code, StatusCodes.Status404NotFound);", source);
        Assert.Contains("? \"Template was not found.\"", source);
        Assert.DoesNotContain(
            "TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);",
            source);
    }

    [Fact]
    public void PublicTemplateCatalogEndpoints_ShouldHandleFailuresBeforeReadingResultValue()
    {
        var source = File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            "..",
            "..",
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));

        Assert.Contains("return ToPublicCatalogProblem(result.Error.Code);", source);
        Assert.Contains("private static ProblemHttpResult ToPublicCatalogProblem(string errorCode)", source);
        Assert.Contains("private static ProblemHttpResult ToPublicValidationProblem(string errorCode)", source);
        Assert.Contains("private static string GetPublicValidationProblemDetail(string errorCode)", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_since_version\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_cursor\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_access\");", source);
        Assert.Contains("return ToPublicValidationProblem(\"templates.invalid_event_type\");", source);
        Assert.DoesNotContain("title: \"templates.invalid_since_version\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_cursor\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_access\"", source);
        Assert.DoesNotContain("title: \"templates.invalid_event_type\"", source);
        Assert.Contains("private static async Task<Results<Ok<PublicTemplatesCatalogVersionResponse>, ProblemHttpResult>> GetCatalogVersionAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<IReadOnlyList<PublicTemplateCategoryResponse>>, ProblemHttpResult>> ListCategoriesAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<PublicTemplateOfTheDayResponse>, ProblemHttpResult>> GetTemplateOfTheDayAsync(", source);
    }
}
