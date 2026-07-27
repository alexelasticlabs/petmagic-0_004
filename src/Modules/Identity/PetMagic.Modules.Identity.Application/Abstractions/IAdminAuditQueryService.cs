using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IAdminAuditQueryService
{
    Task<Result<AdminAuditEventsPageResponse>> ListAsync(
        AdminAuditEventsQuery query,
        CancellationToken cancellationToken);

    Task<Result<AdminAuditEventDetailResponse>> GetAsync(
        Guid eventId,
        CancellationToken cancellationToken);
}
