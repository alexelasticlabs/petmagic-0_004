using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationService(
    TemplatesDbContext dbContext,
    ITemplateGenerationBilling billing) : ITemplateGenerationService
{
    internal static readonly Guid AdminTestUserId = Guid.Empty;

    public async Task<Result<TemplateGenerationResponse>> StartAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == command.TemplateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound);
        }

        var readiness = ValidateTemplate(template);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = command.SourceImageAsset.Url,
            SourceImageFileName = command.SourceImageAsset.FileName,
            SourceImageContentType = command.SourceImageAsset.ContentType,
            SourceImageFileSizeBytes = command.SourceImageAsset.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync(cancellationToken);

        var charge = await billing.ChargeAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (charge.IsFailure)
        {
            job.Status = TemplateGenerationStatus.Failed;
            job.FailureCode = charge.Error.Code;
            job.FailureMessage = charge.Error.Message;
            job.UpdatedAtUtc = DateTime.UtcNow;
            job.CompletedAtUtc = job.UpdatedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Failure<TemplateGenerationResponse>(charge.Error);
        }

        job.ChargedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.ChargedAtUtc.Value;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(MapResponse(job));
    }

    public async Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(Guid templateId, TemplateAssetCommand sourceImageAsset, CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound);
        }

        var readiness = ValidateTemplate(template);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = AdminTestUserId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = sourceImageAsset.Url,
            SourceImageFileName = sourceImageAsset.FileName,
            SourceImageContentType = sourceImageAsset.ContentType,
            SourceImageFileSizeBytes = sourceImageAsset.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(MapResponse(job));
    }

    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapResponse(job));
    }

    public async Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == AdminTestUserId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapResponse(job));
    }

    internal static Error? ValidateTemplate(TemplateItem template)
    {
        if (template.Status != TemplateStatus.Active)
        {
            return TemplatesErrors.InvalidStatus;
        }

        if (template.TemplateType == TemplateType.Image)
        {
            return string.IsNullOrWhiteSpace(template.ImageModel)
                ? TemplatesErrors.MissingImageModel
                : null;
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return TemplatesErrors.TypeMismatch;
        }

        if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
        {
            return TemplatesErrors.MissingReferenceMotion;
        }

        if (template.CharacterOrientation is null)
        {
            return TemplatesErrors.MissingCharacterOrientation;
        }

        if (string.IsNullOrWhiteSpace(template.PreprocessingModel))
        {
            return TemplatesErrors.InvalidPreprocessingModel;
        }

        if (string.IsNullOrWhiteSpace(template.KlingModel))
        {
            return TemplatesErrors.InvalidKlingModel;
        }

        return null;
    }

    internal static TemplateAsset? GetAsset(TemplateItem template, TemplateAssetKind kind)
    {
        return template.Assets.FirstOrDefault(x => x.AssetKind == kind);
    }

    internal static string ResolvePrompt(string? prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    internal static TemplateGenerationResponse MapResponse(TemplateGenerationJob job)
    {
        return new TemplateGenerationResponse(
            job.Id,
            job.UserId,
            job.TemplateId,
            job.Status.ToString(),
            job.TokenCost,
            MapSourceImageAsset(job),
            job.NormalizedImageUrl,
            job.ReferenceMotionUrl,
            job.OutputUrl,
            job.AttemptCount,
            job.UsedPreprocessingModel,
            job.UsedKlingModel,
            job.PreprocessingProviderRequestId,
            job.PreprocessingInferenceTimeSeconds,
            job.MotionProviderRequestId,
            job.MotionInferenceTimeSeconds,
            job.OutputVideoDurationSeconds,
            job.MotionProviderCostUsd,
            job.FailureCode,
            job.FailureMessage,
            job.CreatedAtUtc,
            job.UpdatedAtUtc,
            job.StartedAtUtc,
            job.PreprocessingCompletedAtUtc,
            job.MotionGenerationCompletedAtUtc,
            job.MediaImportCompletedAtUtc,
            job.CompletedAtUtc,
            job.UserMediaDeletedAtUtc != null);
    }

    private static TemplateAssetResponse? MapSourceImageAsset(TemplateGenerationJob job)
    {
        if (string.IsNullOrWhiteSpace(job.SourceImageUrl))
        {
            return null;
        }

        return new TemplateAssetResponse(
            job.SourceImageUrl,
            job.SourceImageFileName,
            job.SourceImageContentType,
            job.SourceImageFileSizeBytes,
            null);
    }
}
