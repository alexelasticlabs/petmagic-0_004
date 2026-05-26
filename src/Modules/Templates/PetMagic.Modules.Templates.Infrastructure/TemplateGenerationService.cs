using System.Text.Json;

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

        var readiness = ValidateTemplate(template, requireActiveStatus: true);
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
            Template = template,
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

        var readiness = ValidateTemplate(template, requireActiveStatus: false);
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
            Template = template,
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
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapResponse(job));
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, CancellationToken cancellationToken)
    {
        var skip = Math.Clamp(query.Skip ?? 0, 0, 10_000);
        var take = Math.Clamp(query.Take ?? 30, 1, 100);

        var generationsQuery = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Where(x => x.UserId == userId);

        generationsQuery = ApplyStatusFilter(generationsQuery, query.Status);

        var items = await generationsQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip(skip)
            .Take(take)
            .Select(x => MapResponse(x))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(items);
    }

    public async Task<Result<TemplateGenerationUnreadCountResponse>> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken)
    {
        var count = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == userId
                && x.Status == TemplateGenerationStatus.Completed
                && x.ResultViewedAtUtc == null,
                cancellationToken);

        return Result.Success(new TemplateGenerationUnreadCountResponse(count));
    }

    public async Task<Result> MarkReadAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        job.ResultViewedAtUtc ??= DateTime.UtcNow;
        job.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RecordFeedbackAsync(RecordTemplateGenerationFeedbackCommand command, CancellationToken cancellationToken)
    {
        if (command.Rating is < 1 or > 3)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == command.GenerationId && x.UserId == command.UserId, cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        var reasons = NormalizeFeedbackReasons(command.SelectedReasons);
        if (reasons.Length > 8)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        dbContext.TemplateGenerationFeedback.Add(new TemplateGenerationFeedback
        {
            Id = Guid.NewGuid(),
            GenerationId = job.Id,
            UserId = job.UserId,
            TemplateId = job.TemplateId,
            Rating = command.Rating,
            SelectedReasons = JsonSerializer.Serialize(reasons),
            Comment = NormalizeOptionalText(command.Comment, 2000),
            InputPhotoQualityScore = command.InputPhotoQualityScore,
            ModelUsed = ResolveFeedbackModel(job),
            GenerationDurationSeconds = ResolveGenerationDurationSeconds(job),
            ProviderRequestId = ResolveProviderRequestId(job),
            CreatedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == AdminTestUserId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapResponse(job));
    }

    internal static Error? ValidateTemplate(TemplateItem template, bool requireActiveStatus)
    {
        if (requireActiveStatus && template.Status != TemplateStatus.Active)
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
            ResolveApiStatus(job.Status),
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
            job.UserMediaDeletedAtUtc != null,
            job.Template?.Title,
            job.Template?.TemplateType.ToString(),
            ResolveStage(job),
            ResolveProgressPercent(job),
            ResolveEstimatedDurationLabel(job.Template?.TemplateType),
            job.ChargedAtUtc,
            job.RefundedAtUtc,
            job.Status == TemplateGenerationStatus.Completed && job.ResultViewedAtUtc == null);
    }

    private static IQueryable<TemplateGenerationJob> ApplyStatusFilter(
        IQueryable<TemplateGenerationJob> query,
        string? rawStatus)
    {
        return rawStatus?.Trim().ToLowerInvariant() switch
        {
            null or "" or "all" => query,
            "active" or "in_progress" or "processing" => query.Where(x => x.Status != TemplateGenerationStatus.Completed && x.Status != TemplateGenerationStatus.Failed),
            "ready" or "succeeded" or "completed" => query.Where(x => x.Status == TemplateGenerationStatus.Completed),
            "error" or "failed" => query.Where(x => x.Status == TemplateGenerationStatus.Failed),
            "queued" => query.Where(x => x.Status == TemplateGenerationStatus.Queued),
            "preprocessing" => query.Where(x => x.Status == TemplateGenerationStatus.Preprocessing),
            "generating" => query.Where(x => x.Status == TemplateGenerationStatus.Generating),
            "finalizing" => query.Where(x => x.Status == TemplateGenerationStatus.Finalizing),
            _ => query
        };
    }

    private static string[] NormalizeFeedbackReasons(IReadOnlyCollection<string> rawReasons)
    {
        return [.. rawReasons
            .Select(x => NormalizeOptionalText(x, 120))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Cast<string>()];
    }

    private static string? ResolveFeedbackModel(TemplateGenerationJob job)
    {
        return string.IsNullOrWhiteSpace(job.UsedKlingModel)
            ? job.UsedPreprocessingModel
            : job.UsedKlingModel;
    }

    private static double? ResolveGenerationDurationSeconds(TemplateGenerationJob job)
    {
        if (job.StartedAtUtc is null || job.CompletedAtUtc is null)
        {
            return null;
        }

        return Math.Max(0, (job.CompletedAtUtc.Value - job.StartedAtUtc.Value).TotalSeconds);
    }

    private static string? ResolveProviderRequestId(TemplateGenerationJob job)
    {
        return string.IsNullOrWhiteSpace(job.MotionProviderRequestId)
            ? job.PreprocessingProviderRequestId
            : job.MotionProviderRequestId;
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    internal static string ResolveApiStatus(TemplateGenerationStatus status)
    {
        return status == TemplateGenerationStatus.Completed
            ? TemplateGenerationStatus.Succeeded.ToString()
            : status.ToString();
    }

    internal static string ResolveStage(TemplateGenerationJob job)
    {
        if (job.Status == TemplateGenerationStatus.Failed)
        {
            return "failed";
        }

        if (job.Status == TemplateGenerationStatus.Completed)
        {
            return "succeeded";
        }

        if (job.Status == TemplateGenerationStatus.Finalizing || job.MediaImportCompletedAtUtc is not null)
        {
            return "finalizing";
        }

        if (job.Status == TemplateGenerationStatus.Generating || job.MotionGenerationCompletedAtUtc is not null)
        {
            return "generating";
        }

        if (job.Status == TemplateGenerationStatus.Preprocessing || job.StartedAtUtc is not null)
        {
            return "preprocessing";
        }

        if (job.Status == TemplateGenerationStatus.Uploading)
        {
            return "uploading";
        }

        return "queued";
    }

    internal static int ResolveProgressPercent(TemplateGenerationJob job)
    {
        return ResolveStage(job) switch
        {
            "succeeded" => 100,
            "failed" => 100,
            "finalizing" => 90,
            "generating" => 65,
            "preprocessing" => 30,
            "uploading" => 15,
            _ => 10
        };
    }

    private static string ResolveEstimatedDurationLabel(TemplateType? templateType)
    {
        return templateType == TemplateType.Video
            ? "Usually 1-3 minutes"
            : "Usually under 1 minute";
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
