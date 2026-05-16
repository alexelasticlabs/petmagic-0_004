using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Identity.Infrastructure;

public static class IdentityErrors
{
    public static readonly Error InvalidCredentials = new("auth.invalid_credentials", "Invalid credentials.");

    public static readonly Error InvalidSubject = new("auth.invalid_subject", "Invalid access token subject.");

    public static readonly Error UserAlreadyExists = new("auth.user_exists", "A user with this email already exists.");

    public static readonly Error InvalidRefreshToken = new("auth.invalid_refresh", "Refresh token is invalid or expired.");

    public static readonly Error ExternalPrincipalInvalid = new("auth.external_invalid", "External login payload is invalid.");

    public static readonly Error ExternalEmailMissing = new("auth.external_email_missing", "External provider did not supply an email.");

    public static readonly Error UserNotFound = new("users.not_found", "User not found.");

    public static readonly Error RoleNotAllowed = new("users.role_not_allowed", "Only Admin can assign Admin or Moderator roles.");

    public static readonly Error CannotRevokeBaseRole = new("users.cannot_revoke_base_role", "User role cannot be removed.");

    public static readonly Error RefreshTokenOwnershipViolation = new("auth.refresh_token_not_owned", "Refresh token does not belong to current user.");

    public static readonly Error OperationFailed = new("common.operation_failed", "Operation failed.");
}
