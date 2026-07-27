using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityUserLookupService(IdentityDbContext dbContext, IMemoryCache? cache = null) : IIdentityUserLookupService
{
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public async Task<IReadOnlyList<Guid>> GetActiveUserIdsInRolesAsync(
        IReadOnlyCollection<string> roles,
        CancellationToken cancellationToken)
    {
        var normalizedRoles = roles
            .Where(static role => !string.IsNullOrWhiteSpace(role))
            .Select(static role => role.Trim())
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        if (normalizedRoles.Length == 0)
        {
            return [];
        }

        var activeRoleUserIds = dbContext.UserRoles
            .AsNoTracking()
            .Join(
                dbContext.Roles.AsNoTracking(),
                userRole => userRole.RoleId,
                role => role.Id,
                (userRole, role) => new
                {
                    userRole.UserId,
                    RoleName = role.Name
                })
            .Where(x => x.RoleName != null && normalizedRoles.Contains(x.RoleName));

        return await activeRoleUserIds
            .Join(
                dbContext.Users.AsNoTracking().Where(user => user.IsActive),
                roleUser => roleUser.UserId,
                user => user.Id,
                (roleUser, _) => roleUser.UserId)
            .Distinct()
            .ToListAsync(cancellationToken);
    }

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

        var rolesByUserId = await LoadRolesByUserIdAsync(missingUserIds, cancellationToken);
        var users = await dbContext.Users
            .AsNoTracking()
            .Where(x => missingUserIds.Contains(x.Id))
            .Select(x => new
            {
                x.Id,
                x.Email,
                x.DisplayName
            })
            .ToListAsync(cancellationToken);

        foreach (var user in users)
        {
            var resolvedUser = new IdentityUserLookup(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                rolesByUserId.TryGetValue(user.Id, out var roles) ? roles : []);
            result[user.Id] = resolvedUser;
            cache?.Set(GetCacheKey(user.Id), resolvedUser, CacheDuration);
        }

        return result;
    }

    public async Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (cache?.TryGetValue(GetCacheKey(userId), out IdentityUserLookup? cachedUser) == true && cachedUser is not null)
        {
            return cachedUser;
        }

        var rolesByUserId = await LoadRolesByUserIdAsync([userId], cancellationToken);
        var user = await dbContext.Users
            .AsNoTracking()
            .Where(x => x.Id == userId)
            .Select(x => new
            {
                x.Id,
                x.Email,
                x.DisplayName
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (user is not null)
        {
            var resolvedUser = new IdentityUserLookup(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                rolesByUserId.TryGetValue(user.Id, out var roles) ? roles : []);
            cache?.Set(GetCacheKey(userId), resolvedUser, CacheDuration);
            return resolvedUser;
        }

        return null;
    }

    private async Task<IReadOnlyDictionary<Guid, IReadOnlyList<string>>> LoadRolesByUserIdAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, IReadOnlyList<string>>();
        }

        var distinctUserIds = userIds.Distinct().ToArray();
        var roleRows = await dbContext.UserRoles
            .AsNoTracking()
            .Where(x => distinctUserIds.Contains(x.UserId))
            .Join(
                dbContext.Roles.AsNoTracking(),
                userRole => userRole.RoleId,
                role => role.Id,
                (userRole, role) => new
                {
                    userRole.UserId,
                    RoleName = role.Name
                })
            .Where(x => !string.IsNullOrWhiteSpace(x.RoleName))
            .ToListAsync(cancellationToken);

        return roleRows
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<string>)group
                    .Select(x => x.RoleName!)
                    .Distinct(StringComparer.Ordinal)
                    .OrderBy(x => x, StringComparer.Ordinal)
                    .ToArray());
    }

    private static string GetCacheKey(Guid userId) => $"identity-user-lookup:{userId:N}";
}
