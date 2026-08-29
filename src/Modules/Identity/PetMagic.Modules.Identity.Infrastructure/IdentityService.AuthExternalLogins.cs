using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private static readonly TimeSpan RepeatedExternalLoginSessionWindow = TimeSpan.FromMinutes(30);

    public async Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
    {
        var provider = NormalizeExternalProvider(command.Provider);
        var providerUserId = command.ProviderSubject.Trim();
        if (string.IsNullOrWhiteSpace(provider) || string.IsNullOrWhiteSpace(providerUserId))
        {
            LogSocialAuthWarning("social_login_failed", command.Provider, null, "validation_failure");
            return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var now = DateTime.UtcNow;
        var providerAccount = await dbContext.ExternalAuthProviders
            .FirstOrDefaultAsync(x => x.Provider == provider && x.ProviderUserId == providerUserId, cancellationToken);
        if (providerAccount is null && await IsDeletedProviderBlockedAsync(provider, providerUserId, cancellationToken))
        {
            LogSocialAuthWarning("social_login_failed", provider, null, "deleted_account");
            return Result.Failure<TokenPairResponse>(IdentityErrors.AccountDeleted);
        }

        var user = providerAccount is null
            ? null
            : await userManager.FindByIdAsync(providerAccount.UserId.ToString());
        var isNewUser = false;

        if (providerAccount is not null && user is null)
        {
            LogSocialAuthWarning("social_login_failed", provider, null, "deleted_account");
            return Result.Failure<TokenPairResponse>(IdentityErrors.AccountDeleted);
        }

        if (user is null)
        {
            var normalizedEmail = NormalizeEmail(command.Email);
            if (string.IsNullOrWhiteSpace(normalizedEmail) || !command.EmailVerified)
            {
                LogSocialAuthWarning("social_login_failed", provider, null, "missing_or_unverified_email");
                return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalEmailMissing);
            }

            if (await IsDeletedEmailBlockedAsync(normalizedEmail, cancellationToken))
            {
                LogSocialAuthWarning("social_login_failed", provider, null, "deleted_account");
                return Result.Failure<TokenPairResponse>(IdentityErrors.AccountDeleted);
            }

            user = await userManager.FindByEmailAsync(normalizedEmail);

            if (user is null)
            {
                isNewUser = true;
                user = new AppUser
                {
                    Id = Guid.NewGuid(),
                    UserName = normalizedEmail,
                    Email = normalizedEmail,
                    EmailConfirmed = true,
                    DisplayName = command.DisplayName,
                    IsPremium = false,
                    IsActive = true,
                    CreatedAtUtc = now,
                    LastLoginAtUtc = now,
                    AccountStatus = AccountStatus.Active,
                    AccountStatusUpdatedAtUtc = now
                };

                var createResult = await userManager.CreateAsync(user);
                if (!createResult.Succeeded)
                {
                    LogSocialAuthWarning("social_login_failed", provider, null, "user_create_failed");
                    return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
                }

                await userManager.AddToRoleAsync(user, SystemRoles.User);
            }
            else if (command.EmailVerified)
            {
                user.EmailConfirmed = true;
                user.AccountStatus = AccountStatus.Active;
                user.AccountStatusUpdatedAtUtc = now;
            }

            providerAccount = new ExternalAuthProvider
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                Provider = provider,
                ProviderUserId = providerUserId,
                Email = normalizedEmail,
                CreatedAt = now,
                LastUsedAt = now
            };
            dbContext.ExternalAuthProviders.Add(providerAccount);
        }

        if (!user.IsActive)
        {
            LogSocialAuthWarning("social_login_failed", provider, user.Id, "inactive_account");
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (providerAccount is not null)
        {
            providerAccount.Email = NormalizeEmail(command.Email) ?? providerAccount.Email;
            providerAccount.LastUsedAt = now;
        }

        user.LastLoginAtUtc = now;

        var accountStatusNormalization = await NormalizeAccountStatusForAuthenticatedUserAsync(user, cancellationToken);
        if (accountStatusNormalization.IsFailure)
        {
            return Result.Failure<TokenPairResponse>(accountStatusNormalization.Error);
        }

        var roles = await userManager.GetRolesAsync(user);
        if (!roles.Contains(SystemRoles.User, StringComparer.Ordinal))
        {
            await userManager.AddToRoleAsync(user, SystemRoles.User);
            roles.Add(SystemRoles.User);
        }

        var revokedRecentSessionCount = await RevokeRecentExternalLoginSessionsAsync(
            user.Id,
            provider,
            now,
            cancellationToken);
        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken, provider);
        if (revokedRecentSessionCount > 0)
        {
            await WriteAuditAsync(
                user.Id,
                "auth.external_login.recent_sessions_revoked",
                $"Replaced {revokedRecentSessionCount} recent external-login session(s) from provider: {provider}.",
                cancellationToken);
        }
        await WriteAuditAsync(user.Id, "auth.external_login.succeeded", $"External provider: {provider}", cancellationToken);
        LogSocialAuthInformation("social_login_success", provider, user.Id, "succeeded", isNewUser);
        LogSocialAuthInformation(isNewUser ? "new_user_registered" : "existing_user_logged_in", provider, user.Id, "succeeded", isNewUser);

        return Result.Success(tokenPair);
    }

    private async Task<int> RevokeRecentExternalLoginSessionsAsync(
        Guid userId,
        string provider,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var cutoff = now.Subtract(RepeatedExternalLoginSessionWindow);
        var sessions = await dbContext.RefreshTokenSessions
            .Where(session =>
                session.UserId == userId &&
                session.AuthenticationProvider == provider &&
                session.RevokedAtUtc == null &&
                session.ExpiresAtUtc > now &&
                session.CreatedAtUtc >= cutoff)
            .ToListAsync(cancellationToken);

        foreach (var session in sessions)
        {
            session.RevokedAtUtc = now;
        }

        return sessions.Count;
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
        var provider = NormalizeExternalProvider(command.Provider);
        var providerUserId = command.ProviderSubject.Trim();
        if (string.IsNullOrWhiteSpace(provider) || string.IsNullOrWhiteSpace(providerUserId))
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

        var existingProvider = await dbContext.ExternalAuthProviders
            .FirstOrDefaultAsync(x => x.Provider == provider && x.ProviderUserId == providerUserId, cancellationToken);
        if (existingProvider is not null && existingProvider.UserId != user.Id)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalAlreadyLinked);
        }

        var providerLogins = await dbContext.ExternalAuthProviders
            .Where(x => x.UserId == user.Id && x.Provider == provider)
            .ToListAsync(cancellationToken);

        if (providerLogins.Count > 0)
        {
            if (providerLogins.Any(x => string.Equals(x.ProviderUserId, providerUserId, StringComparison.Ordinal)))
            {
                return Result.Success<IReadOnlyList<LinkedAccountResponse>>(await ListLinkedAccountsAsync(user));
            }

            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalProviderAlreadyLinked);
        }

        var now = DateTime.UtcNow;
        dbContext.ExternalAuthProviders.Add(new ExternalAuthProvider
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Provider = provider,
            ProviderUserId = providerUserId,
            Email = NormalizeEmail(command.Email),
            CreatedAt = now,
            LastUsedAt = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.external_link.succeeded", $"External provider linked: {provider}", cancellationToken);
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

        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return Result.Failure<IReadOnlyList<LinkedAccountResponse>>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var userLogins = await dbContext.ExternalAuthProviders
            .Where(x => x.UserId == user.Id)
            .ToListAsync(cancellationToken);
        var providerLogins = userLogins
            .Where(x => string.Equals(x.Provider, normalizedProvider, StringComparison.OrdinalIgnoreCase))
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

        dbContext.ExternalAuthProviders.RemoveRange(providerLogins);

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.external_link.removed", $"External provider unlinked: {normalizedProvider}", cancellationToken);
        return Result.Success<IReadOnlyList<LinkedAccountResponse>>(await ListLinkedAccountsAsync(user));
    }
}
