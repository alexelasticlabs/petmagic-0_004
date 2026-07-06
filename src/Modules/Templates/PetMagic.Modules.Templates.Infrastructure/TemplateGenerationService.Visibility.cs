using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task<Result<TemplateItem>> FindPublicGenerationTemplateAsync(
        Guid templateId,
        TemplateVisibilityContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .Include(template => template.Assets)
            .FirstOrDefaultAsync(template => template.Id == templateId, cancellationToken);

        if (template is null)
        {
            RecordRejectedGeneration(userId, templateId, TemplatesErrors.TemplateUnavailable);
            return Result.Failure<TemplateItem>(TemplatesErrors.TemplateUnavailable);
        }

        var decision = await _visibilityPolicy.EvaluatePublicAsync(template, context, cancellationToken);
        if (!decision.IsVisible)
        {
            var error = decision.Error ?? TemplatesErrors.TemplateUnavailable;
            RecordRejectedGeneration(userId, templateId, error);
            return Result.Failure<TemplateItem>(error);
        }

        return Result.Success(template);
    }

    private void RecordRejectedGeneration(Guid userId, Guid templateId, Error error)
    {
        if (error.Code != TemplatesErrors.TemplateUnavailable.Code
            && error.Code != TemplatesErrors.TemplateChanged.Code)
        {
            return;
        }

        logger?.LogWarning(
            "Template generation request rejected by visibility policy. Reason={Reason} TemplateIdHash={TemplateIdHash} UserIdHash={UserIdHash}",
            error.Code,
            TemplateLogSanitizer.SafeId(templateId),
            TemplateLogSanitizer.SafeId(userId));
    }
}
