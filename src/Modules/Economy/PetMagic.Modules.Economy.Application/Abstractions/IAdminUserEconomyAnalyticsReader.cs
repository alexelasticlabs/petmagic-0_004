using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IAdminUserEconomyAnalyticsReader
{
    Task<Result<AdminUserEconomyAnalyticsResponse>> GetAdminUserEconomyAnalyticsAsync(
        Guid userId,
        CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, DateTime>> GetAdminUserLastActivityAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
