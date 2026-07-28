using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IAdminGenerationControlService
{
    Task<Result<AdminGenerationControlResponse>> GetAsync(Guid adminUserId, CancellationToken cancellationToken);

    Task<Result<AdminGenerationControlResponse>> UpdateAsync(
        UpdateAdminGenerationControlCommand command,
        CancellationToken cancellationToken);

    Task<Result<AdminGenerationControlResponse>> RefreshProviderAsync(
        Guid adminUserId,
        CancellationToken cancellationToken);

    Task<Result<AdminGenerationOperationalAlertResponse>> AcknowledgeAlertAsync(
        Guid alertId,
        Guid adminUserId,
        CancellationToken cancellationToken);
}
public interface ITemplateGenerationRuntimeSettingsProvider
{
    TemplateGenerationRuntimeSnapshot Current { get; }

    Task RefreshAsync(CancellationToken cancellationToken);
}

public interface ITemplateGenerationDrainController
{
    Task<bool> TryPauseNewClaimsAsync(Guid operationId, CancellationToken cancellationToken);

    Task<bool> TryResumeNewClaimsAsync(Guid operationId, CancellationToken cancellationToken);
}
