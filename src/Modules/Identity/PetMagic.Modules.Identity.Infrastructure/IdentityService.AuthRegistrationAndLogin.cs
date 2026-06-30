using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    public async Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var normalizedEmail = email.ToUpperInvariant();
        var termsOfUseVersion = string.IsNullOrWhiteSpace(command.TermsOfUseVersion)
            ? legalDocumentsCatalog.CurrentTermsOfUseVersion
            : command.TermsOfUseVersion;
        var privacyPolicyVersion = string.IsNullOrWhiteSpace(command.PrivacyPolicyVersion)
            ? legalDocumentsCatalog.CurrentPrivacyPolicyVersion
            : command.PrivacyPolicyVersion;
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
            existing.TermsOfUseAcceptedVersion = command.TermsOfUseAccepted ? termsOfUseVersion : null;
            existing.PrivacyPolicyAccepted = command.PrivacyPolicyAccepted;
            existing.PrivacyPolicyAcceptedAtUtc = command.PrivacyPolicyAccepted ? now : null;
            existing.PrivacyPolicyAcceptedVersion = command.PrivacyPolicyAccepted ? privacyPolicyVersion : null;
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
            TermsOfUseAcceptedVersion = command.TermsOfUseAccepted ? termsOfUseVersion : null,
            PrivacyPolicyAccepted = command.PrivacyPolicyAccepted,
            PrivacyPolicyAcceptedAtUtc = command.PrivacyPolicyAccepted ? now : null,
            PrivacyPolicyAcceptedVersion = command.PrivacyPolicyAccepted ? privacyPolicyVersion : null,
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

    public async Task<Result<TokenPairResponse>> VerifyEmailCodeAsync(VerifyEmailCodeCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.EmailCodeInvalid);
        }

        var now = DateTime.UtcNow;
        var codeEntity = await FindMatchingCodeAsync(user.Id, EmailCodePurpose.EmailConfirmation, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            await RegisterCodeFailureAsync(user.Id, EmailCodePurpose.EmailConfirmation, now, cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.EmailCodeInvalid);
        }

        codeEntity.ConsumedAtUtc = now;
        user.EmailConfirmed = true;
        user.AccountStatus = AccountStatus.Active;
        user.AccountStatusUpdatedAtUtc = now;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        var roles = await userManager.GetRolesAsync(user);
        if (!roles.Contains(SystemRoles.User, StringComparer.Ordinal))
        {
            await userManager.AddToRoleAsync(user, SystemRoles.User);
            roles.Add(SystemRoles.User);
        }

        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "user.email_confirmed", "Email address confirmed and auth session issued.", cancellationToken);
        LogAuthInformation("email_verification", user.Id, "succeeded");
        return Result.Success(tokenPair);
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
}
