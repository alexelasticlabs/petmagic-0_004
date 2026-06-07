using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;
namespace PetMagic.Modules.Identity.Infrastructure;
public sealed partial class IdentityService
{
    private const int PasswordLockoutThreshold = 8;
    private const int PasswordLockoutBaseMinutes = 15;
    private const int PasswordLockoutMaxHours = 24;

    public async Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var normalizedEmail = email.ToUpperInvariant();
        if (await IsDeletedEmailBlockedAsync(email, cancellationToken))
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.AccountDeleted);
        }

        var existing = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == normalizedEmail, cancellationToken);

        var now = DateTime.UtcNow;
        AppUser user;
        if (existing is not null)
        {
            if (existing.EmailConfirmed || existing.AccountStatus == AccountStatus.Active)
            {
                return Result.Failure<UserProfileResponse>(IdentityErrors.UserAlreadyExists);
            }

            existing.DisplayName = command.DisplayName;
            existing.TermsOfUseAccepted = command.TermsOfUseAccepted;
            existing.TermsOfUseAcceptedAtUtc = command.TermsOfUseAccepted ? now : null;
            existing.TermsOfUseAcceptedVersion = command.TermsOfUseAccepted ? command.TermsOfUseVersion : null;
            existing.PrivacyPolicyAccepted = command.PrivacyPolicyAccepted;
            existing.PrivacyPolicyAcceptedAtUtc = command.PrivacyPolicyAccepted ? now : null;
            existing.PrivacyPolicyAcceptedVersion = command.PrivacyPolicyAccepted ? command.PrivacyPolicyVersion : null;
            existing.MarketingEmailsEnabled = command.MarketingEmailsEnabled;
            existing.MarketingEmailsUpdatedAtUtc = now;
            existing.IsActive = true;
            existing.EmailConfirmed = false;
            existing.AccountStatus = AccountStatus.PendingEmailVerification;
            existing.AccountStatusUpdatedAtUtc = now;
            existing.PasswordHash = userManager.PasswordHasher.HashPassword(existing, command.Password);
            existing.SecurityStamp = Guid.NewGuid().ToString("N");

            var updateExistingResult = await userManager.UpdateAsync(existing);
            if (!updateExistingResult.Succeeded)
            {
                return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
            }

            user = existing;
            await QueueEmailCodeAsync(user, EmailCodePurpose.EmailConfirmation, cancellationToken);
            await WriteAuditAsync(user.Id, "user.registered.pending.reissue", "Pending registration reissued verification code.", cancellationToken);
            LogAuthInformation("registration", user.Id, "pending_reissued");
            var existingRoles = await userManager.GetRolesAsync(user);
            return Result.Success(ToUserProfileResponse(user, existingRoles.Count == 0 ? [SystemRoles.User] : existingRoles));
        }

        user = new AppUser
        {
            Id = Guid.NewGuid(),
            UserName = email,
            Email = email,
            EmailConfirmed = false,
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
            LockoutEnabled = true,
            CreatedAtUtc = now,
            AccountStatus = AccountStatus.PendingEmailVerification,
            AccountStatusUpdatedAtUtc = now
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

        await QueueEmailCodeAsync(user, EmailCodePurpose.EmailConfirmation, cancellationToken);
        await WriteAuditAsync(user.Id, "user.registered.pending", "User self-registration completed and email verification required.", cancellationToken);
        LogAuthInformation("registration", user.Id, "pending_email_verification");

        return Result.Success(ToUserProfileResponse(user, [SystemRoles.User]));
    }

    public Task<Result> VerifyEmailCodeAsync(VerifyEmailCodeCommand command, CancellationToken cancellationToken)
    {
        return ConfirmEmailAsync(new ConfirmEmailCommand(command.Email, command.Code), cancellationToken);
    }

    public Task<Result> ResendEmailVerificationCodeAsync(ResendEmailVerificationCodeCommand command, CancellationToken cancellationToken)
    {
        return RequestEmailConfirmationAsync(new RequestEmailConfirmationCommand(command.Email), cancellationToken);
    }

    public async Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null)
        {
            LogAuthWarning("login", null, "invalid_credentials");
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (!user.IsActive)
        {
            LogAuthWarning("login", user.Id, "inactive_account");
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (!user.LockoutEnabled)
        {
            user.LockoutEnabled = true;
            await userManager.UpdateAsync(user);
        }

        if (await userManager.IsLockedOutAsync(user))
        {
            await WriteAuditAsync(user.Id, "auth.login.locked", "Login denied: account is temporarily locked.", cancellationToken);
            LogAuthWarning("login", user.Id, "account_locked");
            return Result.Failure<TokenPairResponse>(IdentityErrors.AccountLocked);
        }

        var validPassword = await userManager.CheckPasswordAsync(user, command.Password);
        if (!validPassword)
        {
            await RegisterPasswordFailureAsync(user);
            await WriteAuditAsync(user.Id, "auth.login.failed", "Invalid password.", cancellationToken);
            LogAuthWarning("login", user.Id, "invalid_password");
            return await userManager.IsLockedOutAsync(user)
                ? Result.Failure<TokenPairResponse>(IdentityErrors.AccountLocked)
                : Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (!user.EmailConfirmed)
        {
            await WriteAuditAsync(user.Id, "auth.login.denied", "Login denied: email is not confirmed.", cancellationToken);
            LogAuthWarning("login", user.Id, "email_not_confirmed");
            return Result.Failure<TokenPairResponse>(IdentityErrors.EmailNotConfirmed);
        }

        var accountStatusNormalization = await NormalizeAccountStatusForAuthenticatedUserAsync(user, cancellationToken);
        if (accountStatusNormalization.IsFailure)
        {
            return Result.Failure<TokenPairResponse>(accountStatusNormalization.Error);
        }

        var roles = await userManager.GetRolesAsync(user);
        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        if (user.AccessFailedCount > 0)
        {
            await userManager.ResetAccessFailedCountAsync(user);
        }

        await WriteAuditAsync(user.Id, "auth.login.succeeded", "User logged in.", cancellationToken);
        LogAuthInformation("login", user.Id, "succeeded");

        return Result.Success(tokenPair);
    }

    private async Task RegisterPasswordFailureAsync(AppUser user)
    {
        await userManager.AccessFailedAsync(user);
        var failedCount = await userManager.GetAccessFailedCountAsync(user);
        if (failedCount < PasswordLockoutThreshold)
        {
            return;
        }

        var multiplier = Math.Pow(2, Math.Min(8, failedCount - PasswordLockoutThreshold));
        var lockout = TimeSpan.FromMinutes(PasswordLockoutBaseMinutes * multiplier);
        var maxLockout = TimeSpan.FromHours(PasswordLockoutMaxHours);
        if (lockout > maxLockout)
        {
            lockout = maxLockout;
        }

        await userManager.SetLockoutEndDateAsync(user, DateTimeOffset.UtcNow.Add(lockout));
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

        var sentInWindow = await dbContext.UserEmailCodes
            .Where(x => x.Email == user.Email
                && x.Purpose == EmailCodePurpose.EmailConfirmation
                && x.RequestedAtUtc > now.AddHours(-1))
            .CountAsync(cancellationToken);
        if (sentInWindow >= MaxCodesPerHourPerEmail)
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
            await RegisterCodeFailureAsync(user.Id, EmailCodePurpose.EmailConfirmation, now, cancellationToken);
            return Result.Failure(IdentityErrors.EmailCodeInvalid);
        }

        codeEntity.ConsumedAtUtc = now;
        user.EmailConfirmed = true;
        user.AccountStatus = AccountStatus.Active;
        user.AccountStatusUpdatedAtUtc = now;

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

        var now = DateTime.UtcNow;
        var sentInWindow = await dbContext.UserEmailCodes
            .Where(x => x.Email == user.Email
                && x.Purpose == EmailCodePurpose.PasswordReset
                && x.RequestedAtUtc > now.AddHours(-1))
            .CountAsync(cancellationToken);
        if (sentInWindow >= MaxCodesPerHourPerEmail)
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.PasswordReset, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_reset.requested", "Password reset requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> VerifyPasswordResetCodeAsync(VerifyPasswordResetCodeCommand command, CancellationToken cancellationToken)
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
            await RegisterCodeFailureAsync(user.Id, EmailCodePurpose.PasswordReset, now, cancellationToken);
            return Result.Failure(IdentityErrors.PasswordResetCodeInvalid);
        }

        return Result.Success();
    }

    public Task<Result> ResetPasswordAsync(ResetPasswordCommand command, CancellationToken cancellationToken)
    {
        return ConfirmPasswordResetAsync(new ConfirmPasswordResetCommand(command.Email, command.Code, command.NewPassword), cancellationToken);
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
            await RegisterCodeFailureAsync(user.Id, EmailCodePurpose.PasswordReset, now, cancellationToken);
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

    public async Task<Result> RequestCurrentPasswordChangeCodeAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.Id == userId, cancellationToken);

        if (user is null || !user.IsActive || string.IsNullOrWhiteSpace(user.Email))
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var now = DateTime.UtcNow;
        var sentInWindow = await dbContext.UserEmailCodes
            .Where(x => x.Email == user.Email
                && x.Purpose == EmailCodePurpose.PasswordReset
                && x.RequestedAtUtc > now.AddHours(-1))
            .CountAsync(cancellationToken);
        if (sentInWindow >= MaxCodesPerHourPerEmail)
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.PasswordReset, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_change.requested", "Authenticated password change code requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> ConfirmCurrentPasswordChangeAsync(Guid userId, ConfirmCurrentPasswordChangeCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.Id == userId, cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        if (string.IsNullOrWhiteSpace(command.RefreshToken))
        {
            return Result.Failure(IdentityErrors.InvalidRefreshToken);
        }

        var now = DateTime.UtcNow;
        var currentRefreshTokenHash = HashToken(command.RefreshToken);
        var currentSession = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == userId
                && x.TokenHash == currentRefreshTokenHash
                && x.RevokedAtUtc == null
                && x.ExpiresAtUtc > now)
            .FirstOrDefaultAsync(cancellationToken);
        if (currentSession is null)
        {
            return Result.Failure(IdentityErrors.InvalidRefreshToken);
        }

        var codeEntity = await FindMatchingCodeAsync(userId, EmailCodePurpose.PasswordReset, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            await RegisterCodeFailureAsync(userId, EmailCodePurpose.PasswordReset, now, cancellationToken);
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
        await RevokeRefreshTokensExceptAsync(userId, now, currentRefreshTokenHash, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_change.succeeded", "Password changed for authenticated session; other sessions revoked.", cancellationToken);
        return Result.Success();
    }

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

        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.external_login.succeeded", $"External provider: {provider}", cancellationToken);
        LogSocialAuthInformation("social_login_success", provider, user.Id, "succeeded", isNewUser);
        LogSocialAuthInformation(isNewUser ? "new_user_registered" : "existing_user_logged_in", provider, user.Id, "succeeded", isNewUser);

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

        var accountStatusNormalization = await NormalizeAccountStatusForAuthenticatedUserAsync(user, cancellationToken);
        if (accountStatusNormalization.IsFailure)
        {
            return Result.Failure<TokenPairResponse>(accountStatusNormalization.Error);
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


}
