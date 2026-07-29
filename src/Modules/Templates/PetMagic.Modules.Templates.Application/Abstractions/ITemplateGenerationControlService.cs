using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationControlService
{
    Task<Result<AdminTemplateGenerationControlResponse>> GetAsync(CancellationToken cancellationToken);

    Task<Result<AdminTemplateGenerationControlResponse>> UpdatePolicyAsync(
        UpdateAdminTemplateGenerationControlPolicyCommand command,
        CancellationToken cancellationToken);

    Task<Result<AdminTemplateGenerationProviderRefreshResponse>> RefreshProviderAsync(
        CancellationToken cancellationToken);

    Task<Result<AdminTemplateProviderAttemptRecoveryPageResponse>> ListProviderAttemptRecoveryAsync(
        AdminTemplateProviderAttemptRecoveryQuery query,
        CancellationToken cancellationToken);

    Task<Result<AdminTemplateProviderAttemptResolutionResponse>> ResolveProviderAttemptAsync(
        ResolveAdminTemplateProviderAttemptCommand command,
        CancellationToken cancellationToken);
}
