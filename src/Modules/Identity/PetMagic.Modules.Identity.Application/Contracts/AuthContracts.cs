namespace PetMagic.Modules.Identity.Application.Contracts;

public sealed record RegisterUserCommand(string Email, string Password, string? DisplayName);

public sealed record LoginCommand(string Email, string Password);

public sealed record RefreshTokenCommand(string RefreshToken);

public sealed record LogoutCommand(Guid UserId, string RefreshToken);

public sealed record ExternalLoginCallbackCommand(
    string Provider,
    string ProviderSubject,
    string? Email,
    string? DisplayName);

public sealed record TokenPairResponse(
    string AccessToken,
    string RefreshToken,
    DateTime ExpiresAtUtc,
    UserProfileResponse User);

public sealed record UserProfileResponse(
    Guid UserId,
    string Email,
    string? DisplayName,
    bool IsPremium,
    IReadOnlyList<string> Roles);

public sealed record UserListItemResponse(
    Guid UserId,
    string Email,
    string? DisplayName,
    bool IsPremium,
    bool IsActive,
    IReadOnlyList<string> Roles,
    DateTime CreatedAtUtc);

public sealed record AssignRoleCommand(Guid UserId, string Role);

public sealed record RevokeRoleCommand(Guid UserId, string Role);

public sealed record SetPremiumStatusCommand(Guid UserId, bool IsPremium);

public sealed record SetUserActiveStatusCommand(Guid UserId, bool IsActive);
