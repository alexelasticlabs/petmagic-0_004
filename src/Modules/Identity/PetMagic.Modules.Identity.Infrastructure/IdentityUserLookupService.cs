using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityUserLookupService(IdentityDbContext dbContext) : IIdentityUserLookupService
{
    public async Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, IdentityUserLookup>();
        }

        var distinctUserIds = userIds.Distinct().ToArray();
        var users = await dbContext.Users
            .AsNoTracking()
            .Where(x => distinctUserIds.Contains(x.Id))
            .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
            .ToListAsync(cancellationToken);

        return users.ToDictionary(x => x.UserId);
    }

    public async Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.Users
            .AsNoTracking()
            .Where(x => x.Id == userId)
            .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
            .FirstOrDefaultAsync(cancellationToken);
    }
}
