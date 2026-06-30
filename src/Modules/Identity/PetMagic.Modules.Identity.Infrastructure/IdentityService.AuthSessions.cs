using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
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
