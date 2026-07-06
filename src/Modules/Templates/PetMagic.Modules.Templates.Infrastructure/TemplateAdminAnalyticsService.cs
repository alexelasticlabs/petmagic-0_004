using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateAdminAnalyticsService(
    TemplatesDbContext dbContext,
    IMediaStorage mediaStorage,
    TemplatesOptions options)
{
    private sealed record GenerationAnalyticsProjection(
        Guid GenerationId,
        Guid TemplateId,
        Guid UserId,
        TemplateGenerationStatus Status,
        int TokenCost,
        int AttemptCount,
        string? UsedPreprocessingModel,
        string? UsedKlingModel,
        decimal? MotionProviderCostUsd,
        string? FailureCode,
        string? FailureMessage,
        string? OutputUrl,
        DateTime CreatedAtUtc,
        DateTime? StartedAtUtc,
        DateTime? CompletedAtUtc);
}
