using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private string? ResolvePreferredLocale()
    {
        var acceptLanguage = httpContextAccessor.HttpContext?.Request.Headers.AcceptLanguage.ToString();
        if (string.IsNullOrWhiteSpace(acceptLanguage))
        {
            return null;
        }

        var candidate = acceptLanguage
            .Split(',', 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault();
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return null;
        }

        var semicolonIndex = candidate.IndexOf(';');
        if (semicolonIndex >= 0)
        {
            candidate = candidate[..semicolonIndex];
        }

        return string.IsNullOrWhiteSpace(candidate) ? null : candidate.Trim();
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
                && x.LockedAtUtc == null
                && x.FailedAttemptCount < MaxCodeAttempts
                && x.CodeHash == codeHash)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task RegisterCodeFailureAsync(
        Guid userId,
        EmailCodePurpose purpose,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var activeCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId
                && x.Purpose == purpose
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now
                && x.LockedAtUtc == null)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (activeCode is null)
        {
            return;
        }

        activeCode.FailedAttemptCount++;
        if (activeCode.FailedAttemptCount >= MaxCodeAttempts)
        {
            activeCode.LockedAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
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

    private async Task RevokeRefreshTokensExceptAsync(Guid userId, DateTime revokedAtUtc, string keepTokenHash, CancellationToken cancellationToken)
    {
        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == userId
                && x.RevokedAtUtc == null
                && x.TokenHash != keepTokenHash)
            .ToListAsync(cancellationToken);

        foreach (var session in sessions)
        {
            session.RevokedAtUtc = revokedAtUtc;
        }
    }
}

