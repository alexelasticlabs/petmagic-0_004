using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationProviderCallbackService(
    TemplateGenerationJobProcessor processor) : ITemplateGenerationProviderCallbackService
{
    public Task<Result<FalProviderWebhookResponse>> ProcessFalWebhookAsync(
        FalProviderWebhookCommand command,
        CancellationToken cancellationToken)
    {
        return processor.ProcessFalWebhookAsync(command, cancellationToken);
    }
}
