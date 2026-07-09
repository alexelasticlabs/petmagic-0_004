using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationJobStatusSets
{
    public static readonly TemplateGenerationStatus[] Active =
    [
        TemplateGenerationStatus.Queued,
        TemplateGenerationStatus.Processing,
        TemplateGenerationStatus.Retrying,
        TemplateGenerationStatus.SubmittingToProvider,
        TemplateGenerationStatus.ProviderQueued,
        TemplateGenerationStatus.ProviderProcessing,
        TemplateGenerationStatus.ImportingMedia,
        TemplateGenerationStatus.CancellationRequested
    ];

    public static readonly TemplateGenerationStatus[] Processing =
    [
        TemplateGenerationStatus.Processing,
        TemplateGenerationStatus.SubmittingToProvider,
        TemplateGenerationStatus.ProviderQueued,
        TemplateGenerationStatus.ProviderProcessing,
        TemplateGenerationStatus.ImportingMedia
    ];
}
