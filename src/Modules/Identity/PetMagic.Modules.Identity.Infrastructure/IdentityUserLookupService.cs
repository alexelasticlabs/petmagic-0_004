using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityUserLookupService(IdentityDbContext dbContext, IMemoryCache? cache = null) : IIdentityUserLookupService
{
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public async Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, IdentityUserLookup>();
        }

        var distinctUserIds = userIds.Distinct().ToArray();
        var result = new Dictionary<Guid, IdentityUserLookup>(distinctUserIds.Length);
        var missingUserIds = new List<Guid>();

        foreach (var userId in distinctUserIds)
        {
            if (cache?.TryGetValue(GetCacheKey(userId), out IdentityUserLookup? cachedUser) == true && cachedUser is not null)
            {
                result[userId] = cachedUser;
                continue;
            }

            missingUserIds.Add(userId);
        }

        if (missingUserIds.Count == 0)
        {
            return result;
        }

        var users = await dbContext.Users
            .AsNoTracking()
            .Where(x => missingUserIds.Contains(x.Id))
            .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
            .ToListAsync(cancellationToken);

        foreach (var user in users)
        {
            result[user.UserId] = user;
            cache?.Set(GetCacheKey(user.UserId), user, CacheDuration);
        }

        return result;
    }

    public async Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (cache?.TryGetValue(GetCacheKey(userId), out IdentityUserLookup? cachedUser) == true && cachedUser is not null)
        {
            return cachedUser;
        }

        var user = await dbContext.Users
            .AsNoTracking()
            .Where(x => x.Id == userId)
            .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
            .FirstOrDefaultAsync(cancellationToken);

        if (user is not null)
        {
            cache?.Set(GetCacheKey(userId), user, CacheDuration);
        }

        return user;
    }

    private static string GetCacheKey(Guid userId) => $"identity-user-lookup:{userId:N}";
}
