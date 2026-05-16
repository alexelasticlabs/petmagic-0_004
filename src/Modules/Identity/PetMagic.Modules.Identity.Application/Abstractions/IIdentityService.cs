using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IIdentityService
{
    Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken);

    Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken);

    Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken);

    Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken);

    Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken);

    Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken);

    Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken);
}
