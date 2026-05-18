using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IIdentityService
{
    Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken);

    Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken);

    Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken);

    Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken);

    Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken);

    Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken);

    Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken);

    Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken);

    Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken);

    Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken);

    Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken);

    Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken);

    Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken);

    Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken);

    Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken);
}
