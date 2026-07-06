using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IAdminUserTemplateAnalyticsReader
{
    Task<Result<AdminUserTemplateAnalyticsResponse>> GetAdminUserTemplateAnalyticsAsync(
        Guid userId,
        CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, DateTime>> GetAdminUserLastActivityAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
