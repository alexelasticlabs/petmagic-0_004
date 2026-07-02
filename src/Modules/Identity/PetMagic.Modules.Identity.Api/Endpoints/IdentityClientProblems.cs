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
            detail: "Authentication failed.",
            statusCode: StatusCodes.Status401Unauthorized);
    }

    public static ProblemHttpResult ExternalProviderInvalid()
    {
        return TypedResults.Problem(
            title: "auth.external_invalid",
            detail: "External authentication request is invalid.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    public static ProblemHttpResult ToProblem(Error error, int fallbackStatusCode)
    {
        var statusCode = ResolveStatusCode(error.Code, fallbackStatusCode);
        return TypedResults.Problem(
            title: error.Code,
            detail: GetDetail(error.Code, statusCode),
            statusCode: statusCode);
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
            "legal.catalog_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.insufficient_balance" => StatusCodes.Status409Conflict,
            "email.not_configured" or "email.dispatch_failed" or "users.avatar_storage_failed" => StatusCodes.Status503ServiceUnavailable,
            _ => fallbackStatusCode,
        };
    }

    private static string GetDetail(string errorCode, int statusCode)
    {
        return errorCode switch
        {
            "auth.invalid_credentials" => "Sign-in credentials are invalid.",
            "auth.account_locked" => "Account is temporarily unavailable.",
            "auth.account_deleted" => "Account is unavailable.",
            "auth.user_exists" => "Account already exists.",
            "auth.email_not_confirmed" => "Email address is not confirmed.",
            "auth.invalid_subject" => "Authentication failed.",
            "auth.external_invalid" => "External authentication request is invalid.",
            "auth.email_code_invalid" => "Email verification code is invalid.",
            "auth.password_reset_code_invalid" => "Password reset code is invalid.",
            "auth.invalid_refresh" => "Session is invalid or expired.",
            "auth.refresh_token_not_owned" => "Session does not belong to the current user.",
            "users.not_found" => "Account was not found.",
            "users.role_not_allowed" => "Requested role change is not allowed.",
            "users.cannot_revoke_base_role" => "User role cannot be removed.",
            "users.cannot_remove_last_admin" => "At least one Admin must remain active.",
            "legal.catalog_unavailable" => "Current legal documents are temporarily unavailable.",
            "economy.insufficient_balance" => "Not enough balance to complete this action.",
            "users.avatar_invalid_upload" => "Avatar upload is invalid.",
            "users.avatar_content_type_not_allowed" => "Avatar content type is not allowed.",
            "users.avatar_file_too_large" => "Avatar file exceeds the maximum allowed size.",
            "users.avatar_storage_failed" => "Avatar upload is temporarily unavailable.",
            "email.not_configured" or "email.dispatch_failed" => "Email delivery is temporarily unavailable.",
            "legal.version_mismatch" => "Current legal document versions must be accepted.",
            "common.operation_failed" => "Identity operation could not be completed.",
            _ when statusCode == StatusCodes.Status404NotFound => "Requested account resource was not found.",
            _ when statusCode == StatusCodes.Status401Unauthorized => "Authentication failed.",
            _ when statusCode == StatusCodes.Status403Forbidden => "Operation is not allowed for this account.",
            _ when statusCode == StatusCodes.Status503ServiceUnavailable => "Identity service is temporarily unavailable.",
            _ when statusCode == StatusCodes.Status400BadRequest => "Identity request is invalid.",
            _ => "Identity operation failed.",
        };
    }
}
