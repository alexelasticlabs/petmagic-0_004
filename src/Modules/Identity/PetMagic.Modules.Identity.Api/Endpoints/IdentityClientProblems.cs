using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Identity.Api.Endpoints;

internal static class IdentityClientProblems
{
    public static ProblemHttpResult InvalidSubject()
    {
        return TypedResults.Problem(
            title: "auth.invalid_subject",
            statusCode: StatusCodes.Status401Unauthorized,
            extensions: BuildProblemExtensions("auth.invalid_subject"));
    }

    public static ProblemHttpResult ExternalProviderInvalid()
    {
        return TypedResults.Problem(
            title: "auth.external_invalid",
            statusCode: StatusCodes.Status400BadRequest,
            extensions: BuildProblemExtensions("auth.external_invalid"));
    }

    public static ProblemHttpResult ToProblem(Error error, int fallbackStatusCode)
    {
        var statusCode = ResolveStatusCode(error.Code, fallbackStatusCode);
        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildProblemExtensions(error.Code));
    }

    private static int ResolveStatusCode(string errorCode, int fallbackStatusCode)
    {
        return errorCode switch
        {
            "users.not_found" => StatusCodes.Status404NotFound,
            "auth.email_not_confirmed" => StatusCodes.Status403Forbidden,
            "auth.invalid_subject" => StatusCodes.Status401Unauthorized,
            "auth.external_invalid" => StatusCodes.Status400BadRequest,
            "auth.invalid_refresh" => StatusCodes.Status401Unauthorized,
            "auth.refresh_token_not_owned" => StatusCodes.Status403Forbidden,
            "users.role_not_allowed" => StatusCodes.Status403Forbidden,
            "users.cannot_remove_last_admin" => StatusCodes.Status409Conflict,
            "users.bulk_email_idempotency_conflict" => StatusCodes.Status409Conflict,
            "users.bulk_email_broadcast_not_found" => StatusCodes.Status404NotFound,
            "users.session_not_found" => StatusCodes.Status404NotFound,
            "users.session_idempotency_conflict" => StatusCodes.Status409Conflict,
            "legal.catalog_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.insufficient_balance" => StatusCodes.Status409Conflict,
            "email.not_configured" or "email.dispatch_failed" or "users.avatar_storage_failed" => StatusCodes.Status503ServiceUnavailable,
            _ => fallbackStatusCode,
        };
    }

    internal static Dictionary<string, object?> BuildProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
