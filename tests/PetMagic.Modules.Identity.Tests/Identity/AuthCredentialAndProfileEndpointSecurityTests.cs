using System.IO;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AuthCredentialAndProfileEndpointSecurityTests
{
    [Fact]
    public void AuthCredentialAndProfileEndpoints_ShouldNotExposeRawIdentityErrorMessages()
    {
        var credentialsSource = ReadSource("AuthEndpoints.Credentials.cs");
        var profileSource = ReadSource("AuthEndpoints.Profile.cs");
        var legalSource = ReadSource("LegalEndpoints.cs");
        var helpersSource = ReadSource("AuthEndpoints.Helpers.cs");

        Assert.DoesNotContain("detail: result.Error.Message", credentialsSource);
        Assert.DoesNotContain("detail: result.Error.Message", profileSource);
        Assert.DoesNotContain("detail: result.Error.Message", legalSource);
        Assert.DoesNotContain("Invalid access token subject.", credentialsSource);
        Assert.DoesNotContain("Invalid access token subject.", profileSource);
        Assert.DoesNotContain("Invalid access token subject.", legalSource);

        Assert.Contains("IdentityClientProblems.ToProblem(result.Error", credentialsSource);
        Assert.Contains("IdentityClientProblems.ToProblem(result.Error", profileSource);
        Assert.Contains("IdentityClientProblems.ToProblem(result.Error", legalSource);
        Assert.Contains("IdentityClientProblems.ExternalProviderInvalid();", profileSource);
        Assert.DoesNotContain("detail: \"Unsupported provider.\"", profileSource);
        Assert.DoesNotContain("detail: \"Current legal documents are temporarily unavailable.\"", legalSource);
        Assert.Contains("problem = IdentityClientProblems.InvalidSubject();", helpersSource);
        Assert.Contains("if (!AuthEndpoints.TryGetUserId(context, out var userId, out var invalidSubjectProblem))", legalSource);
    }

    [Fact]
    public void IdentityClientProblems_ShouldMapSensitiveIdentityFailuresToSafeDetailsAndStatuses()
    {
        var source = ReadSource("IdentityClientProblems.cs");

        Assert.Contains("\"email.not_configured\" or \"email.dispatch_failed\" or \"users.avatar_storage_failed\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"auth.invalid_subject\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("\"auth.external_invalid\" => StatusCodes.Status400BadRequest", source);
        Assert.Contains("\"auth.invalid_refresh\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("\"auth.refresh_token_not_owned\" => StatusCodes.Status403Forbidden", source);
        Assert.Contains("\"users.not_found\" => StatusCodes.Status404NotFound", source);
        Assert.Contains("\"legal.catalog_unavailable\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"auth.invalid_subject\" => \"Authentication failed.\"", source);
        Assert.Contains("\"auth.external_invalid\" => \"Unsupported provider.\"", source);
        Assert.Contains("\"Current legal documents are temporarily unavailable.\"", source);
        Assert.Contains("\"Email delivery is temporarily unavailable.\"", source);
        Assert.Contains("\"Avatar upload is temporarily unavailable.\"", source);
        Assert.Contains("public static ProblemHttpResult InvalidSubject()", source);
        Assert.Contains("public static ProblemHttpResult ExternalProviderInvalid()", source);
        Assert.DoesNotContain("detail: error.Message", source);
    }

    private static string ReadSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            "..",
            "..",
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            fileName));
    }
}
