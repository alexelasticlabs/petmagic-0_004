using System.IO;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AuthCredentialAndProfileEndpointSecurityTests
{
    [Fact]
    public void AuthCredentialAndProfileEndpoints_ShouldNotExposeRawIdentityErrorMessages()
    {
        var credentialsSource = ReadSource("AuthEndpoints.Credentials.cs");
        var authRouteSource = ReadSource("AuthEndpoints.cs");
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
        Assert.DoesNotContain("detail: \"External authentication request is invalid.\"", profileSource);
        Assert.DoesNotContain("Avatar file is required.", profileSource);
        Assert.DoesNotContain("Avatar content type is not allowed.", profileSource);
        Assert.Contains("users.avatar_file_required", profileSource);
        Assert.Contains("users.avatar_content_type_not_allowed", profileSource);
        Assert.Contains("users.avatar_file_too_large", profileSource);
        Assert.DoesNotContain("TypedResults.ValidationProblem(validation.Errors)", profileSource);
        Assert.Contains("return ToAvatarValidationProblem(validation.Errors);", profileSource);
        Assert.Contains("_ => \"validation.invalid\"", profileSource);
        Assert.DoesNotContain("detail: \"Current legal documents are temporarily unavailable.\"", legalSource);
        Assert.Contains("problem = IdentityClientProblems.InvalidSubject();", helpersSource);
        Assert.Contains("if (!AuthEndpoints.TryGetUserId(context, out var userId, out var invalidSubjectProblem))", legalSource);
        Assert.Contains(".AddEndpointFilter(ApplySensitiveNoStoreHeadersAsync)", authRouteSource, StringComparison.Ordinal);
        Assert.True(
            CountOccurrences(profileSource, "ApplySensitiveNoStoreHeaders(context);") >= 8,
            "Profile endpoints returning private profile, link, or account data must apply no-store headers.");
        Assert.Contains("ApplySensitiveNoStoreHeaders(context.HttpContext);", authRouteSource, StringComparison.Ordinal);
        Assert.Contains("Headers.XContentTypeOptions = \"nosniff\";", helpersSource, StringComparison.Ordinal);
        Assert.Contains("ApplySensitiveNoStoreHeaders(context);", legalSource, StringComparison.Ordinal);
        Assert.Contains("Headers.XContentTypeOptions = \"nosniff\";", legalSource, StringComparison.Ordinal);
    }

    [Fact]
    public void IdentityClientProblems_ShouldMapSensitiveIdentityFailuresToSafeCodesAndStatuses()
    {
        var source = ReadSource("IdentityClientProblems.cs");

        Assert.Contains("\"email.not_configured\" or \"email.dispatch_failed\" or \"users.avatar_storage_failed\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"auth.invalid_subject\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("\"auth.external_invalid\" => StatusCodes.Status400BadRequest", source);
        Assert.Contains("\"auth.invalid_refresh\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("\"auth.refresh_token_not_owned\" => StatusCodes.Status403Forbidden", source);
        Assert.Contains("\"users.not_found\" => StatusCodes.Status404NotFound", source);
        Assert.Contains("\"legal.catalog_unavailable\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("extensions: BuildProblemExtensions(\"auth.invalid_subject\")", source);
        Assert.Contains("extensions: BuildProblemExtensions(\"auth.external_invalid\")", source);
        Assert.Contains("extensions: BuildProblemExtensions(error.Code)", source);
        Assert.Contains("return new Dictionary<string, object?> { [\"code\"] = errorCode };", source);
        Assert.Contains("public static ProblemHttpResult InvalidSubject()", source);
        Assert.Contains("public static ProblemHttpResult ExternalProviderInvalid()", source);
        Assert.DoesNotContain("GetDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail:", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"External authentication request is invalid.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Current legal documents are temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Email delivery is temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Avatar upload is temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source);
    }

    [Fact]
    public void AvatarUploadEndpoint_ShouldLimitRequestBodyBeforeFormBinding()
    {
        var source = ReadSource("AuthEndpoints.cs");

        Assert.Contains("private const long MaxAvatarUploadRequestBodyBytes = 9L * 1024 * 1024;", source);
        Assert.Contains(".WithMetadata(new RequestSizeLimitAttribute(MaxAvatarUploadRequestBodyBytes));", source);
    }

    [Fact]
    public void AvatarUploadValidation_ShouldRejectOversizedFileBeforeSniffingContent()
    {
        var source = ReadSource("AuthEndpoints.Profile.cs");
        var validationBody = ExtractMethodBody(
            source,
            "private static async Task<(Dictionary<string, string[]> Errors, string? DetectedContentType)> ValidateAvatarFileAsync");
        var tooLargeIndex = validationBody.IndexOf("users.avatar_file_too_large", StringComparison.Ordinal);
        var sniffIndex = validationBody.IndexOf("DetectAvatarContentTypeAsync(file, cancellationToken)", StringComparison.Ordinal);

        Assert.True(tooLargeIndex >= 0, "Expected avatar file size validation.");
        Assert.True(sniffIndex >= 0, "Expected avatar content sniffing.");
        Assert.True(tooLargeIndex < sniffIndex, "Oversized avatars must be rejected before opening the file stream.");
    }

    private static string ReadSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
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
