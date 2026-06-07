using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationJobStatusSets
{
    public static readonly TemplateGenerationStatus[] Active =
    [
        TemplateGenerationStatus.Queued,
        TemplateGenerationStatus.Processing,
        TemplateGenerationStatus.Retrying
    ];

    public static readonly TemplateGenerationStatus[] Processing =
    [
        TemplateGenerationStatus.Processing
    ];
}
