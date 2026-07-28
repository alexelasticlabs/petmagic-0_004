using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IAdminGenerationRenderControlService
{
    Task<Result<AdminRenderScaleOperationResponse>> RequestScaleAsync(
        Guid actorUserId,
        string idempotencyKey,
        AdminRenderScaleCommand command,
        string correlationId,
        CancellationToken cancellationToken);

    Task<Result<AdminRenderScaleOperationResponse>> GetOperationAsync(
        Guid operationId,
        CancellationToken cancellationToken);

    Task<Result<AdminRenderScaleOperationResponse>> CancelOperationAsync(
        Guid actorUserId,
        Guid operationId,
        string reason,
        string correlationId,
        CancellationToken cancellationToken);
}
