using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task RecordMediaAccessAnalyticsAsync(
        Guid userId,
        Guid generationId,
        string eventType,
        string? mediaType,
        string? userPlan,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        if (job is null)
        {
            return;
        }

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = userId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(job.Id, job.TemplateId, mediaType, userPlan),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private void AddAnalyticsEvent(
        TemplateGenerationJob job,
        string eventType,
        string? userPlan = null,
        string? unlockMethod = null,
        int? creditsSpent = null)
    {
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = job.UserId,
            GenerationId = job.Id,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(
                job.Id,
                job.TemplateId,
                job.Template?.TemplateType.ToString(),
                userPlan,
                unlockMethod,
                creditsSpent,
                job.ParentGenerationId,
                job.Template?.TemplateType.ToString(),
                ResolveAnalyticsInputMediaType(job),
                job.TokenCost),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid petPhotoId,
        Guid templateId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            UserId = pet.UserId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = JsonSerializer.Serialize(new
            {
                generationId,
                templateId,
                mediaType = "image",
                petId = pet.Id,
                petPhotoId
            }),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });

        return Task.CompletedTask;
    }

    private static string BuildAnalyticsMetadata(
        Guid generationId,
        Guid templateId,
        string? mediaType,
        string? userPlan,
        string? unlockMethod = null,
        int? creditsSpent = null,
        Guid? parentGenerationId = null,
        string? newTemplateType = null,
        string? inputMediaType = null,
        int? creditsCost = null)
    {
        return JsonSerializer.Serialize(new
        {
            generationId,
            templateId,
            parentGenerationId,
            newTemplateId = templateId,
            newTemplateType = NormalizeAnalyticsMediaType(newTemplateType),
            mediaType = string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant(),
            inputMediaType = NormalizeAnalyticsMediaType(inputMediaType),
            userPlan,
            unlockMethod,
            creditsSpent,
            creditsCost
        });
    }

    private static string? ResolveAnalyticsInputMediaType(TemplateGenerationJob job)
    {
        if (job.InputSourceType is null)
        {
            return null;
        }

        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return job.Template?.RequiredInputMediaType?.ToString();
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? "image"
            : null;
    }

    private static string NormalizeAnalyticsMediaType(string? mediaType)
    {
        return string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant();
    }
}
