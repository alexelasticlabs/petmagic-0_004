using System.IO;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AuthExternalEndpointSecurityTests
{
    [Fact]
    public void AuthExternalEndpoints_ShouldNotExposeRawExternalErrorMessagesInRedirectsOrProblems()
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
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AuthEndpoints.External.cs"));

        Assert.Contains("return ToExternalAuthProblem(verification.Error.Code, statusCode);", source);
        Assert.Contains("return ToExternalAuthProblem(result.Error.Code, StatusCodes.Status401Unauthorized);", source);
        Assert.Contains("return ToExternalAuthProblem(\"auth.external_invalid\", StatusCodes.Status400BadRequest);", source);
        Assert.Contains("return ToExternalAuthProblem(\"auth.external_not_configured\", StatusCodes.Status404NotFound);", source);
        Assert.Contains("return ToExternalAuthProblem(ExternalTicketInvalidCode, StatusCodes.Status401Unauthorized);", source);
        Assert.Contains("[\"error\"] = errorCode", source);
        Assert.DoesNotContain("Results.BadRequest(new { message =", source);
        Assert.DoesNotContain("Unsupported provider.", source);
        Assert.DoesNotContain("Unsupported redirect URI.", source);
        Assert.DoesNotContain("Google sign-in is not configured.", source);
        Assert.DoesNotContain("linkedResult.Error.Message", source);
        Assert.DoesNotContain("result.Error.Message", source);
        Assert.DoesNotContain("BuildExternalCallbackErrorResult(\r\n                    clientRedirectUri,\r\n                    ExternalTicketInvalidCode,\r\n                    ExternalTicketInvalidMessage,", source);
        Assert.DoesNotContain("BuildExternalCallbackErrorResult(\r\n                    clientRedirectUri,\r\n                    ExternalCancelledCode,\r\n                    ExternalCancelledMessage,", source);
        Assert.DoesNotContain("[\"message\"] = errorMessage", source);
        Assert.DoesNotContain("detail: verification.Error.Message", source);
        Assert.DoesNotContain("detail: result.Error.Message", source);
        Assert.DoesNotContain("TypedResults.Problem(title: errorCode, detail: errorMessage, statusCode: statusCode);", source);
        Assert.DoesNotContain("title: ExternalTicketInvalidCode,", source);
        Assert.DoesNotContain("detail: ExternalTicketInvalidMessage,", source);
    }
}
