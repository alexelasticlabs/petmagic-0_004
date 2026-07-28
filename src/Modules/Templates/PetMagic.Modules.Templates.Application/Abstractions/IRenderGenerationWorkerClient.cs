using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IRenderGenerationWorkerClient
{
    bool IsConfigured { get; }

    Task<Result<RenderGenerationWorkerTargetStatus>> GetTargetStatusAsync(
        CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
        CancellationToken cancellationToken);

    Task<Result<RenderScaleAccepted>> ScaleAsync(
        int targetInstances,
        CancellationToken cancellationToken);
}
