using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityAccessTokenValidator(IdentityDbContext dbContext) : IIdentityAccessTokenValidator
{
    public Task<bool> IsCurrentAsync(Guid userId, string securityStamp, CancellationToken cancellationToken)
    {
        return IsCurrentAsync(userId, securityStamp, sessionId: null, cancellationToken);
    }

    public Task<bool> IsCurrentAsync(
        Guid userId,
        string securityStamp,
        Guid? sessionId,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty || string.IsNullOrWhiteSpace(securityStamp))
        {
            return Task.FromResult(false);
        }

        if (sessionId.HasValue)
        {
            var now = DateTime.UtcNow;
            return (
                from user in dbContext.Users.AsNoTracking()
                join session in dbContext.RefreshTokenSessions.AsNoTracking()
                    on user.Id equals session.UserId
                where user.Id == userId
                    && user.IsActive
                    && user.SecurityStamp == securityStamp
                    && session.Id == sessionId.Value
                    && session.RevokedAtUtc == null
                    && session.ExpiresAtUtc > now
                select session.Id)
                .AnyAsync(cancellationToken);
        }

        return dbContext.Users
            .AsNoTracking()
            .AnyAsync(
                user => user.Id == userId
                    && user.IsActive
                    && user.SecurityStamp == securityStamp,
                cancellationToken);
    }
}
