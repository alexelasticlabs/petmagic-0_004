using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityService(
    UserManager<AppUser> userManager,
    RoleManager<IdentityRole<Guid>> roleManager,
    IdentityDbContext dbContext,
    IServiceProvider serviceProvider,
    ILegalDocumentsCatalog legalDocumentsCatalog,
    IIdentityEmailTemplateRenderer emailTemplateRenderer,
    IAvatarStorage avatarStorage,
    EmailOptions emailOptions,
    AvatarStorageOptions avatarStorageOptions,
    IOptions<JwtOptions> jwtOptions) : IIdentityService
{
    public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(legalDocumentsCatalog.GetCurrentDocuments(locale)));
    }

    public async Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var normalizedEmail = email.ToUpperInvariant();
        var existing = await userManager.Users
            .AnyAsync(x => x.NormalizedEmail == normalizedEmail, cancellationToken);

        if (existing)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            UserName = email,
            Email = email,
            EmailConfirmed = true,
            DisplayName = command.DisplayName,
            TermsOfUseAccepted = command.TermsOfUseAccepted,
            TermsOfUseAcceptedAtUtc = command.TermsOfUseAccepted ? now : null,
            TermsOfUseAcceptedVersion = command.TermsOfUseAccepted ? command.TermsOfUseVersion : null,
            PrivacyPolicyAccepted = command.PrivacyPolicyAccepted,
            PrivacyPolicyAcceptedAtUtc = command.PrivacyPolicyAccepted ? now : null,
            PrivacyPolicyAcceptedVersion = command.PrivacyPolicyAccepted ? command.PrivacyPolicyVersion : null,
            MarketingEmailsEnabled = command.MarketingEmailsEnabled,
            MarketingEmailsUpdatedAtUtc = now,
            IsPremium = false,
            IsActive = true,
            CreatedAtUtc = now
        };

        var createResult = await userManager.CreateAsync(user, command.Password);
        if (!createResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        var addRoleResult = await userManager.AddToRoleAsync(user, SystemRoles.User);
        if (!addRoleResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.registered", "User self-registration completed.", cancellationToken);

        return Result.Success(ToUserProfileResponse(user, [SystemRoles.User]));
    }

    public async Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        var validPassword = await userManager.CheckPasswordAsync(user, command.Password);
        if (!validPassword)
        {
            await WriteAuditAsync(user.Id, "auth.login.failed", "Invalid password.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (!user.EmailConfirmed)
        {
            await WriteAuditAsync(user.Id, "auth.login.denied", "Login denied: email is not confirmed.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.EmailNotConfirmed);
        }

        var roles = await userManager.GetRolesAsync(user);
        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.login.succeeded", "User logged in.", cancellationToken);

        return Result.Success(tokenPair);
    }

    public async Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive || user.EmailConfirmed)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        var lastActiveCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id
                && x.Purpose == EmailCodePurpose.EmailConfirmation
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (lastActiveCode?.LastSentAtUtc is not null
            && lastActiveCode.LastSentAtUtc > now.AddSeconds(-emailOptions.ConfirmationResendCooldownSeconds))
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.EmailConfirmation, cancellationToken);
        await WriteAuditAsync(user.Id, "user.email_confirmation.requested", "Email confirmation code requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure(IdentityErrors.EmailCodeInvalid);
        }

        if (user.EmailConfirmed)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        var codeEntity = await FindMatchingCodeAsync(user.Id, EmailCodePurpose.EmailConfirmation, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            return Result.Failure(IdentityErrors.EmailCodeInvalid);
        }

        codeEntity.ConsumedAtUtc = now;
        user.EmailConfirmed = true;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "user.email_confirmed", "Email address confirmed.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive || string.IsNullOrWhiteSpace(user.Email) || string.IsNullOrWhiteSpace(user.PasswordHash))
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.PasswordReset, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_reset.requested", "Password reset requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure(IdentityErrors.PasswordResetCodeInvalid);
        }

        var now = DateTime.UtcNow;
        var codeEntity = await FindMatchingCodeAsync(user.Id, EmailCodePurpose.PasswordReset, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            return Result.Failure(IdentityErrors.PasswordResetCodeInvalid);
        }

        user.PasswordHash = userManager.PasswordHasher.HashPassword(user, command.NewPassword);
        user.SecurityStamp = Guid.NewGuid().ToString("N");

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        codeEntity.ConsumedAtUtc = now;
        await RevokeRefreshTokensAsync(user.Id, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_reset.succeeded", "Password reset completed.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Provider) || string.IsNullOrWhiteSpace(command.ProviderSubject))
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var user = await userManager.FindByLoginAsync(command.Provider, command.ProviderSubject);

        if (user is null)
        {
            if (string.IsNullOrWhiteSpace(command.Email))
            {
                return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalEmailMissing);
            }

            user = await userManager.FindByEmailAsync(command.Email);

            if (user is null)
            {
                user = new AppUser
                {
                    Id = Guid.NewGuid(),
                    UserName = command.Email,
                    Email = command.Email,
                    EmailConfirmed = true,
                    DisplayName = command.DisplayName,
                    IsPremium = false,
                    IsActive = true,
                    CreatedAtUtc = DateTime.UtcNow
                };

                var createResult = await userManager.CreateAsync(user);
                if (!createResult.Succeeded)
                {
                    return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
                }

                await userManager.AddToRoleAsync(user, SystemRoles.User);
            }

            var addLoginResult = await userManager.AddLoginAsync(user, new UserLoginInfo(command.Provider, command.ProviderSubject, command.Provider));
            if (!addLoginResult.Succeeded)
            {
                return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
            }
        }

        if (!user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        var roles = await userManager.GetRolesAsync(user);
        if (!roles.Contains(SystemRoles.User, StringComparer.Ordinal))
        {
            await userManager.AddToRoleAsync(user, SystemRoles.User);
            roles.Add(SystemRoles.User);
        }

        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.external_login.succeeded", $"External provider: {command.Provider}", cancellationToken);

        return Result.Success(tokenPair);
    }

    public async Task<Result<IReadOnlyList<LinkedAccountResponse>>> GetLinkedAccountsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.UserNotFound);
        }

        return Result.Success(await ListLinkedAccountsAsync(user));
    }

    public async Task<Result<IReadOnlyList<LinkedAccountResponse>>> LinkExternalLoginAsync(Guid userId, ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Provider) || string.IsNullOrWhiteSpace(command.ProviderSubject))
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.UserNotFound);
        }

        if (!user.IsActive)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.InvalidCredentials);
        }

        var existingOwner = await userManager.FindByLoginAsync(command.Provider, command.ProviderSubject);
        if (existingOwner is not null && existingOwner.Id != user.Id)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalAlreadyLinked);
        }

        var userLogins = await userManager.GetLoginsAsync(user);
        var providerLogins = userLogins
            .Where(x => string.Equals(x.LoginProvider, command.Provider, StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (providerLogins.Count > 0)
        {
            if (providerLogins.Any(x => string.Equals(x.ProviderKey, command.ProviderSubject, StringComparison.Ordinal)))
            {
                return Result.Success<IReadOnlyList<LinkedAccountResponse>>(await ListLinkedAccountsAsync(user));
            }

            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalProviderAlreadyLinked);
        }

        var addLoginResult = await userManager.AddLoginAsync(
            user,
            new UserLoginInfo(command.Provider, command.ProviderSubject, command.Provider));
        if (!addLoginResult.Succeeded)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "auth.external_link.succeeded", $"External provider linked: {command.Provider}", cancellationToken);
        return Result.Success<IReadOnlyList<LinkedAccountResponse>>(await ListLinkedAccountsAsync(user));
    }

    public async Task<Result<IReadOnlyList<LinkedAccountResponse>>> UnlinkExternalLoginAsync(Guid userId, string provider, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(provider))
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.UserNotFound);
        }

        var userLogins = await userManager.GetLoginsAsync(user);
        var providerLogins = userLogins
            .Where(x => string.Equals(x.LoginProvider, provider, StringComparison.OrdinalIgnoreCase))
            .ToList();
        if (providerLogins.Count == 0)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalProviderNotLinked);
        }

        var hasPassword = !string.IsNullOrWhiteSpace(user.PasswordHash);
        if (!hasPassword && userLogins.Count <= providerLogins.Count)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalLastSignInMethod);
        }

        foreach (var login in providerLogins)
        {
            var removeLoginResult = await userManager.RemoveLoginAsync(user, login.LoginProvider, login.ProviderKey);
            if (!removeLoginResult.Succeeded)
            {
                return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.OperationFailed);
            }
        }

        await WriteAuditAsync(user.Id, "auth.external_link.removed", $"External provider unlinked: {provider}", cancellationToken);
        return Result.Success<IReadOnlyList<LinkedAccountResponse>>(await ListLinkedAccountsAsync(user));
    }

    public async Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        var hash = HashToken(command.RefreshToken);
        var session = await dbContext.RefreshTokenSessions
            .Where(x => x.TokenHash == hash)
            .FirstOrDefaultAsync(cancellationToken);

        if (session is null)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        if (session.RevokedAtUtc is not null)
        {
            await WriteAuditAsync(session.UserId, "auth.refresh.reuse_detected", "Detected refresh token reuse attempt.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        if (session.ExpiresAtUtc <= DateTime.UtcNow)
        {
            await WriteAuditAsync(session.UserId, "auth.refresh.expired", "Refresh attempt with expired token.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        var user = await userManager.FindByIdAsync(session.UserId.ToString());
        if (user is null || !user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        session.RevokedAtUtc = DateTime.UtcNow;
        var roles = await userManager.GetRolesAsync(user);
        var pair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.refresh.succeeded", "Refresh token rotated.", cancellationToken);

        return Result.Success(pair);
    }

    public async Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken)
    {
        var hash = HashToken(command.RefreshToken);
        var session = await dbContext.RefreshTokenSessions
            .Where(x => x.TokenHash == hash)
            .FirstOrDefaultAsync(cancellationToken);

        if (session is null)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "Logout requested for non-existing refresh token.", cancellationToken);
            return Result.Success();
        }

        if (session.UserId != command.UserId)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.denied", "Logout denied: refresh token belongs to a different user.", cancellationToken);
            return Result.Failure(IdentityErrors.RefreshTokenOwnershipViolation);
        }

        if (session.RevokedAtUtc is not null)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "Logout requested for already revoked refresh token.", cancellationToken);
            return Result.Success();
        }

        session.RevokedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "User logged out and refresh token revoked.", cancellationToken);

        return Result.Success();
    }

    public async Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var avatarUrl = user.AvatarUrl;
        var deleteUserResult = await userManager.DeleteAsync(user);
        if (!deleteUserResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        var refreshSessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == command.UserId)
            .ToListAsync(cancellationToken);

        var emailCodes = await dbContext.UserEmailCodes
            .Where(x => x.UserId == command.UserId)
            .ToListAsync(cancellationToken);

        var emailJobs = await dbContext.EmailDispatchJobs
            .Where(x => x.UserId == command.UserId)
            .ToListAsync(cancellationToken);

        if (refreshSessions.Count > 0)
        {
            dbContext.RefreshTokenSessions.RemoveRange(refreshSessions);
        }

        if (emailCodes.Count > 0)
        {
            dbContext.UserEmailCodes.RemoveRange(emailCodes);
        }

        if (emailJobs.Count > 0)
        {
            dbContext.EmailDispatchJobs.RemoveRange(emailJobs);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await avatarStorage.DeleteAsync(avatarUrl, CancellationToken.None);
        await WriteAuditAsync(command.UserId, "user.deleted", "User account deleted by owner.", cancellationToken);

        return Result.Success();
    }

    public async Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken)
    {
        if (!legalDocumentsCatalog.MatchesCurrentVersions(command.TermsOfUseVersion, command.PrivacyPolicyVersion))
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.LegalDocumentVersionMismatch);
        }

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var now = DateTime.UtcNow;
        user.TermsOfUseAccepted = true;
        user.TermsOfUseAcceptedAtUtc = now;
        user.TermsOfUseAcceptedVersion = command.TermsOfUseVersion;
        user.PrivacyPolicyAccepted = true;
        user.PrivacyPolicyAcceptedAtUtc = now;
        user.PrivacyPolicyAcceptedVersion = command.PrivacyPolicyVersion;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.legal_documents.accepted", $"Accepted terms {command.TermsOfUseVersion} and privacy {command.PrivacyPolicyVersion}.", cancellationToken);

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken)
    {
        if (command.Content.Length == 0)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.InvalidAvatarUpload);
        }

        if (!command.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.AvatarContentTypeNotAllowed);
        }

        if (command.Content.LongLength > avatarStorageOptions.MaxFileSizeBytes)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.AvatarFileTooLarge);
        }

        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var previousAvatarUrl = user.AvatarUrl;
        var storeResult = await avatarStorage.StoreAsync(
            new AvatarUploadCommand(command.FileName, command.ContentType, command.Content),
            cancellationToken);
        if (storeResult.IsFailure)
        {
            return Result.Failure<UserProfileResponse>(storeResult.Error);
        }

        user.AvatarUrl = storeResult.Value.Url;
        user.AvatarFileName = storeResult.Value.FileName;
        user.AvatarContentType = storeResult.Value.ContentType;
        user.AvatarFileSizeBytes = storeResult.Value.FileSizeBytes;
        user.AvatarUpdatedAtUtc = DateTime.UtcNow;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            await avatarStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        if (!string.IsNullOrWhiteSpace(previousAvatarUrl)
            && !string.Equals(previousAvatarUrl, storeResult.Value.Url, StringComparison.OrdinalIgnoreCase))
        {
            await avatarStorage.DeleteAsync(previousAvatarUrl, CancellationToken.None);
        }

        await WriteAuditAsync(user.Id, "user.avatar.updated", "User avatar uploaded or replaced.", cancellationToken);
        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var previousAvatarUrl = user.AvatarUrl;
        user.AvatarUrl = null;
        user.AvatarFileName = null;
        user.AvatarContentType = null;
        user.AvatarFileSizeBytes = null;
        user.AvatarUpdatedAtUtc = null;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await avatarStorage.DeleteAsync(previousAvatarUrl, CancellationToken.None);
        await WriteAuditAsync(user.Id, "user.avatar.removed", "User avatar removed.", cancellationToken);
        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken)
    {
        var users = await userManager.Users
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        if (users.Count == 0)
        {
            return Result.Success<IReadOnlyList<UserListItemResponse>>([]);
        }

        var userIds = users.Select(x => x.Id).ToArray();
        var rolesByUserId = await dbContext.UserRoles
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId))
            .Join(
                dbContext.Roles.AsNoTracking(),
                userRole => userRole.RoleId,
                role => role.Id,
                (userRole, role) => new
                {
                    userRole.UserId,
                    RoleName = role.Name ?? string.Empty
                })
            .GroupBy(x => x.UserId)
            .ToDictionaryAsync(
                group => group.Key,
                group => (IReadOnlyList<string>)[.. group
                    .Select(x => x.RoleName)
                    .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)],
                cancellationToken);

        var output = users
            .Select(user => new UserListItemResponse(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                user.IsPremium,
                user.IsActive,
                user.EmailConfirmed,
                user.TermsOfUseAccepted,
                user.PrivacyPolicyAccepted,
                user.MarketingEmailsEnabled,
                ToLegalAcceptanceResponse(user),
                rolesByUserId.GetValueOrDefault(user.Id) ?? [],
                user.CreatedAtUtc,
                ToAvatarResponse(user)))
            .ToArray();

        return Result.Success<IReadOnlyList<UserListItemResponse>>(output);
    }

    public async Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<AdminUserDetailResponse>(IdentityErrors.UserNotFound);
        }

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToAdminUserDetailResponse(user, roles));
    }

    public async Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var economyAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserEconomyAnalyticsReader>();
        var templateAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserTemplateAnalyticsReader>();
        var analyticsService = new IdentityAdminUserAnalyticsService(
            userManager,
            dbContext,
            economyAnalyticsReader,
            templateAnalyticsReader);

        return await analyticsService.GetAdminUserAnalyticsAsync(userId, cancellationToken);
    }

    public async Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<AdminUserWalletOperationResponse>(IdentityErrors.UserNotFound);
        }

        var economyService = serviceProvider.GetRequiredService<IEconomyService>();
        var normalizedOperation = command.Operation.Trim().ToLowerInvariant();
        var reason = command.Reason.Trim();
        var operationResult = normalizedOperation switch
        {
            "credit" => await economyService.CreditAsync(
                new CreditBalanceCommand(command.UserId, command.Amount, WalletLedgerSource.AdminGrant, reason),
                cancellationToken),
            "debit" => await economyService.SpendAsync(
                new SpendBalanceCommand(command.UserId, command.Amount, reason, WalletLedgerSource.AdminDebit),
                cancellationToken),
            _ => Result.Failure<WalletOperationResponse>(IdentityErrors.OperationFailed)
        };

        if (operationResult.IsFailure)
        {
            return Result.Failure<AdminUserWalletOperationResponse>(operationResult.Error);
        }

        var source = normalizedOperation == "credit" ? WalletLedgerSource.AdminGrant : WalletLedgerSource.AdminDebit;

        await WriteAuditAsync(
            command.UserId,
            normalizedOperation == "credit" ? "admin.user.wallet.credited" : "admin.user.wallet.debited",
            $"{command.Amount} tokens. Reason: {reason}",
            cancellationToken);

        return Result.Success(new AdminUserWalletOperationResponse(
            command.UserId,
            normalizedOperation,
            normalizedOperation == "credit" ? command.Amount : -command.Amount,
            operationResult.Value.NewBalance,
            source,
            reason,
            operationResult.Value.OccurredAtUtc));
    }

    public async Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken)
    {
        var query = userManager.Users
            .Where(x => x.IsActive && x.EmailConfirmed && !string.IsNullOrWhiteSpace(x.Email));

        if (string.Equals(command.Audience, EmailAudiences.Premium, StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(x => x.IsPremium);
        }
        else if (string.Equals(command.Audience, EmailAudiences.Selected, StringComparison.OrdinalIgnoreCase))
        {
            var selectedIds = command.UserIds?
                .Where(id => id != Guid.Empty)
                .Distinct()
                .ToArray() ?? [];

            query = query.Where(x => selectedIds.Contains(x.Id));
        }

        var recipients = await query
            .Select(x => new { x.Id, x.Email })
            .ToListAsync(cancellationToken);

        if (recipients.Count == 0)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        foreach (var recipient in recipients)
        {
            dbContext.EmailDispatchJobs.Add(CreateBroadcastEmailJob(recipient.Id, recipient.Email!, command.Subject, command.Body, now));
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(null, "admin.bulk_email.queued", $"Bulk email queued for {recipients.Count} recipients.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        if (!await roleManager.RoleExistsAsync(command.Role))
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        var addResult = await userManager.AddToRoleAsync(user, command.Role);
        if (!addResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.assigned", $"Assigned role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        if (string.Equals(command.Role, SystemRoles.User, StringComparison.Ordinal))
        {
            return Result.Failure(IdentityErrors.CannotRevokeBaseRole);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (!currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        var removeResult = await userManager.RemoveFromRoleAsync(user, command.Role);
        if (!removeResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.revoked", $"Revoked role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsPremium = command.IsPremium;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.premium.updated", $"Premium status changed to '{command.IsPremium}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsActive = command.IsActive;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.active.updated", $"Active status changed to '{command.IsActive}'.", cancellationToken);
        return Result.Success();
    }

    private async Task<TokenPairResponse> IssueTokenPairAsync(AppUser user, IEnumerable<string> roles, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(jwtOptions.Value.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new("premium", user.IsPremium ? "true" : "false")
        };
        claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Value.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var jwt = new JwtSecurityToken(
            issuer: jwtOptions.Value.Issuer,
            audience: jwtOptions.Value.Audience,
            claims: claims,
            notBefore: now,
            expires: expiresAt,
            signingCredentials: credentials);

        var accessToken = new JwtSecurityTokenHandler().WriteToken(jwt);
        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

        dbContext.RefreshTokenSessions.Add(new RefreshTokenSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = HashToken(refreshToken),
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(jwtOptions.Value.RefreshTokenDays)
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return new TokenPairResponse(
            accessToken,
            refreshToken,
            expiresAt,
            ToUserProfileResponse(user, roles));
    }

    private async Task WriteAuditAsync(Guid? subjectUserId, string action, string details, CancellationToken cancellationToken)
    {
        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = subjectUserId,
            Action = action,
            Details = details,
            OccurredAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task QueueEmailCodeAsync(AppUser user, EmailCodePurpose purpose, CancellationToken cancellationToken)
    {
        var email = user.Email?.Trim();
        if (string.IsNullOrWhiteSpace(email))
        {
            return;
        }

        var now = DateTime.UtcNow;
        await InvalidateActiveCodesAsync(user.Id, purpose, now, cancellationToken);

        var code = CreateVerificationCode(emailOptions.VerificationCodeLength);
        var ttlMinutes = purpose == EmailCodePurpose.EmailConfirmation
            ? emailOptions.VerificationCodeTtlMinutes
            : emailOptions.PasswordResetCodeTtlMinutes;
        var expiresAtUtc = now.AddMinutes(ttlMinutes);

        dbContext.UserEmailCodes.Add(new UserEmailCode
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Email = email,
            Purpose = purpose,
            CodeHash = HashToken(code),
            RequestedAtUtc = now,
            ExpiresAtUtc = expiresAtUtc,
            LastSentAtUtc = now,
            SendCount = 1
        });

        var message = purpose == EmailCodePurpose.EmailConfirmation
            ? emailTemplateRenderer.RenderEmailConfirmation(user.DisplayName, code, expiresAtUtc)
            : emailTemplateRenderer.RenderPasswordReset(user.DisplayName, code, expiresAtUtc);

        dbContext.EmailDispatchJobs.Add(new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RecipientEmail = email,
            Kind = purpose == EmailCodePurpose.EmailConfirmation
                ? EmailDispatchKind.EmailConfirmation
                : EmailDispatchKind.PasswordReset,
            Status = EmailDispatchStatus.Queued,
            Subject = message.Subject,
            HtmlBody = message.HtmlBody,
            TextBody = message.TextBody,
            AttemptCount = 0,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            NextAttemptAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task InvalidateActiveCodesAsync(Guid userId, EmailCodePurpose purpose, DateTime now, CancellationToken cancellationToken)
    {
        var activeCodes = await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId
                && x.Purpose == purpose
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now)
            .ToListAsync(cancellationToken);

        foreach (var activeCode in activeCodes)
        {
            activeCode.ConsumedAtUtc = now;
        }
    }

    private async Task<UserEmailCode?> FindMatchingCodeAsync(
        Guid userId,
        EmailCodePurpose purpose,
        string code,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var codeHash = HashToken(code.Trim());
        return await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId
                && x.Purpose == purpose
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now
                && x.CodeHash == codeHash)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task RevokeRefreshTokensAsync(Guid userId, DateTime revokedAtUtc, CancellationToken cancellationToken)
    {
        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == userId && x.RevokedAtUtc == null)
            .ToListAsync(cancellationToken);

        foreach (var session in sessions)
        {
            session.RevokedAtUtc = revokedAtUtc;
        }
    }

    private static string CreateVerificationCode(int length)
    {
        var size = Math.Clamp(length, 6, 12);
        var chars = new char[size];
        for (var index = 0; index < size; index++)
        {
            chars[index] = (char)('0' + RandomNumberGenerator.GetInt32(0, 10));
        }

        return new string(chars);
    }

    private static EmailDispatchJob CreateBroadcastEmailJob(Guid userId, string recipientEmail, string subject, string body, DateTime now)
    {
        return new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            RecipientEmail = recipientEmail,
            Kind = EmailDispatchKind.Broadcast,
            Status = EmailDispatchStatus.Queued,
            Subject = subject.Trim(),
            HtmlBody = $"<p>{WebUtility.HtmlEncode(body).Replace("\n", "<br/>", StringComparison.Ordinal)}</p>",
            TextBody = body,
            AttemptCount = 0,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            NextAttemptAtUtc = now
        };
    }

    private static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes);
    }

    private static UserAvatarResponse? ToAvatarResponse(AppUser user)
    {
        if (string.IsNullOrWhiteSpace(user.AvatarUrl)
            || string.IsNullOrWhiteSpace(user.AvatarFileName)
            || string.IsNullOrWhiteSpace(user.AvatarContentType))
        {
            return null;
        }

        return new UserAvatarResponse(
            user.AvatarUrl,
            user.AvatarFileName,
            user.AvatarContentType,
            user.AvatarFileSizeBytes,
            user.AvatarUpdatedAtUtc);
    }

    private LegalAcceptanceStatusResponse ToLegalAcceptanceResponse(AppUser user)
    {
        var currentTermsVersion = legalDocumentsCatalog.CurrentTermsOfUseVersion;
        var currentPrivacyVersion = legalDocumentsCatalog.CurrentPrivacyPolicyVersion;
        var requiresAcceptance = !user.TermsOfUseAccepted
            || !user.PrivacyPolicyAccepted
            || !string.Equals(user.TermsOfUseAcceptedVersion, currentTermsVersion, StringComparison.Ordinal)
            || !string.Equals(user.PrivacyPolicyAcceptedVersion, currentPrivacyVersion, StringComparison.Ordinal);

        return new LegalAcceptanceStatusResponse(
            user.TermsOfUseAccepted,
            user.TermsOfUseAcceptedVersion,
            user.TermsOfUseAcceptedAtUtc,
            user.PrivacyPolicyAccepted,
            user.PrivacyPolicyAcceptedVersion,
            user.PrivacyPolicyAcceptedAtUtc,
            currentTermsVersion,
            currentPrivacyVersion,
            requiresAcceptance);
    }

    private AdminUserDetailResponse ToAdminUserDetailResponse(AppUser user, IEnumerable<string> roles) =>
        new(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.IsPremium,
            user.IsActive,
            user.EmailConfirmed,
            user.TermsOfUseAccepted,
            user.PrivacyPolicyAccepted,
            user.MarketingEmailsEnabled,
            ToLegalAcceptanceResponse(user),
            [.. roles],
            user.CreatedAtUtc,
            ToAvatarResponse(user));

    private async Task<IReadOnlyList<LinkedAccountResponse>> ListLinkedAccountsAsync(AppUser user)
    {
        var userLogins = await userManager.GetLoginsAsync(user);

        return [.. userLogins
            .GroupBy(x => x.LoginProvider, StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .Select(group => new LinkedAccountResponse(
                group.First().LoginProvider,
                ToLinkedAccountDisplayName(group.First().ProviderDisplayName ?? group.First().LoginProvider),
                CanDisconnectLinkedProvider(user, userLogins, group.Count())))];
    }

    private static bool CanDisconnectLinkedProvider(AppUser user, IEnumerable<UserLoginInfo> allLogins, int providerLoginCount)
    {
        if (!string.IsNullOrWhiteSpace(user.PasswordHash))
        {
            return true;
        }

        return allLogins.Count() > providerLoginCount;
    }

    private static string ToLinkedAccountDisplayName(string provider)
    {
        if (string.Equals(provider, "Google", StringComparison.OrdinalIgnoreCase))
        {
            return "Google";
        }

        if (string.Equals(provider, "Apple", StringComparison.OrdinalIgnoreCase))
        {
            return "Apple";
        }

        return provider;
    }

    private UserProfileResponse ToUserProfileResponse(AppUser user, IEnumerable<string> roles) =>
        new(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.IsPremium,
            user.EmailConfirmed,
            user.TermsOfUseAccepted,
            user.PrivacyPolicyAccepted,
            user.MarketingEmailsEnabled,
            ToLegalAcceptanceResponse(user),
            [.. roles],
            ToAvatarResponse(user));
}
