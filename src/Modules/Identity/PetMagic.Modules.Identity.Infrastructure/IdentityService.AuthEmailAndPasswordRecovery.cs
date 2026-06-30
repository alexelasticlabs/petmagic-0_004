using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
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
}
