using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationQaFixtureService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    ITemplateGenerationBilling billing,
    IMediaStorage mediaStorage,
    ITemplateFeedRealtimeService realtimeService) : ITemplateGenerationQaFixtureService
{
    private static readonly string[] DefaultScenarios =
    [
        "queued",
        "providerQueued",
        "providerProcessing",
        "importingMedia",
        "failed",
        "waitTooLongImage",
        "waitTooLongVideo"
    ];

    public async Task<Result<QaGenerationFixturesResponse>> CreateAsync(
        Guid userId,
        CreateQaGenerationFixturesCommand command,
        CancellationToken cancellationToken)
    {
        if (!options.QaFixturesEnabled)
        {
            return Result.Failure<QaGenerationFixturesResponse>(TemplatesErrors.NotFound);
        }

        var deletedBeforeCreate = await CleanupInternalAsync(userId, cancellationToken);
        var requestedScenarios = NormalizeScenarios(command.Scenarios);
        var templates = await LoadRequiredTemplatesAsync(command, requestedScenarios, cancellationToken);
        if (templates.IsFailure)
        {
            return Result.Failure<QaGenerationFixturesResponse>(templates.Error);
        }

        var responses = new List<TemplateGenerationResponse>();
        var waitTooLong = new List<QaGenerationWaitTooLongFixtureResponse>();
        foreach (var scenario in requestedScenarios)
        {
            switch (scenario)
            {
                case "queued":
                    var queued = await CreateUserFixtureAsync(
                        userId,
                        templates.Value.ImageTemplate,
                        TemplateGenerationStatus.Queued,
                        scenario,
                        chargeAndKeepCharge: true,
                        refundImmediately: false,
                        cancellationToken);
                    if (queued.IsFailure)
                    {
                        return Result.Failure<QaGenerationFixturesResponse>(queued.Error);
                    }

                    responses.Add(queued.Value);
                    break;
                case "providerQueued":
                    var providerQueued = await CreateUserFixtureAsync(
                        userId,
                        templates.Value.VideoTemplate,
                        TemplateGenerationStatus.ProviderQueued,
                        scenario,
                        chargeAndKeepCharge: false,
                        refundImmediately: false,
                        cancellationToken);
                    if (providerQueued.IsFailure)
                    {
                        return Result.Failure<QaGenerationFixturesResponse>(providerQueued.Error);
                    }

                    responses.Add(providerQueued.Value);
                    break;
                case "providerProcessing":
                    var providerProcessing = await CreateUserFixtureAsync(
                        userId,
                        templates.Value.VideoTemplate,
                        TemplateGenerationStatus.ProviderProcessing,
                        scenario,
                        chargeAndKeepCharge: false,
                        refundImmediately: false,
                        cancellationToken);
                    if (providerProcessing.IsFailure)
                    {
                        return Result.Failure<QaGenerationFixturesResponse>(providerProcessing.Error);
                    }

                    responses.Add(providerProcessing.Value);
                    break;
                case "importingMedia":
                    var importingMedia = await CreateUserFixtureAsync(
                        userId,
                        templates.Value.VideoTemplate,
                        TemplateGenerationStatus.ImportingMedia,
                        scenario,
                        chargeAndKeepCharge: false,
                        refundImmediately: false,
                        cancellationToken);
                    if (importingMedia.IsFailure)
                    {
                        return Result.Failure<QaGenerationFixturesResponse>(importingMedia.Error);
                    }

                    responses.Add(importingMedia.Value);
                    break;
                case "failed":
                    var failed = await CreateUserFixtureAsync(
                        userId,
                        templates.Value.ImageTemplate,
                        TemplateGenerationStatus.Failed,
                        scenario,
                        chargeAndKeepCharge: true,
                        refundImmediately: true,
                        cancellationToken);
                    if (failed.IsFailure)
                    {
                        return Result.Failure<QaGenerationFixturesResponse>(failed.Error);
                    }

                    responses.Add(failed.Value);
                    break;
                case "waitTooLongImage":
                    waitTooLong.Add(await CreateWaitTooLongBacklogAsync(
                        templates.Value.ImageTemplate,
                        TemplateGenerationQueue.MediaTypeImage,
                        scenario,
                        cancellationToken));
                    break;
                case "waitTooLongVideo":
                    waitTooLong.Add(await CreateWaitTooLongBacklogAsync(
                        templates.Value.VideoTemplate,
                        TemplateGenerationQueue.MediaTypeVideo,
                        scenario,
                        cancellationToken));
                    break;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        foreach (var response in responses)
        {
            await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
        }

        return Result.Success(new QaGenerationFixturesResponse(responses, waitTooLong, deletedBeforeCreate.DeletedGenerationJobs));
    }

    public async Task<Result<QaGenerationFixtureCleanupResponse>> CleanupAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (!options.QaFixturesEnabled)
        {
            return Result.Failure<QaGenerationFixtureCleanupResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(await CleanupInternalAsync(userId, cancellationToken));
    }

    private async Task<QaGenerationFixtureCleanupResponse> CleanupInternalAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var fixtureJobs = await dbContext.TemplateGenerationJobs
            .Where(x => x.InputSourceType == TemplateGenerationQaFixtures.InputSourceType
                && (x.UserId == userId || x.UserId == TemplateGenerationService.AdminTestUserId))
            .ToArrayAsync(cancellationToken);
        var refunded = 0;
        foreach (var job in fixtureJobs.Where(x => x.ChargedAtUtc is not null && x.RefundedAtUtc is null && x.TokenCost > 0))
        {
            var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
            if (refund.IsSuccess)
            {
                job.RefundedAtUtc = DateTime.UtcNow;
                job.RefundLastErrorCode = null;
                refunded++;
            }
            else
            {
                job.RefundLastErrorCode = refund.Error.Code;
            }
        }

        var fixtureJobIds = fixtureJobs.Select(x => x.Id).ToArray();
        var mediaRecords = await dbContext.TemplateMediaRecords
            .Where(x => x.SourceType == TemplateGenerationQaFixtures.InputSourceType
                || (x.GenerationJobId != null && fixtureJobIds.Contains(x.GenerationJobId.Value)))
            .ToArrayAsync(cancellationToken);
        var fixtureJobIdStrings = fixtureJobIds.Select(x => x.ToString()).ToArray();
        var realtimeCandidates = await dbContext.TemplateRealtimeEvents
            .Where(x => x.Topic == TemplateFeedRealtimeTopics.GenerationStatusChanged
                && x.Data != null)
            .ToArrayAsync(cancellationToken);
        var realtimeEvents = realtimeCandidates
            .Where(x => fixtureJobIdStrings.Any(id => x.Data?.Contains(id, StringComparison.OrdinalIgnoreCase) == true))
            .ToArray();

        dbContext.TemplateMediaRecords.RemoveRange(mediaRecords);
        dbContext.TemplateRealtimeEvents.RemoveRange(realtimeEvents);
        dbContext.TemplateGenerationJobs.RemoveRange(fixtureJobs);
        await dbContext.SaveChangesAsync(cancellationToken);

        return new QaGenerationFixtureCleanupResponse(
            fixtureJobs.Length,
            mediaRecords.Length,
            realtimeEvents.Length,
            refunded);
    }

    private async Task<Result<TemplateGenerationResponse>> CreateUserFixtureAsync(
        Guid userId,
        TemplateItem template,
        TemplateGenerationStatus status,
        string scenario,
        bool chargeAndKeepCharge,
        bool refundImmediately,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var generationId = Guid.NewGuid();
        var tokenCost = chargeAndKeepCharge ? template.TokenCost : 0;
        var job = CreateBaseJob(
            generationId,
            userId,
            template,
            status,
            scenario,
            tokenCost,
            now);

        ApplyStatusDetails(job, status, now);
        var mediaRecord = CreateSourceMediaRecord(job, now);
        dbContext.TemplateGenerationJobs.Add(job);
        dbContext.TemplateMediaRecords.Add(mediaRecord);
        await dbContext.SaveChangesAsync(cancellationToken);

        if (chargeAndKeepCharge && tokenCost > 0)
        {
            var charge = await billing.ChargeAsync(userId, generationId, tokenCost, cancellationToken);
            if (charge.IsFailure)
            {
                dbContext.TemplateMediaRecords.Remove(mediaRecord);
                dbContext.TemplateGenerationJobs.Remove(job);
                await dbContext.SaveChangesAsync(cancellationToken);
                return Result.Failure<TemplateGenerationResponse>(charge.Error);
            }

            job.ChargedAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = job.ChargedAtUtc.Value;
            if (refundImmediately)
            {
                var refund = await billing.RefundAsync(userId, generationId, tokenCost, cancellationToken);
                if (refund.IsSuccess)
                {
                    job.RefundedAtUtc = DateTime.UtcNow;
                    job.RefundLastErrorCode = null;
                }
                else
                {
                    job.RefundLastErrorCode = refund.Error.Code;
                }
            }

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Result.Success(await TemplateGenerationService.SignUserMediaUrlsAsync(
            mediaStorage,
            options,
            TemplateGenerationService.MapResponse(job),
            cancellationToken));
    }

    private async Task<QaGenerationWaitTooLongFixtureResponse> CreateWaitTooLongBacklogAsync(
        TemplateItem template,
        string mediaType,
        string scenario,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var maxWaitSeconds = ResolveMaxEstimatedWaitSeconds(mediaType, TemplateGenerationQueue.TierFree);
        var generationSeconds = mediaType == TemplateGenerationQueue.MediaTypeVideo
            ? Math.Max(1, options.EstimatedVideoGenerationSeconds)
            : Math.Max(1, options.EstimatedImageGenerationSeconds);
        var slots = mediaType == TemplateGenerationQueue.MediaTypeVideo
            ? Math.Max(1, ResolveVideoReservedConcurrency())
            : Math.Max(1, Math.Min(options.ImageMaxConcurrentGenerations, options.GlobalMaxConcurrentGenerations));
        var backlogCount = Math.Max(1, (int)Math.Floor(maxWaitSeconds * slots / (double)generationSeconds) + 1);
        var estimatedWaitSeconds = (int)Math.Ceiling(backlogCount * generationSeconds / (double)slots);

        for (var i = 0; i < backlogCount; i++)
        {
            var generationId = Guid.NewGuid();
            var job = CreateBaseJob(
                generationId,
                TemplateGenerationService.AdminTestUserId,
                template,
                TemplateGenerationStatus.Queued,
                $"{scenario}:{i + 1}",
                tokenCost: 0,
                now.AddMilliseconds(i));
            job.QueueMediaType = mediaType;
            dbContext.TemplateGenerationJobs.Add(job);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return new QaGenerationWaitTooLongFixtureResponse(
            scenario,
            mediaType,
            template.Id,
            backlogCount,
            estimatedWaitSeconds,
            maxWaitSeconds,
            Math.Max(30, Math.Min(300, estimatedWaitSeconds / 2)),
            TemplatesErrors.GenerationWaitTooLong.Code);
    }

    private static TemplateGenerationJob CreateBaseJob(
        Guid generationId,
        Guid userId,
        TemplateItem template,
        TemplateGenerationStatus status,
        string scenario,
        int tokenCost,
        DateTime now)
    {
        return new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = template.Id,
            Template = template,
            Status = status,
            TokenCost = tokenCost,
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = userId == TemplateGenerationService.AdminTestUserId
                ? TemplateGenerationQueue.TierFree
                : TemplateGenerationQueue.TierPrivileged,
            InputSourceType = TemplateGenerationQaFixtures.InputSourceType,
            InputMediaAssetId = Guid.NewGuid(),
            SourceImageUrl = TemplateGenerationQaFixtures.SourceImageUrl,
            SourceImageFileName = TemplateGenerationQaFixtures.SourceImageFileName,
            SourceImageContentType = TemplateGenerationQaFixtures.SourceImageContentType,
            SourceImageFileSizeBytes = 68,
            ReferenceMotionUrl = template.Assets.FirstOrDefault(x => x.AssetKind == TemplateAssetKind.ReferenceMotion)?.Url,
            IdempotencyKey = $"{TemplateGenerationQaFixtures.RequestHashPrefix}{scenario}:{generationId:N}",
            RequestHash = $"{TemplateGenerationQaFixtures.RequestHashPrefix}{scenario}:{generationId:N}",
            CorrelationId = CorrelationContext.ResolveOrCreate(),
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            EstimatedWaitSecondsAtQueue = 0,
            EstimatedCompletionAtQueueUtc = now
        };
    }

    private static TemplateMediaRecord CreateSourceMediaRecord(TemplateGenerationJob job, DateTime now)
    {
        return new TemplateMediaRecord
        {
            Id = job.InputMediaAssetId!.Value,
            UserId = job.UserId,
            MediaType = TemplateGenerationQueue.MediaTypeImage,
            StoragePath = TemplateGenerationQaFixtures.SourceImageUrl,
            PreviewUrl = TemplateGenerationQaFixtures.SourceImageUrl,
            SourceType = TemplateGenerationQaFixtures.InputSourceType,
            GenerationId = job.Id,
            Url = TemplateGenerationQaFixtures.SourceImageUrl,
            FileName = TemplateGenerationQaFixtures.SourceImageFileName,
            ContentType = TemplateGenerationQaFixtures.SourceImageContentType,
            FileSizeBytes = job.SourceImageFileSizeBytes,
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            GenerationJobId = job.Id,
            UploadedAtUtc = now,
            AttachedAtUtc = now,
            IsDeleted = false
        };
    }

    private static void ApplyStatusDetails(TemplateGenerationJob job, TemplateGenerationStatus status, DateTime now)
    {
        if (status != TemplateGenerationStatus.Queued)
        {
            job.StartedAtUtc = now.AddSeconds(-30);
            job.ProviderSubmittedAtUtc = now.AddSeconds(-25);
            job.ProviderStatusCheckedAtUtc = now.AddSeconds(-5);
            job.CurrentProviderStage = job.Template.TemplateType == TemplateType.Video
                ? "video_generation"
                : "image_generation";
            job.ProviderStatus = status == TemplateGenerationStatus.ProviderQueued ? "IN_QUEUE" : "IN_PROGRESS";
        }

        if (status == TemplateGenerationStatus.ProviderQueued)
        {
            job.MotionProviderRequestId = $"qa-provider-queued-{job.Id:N}";
            return;
        }

        if (status == TemplateGenerationStatus.ProviderProcessing)
        {
            job.MotionProviderRequestId = $"qa-provider-processing-{job.Id:N}";
            return;
        }

        if (status == TemplateGenerationStatus.ImportingMedia)
        {
            job.MotionProviderRequestId = $"qa-importing-{job.Id:N}";
            job.ProviderCompletedAtUtc = now.AddSeconds(-3);
            job.ImportStartedAtUtc = now.AddSeconds(-2);
            job.ProviderResultUrl = "https://qa-fixtures.petmagic.local/generated.mp4";
            job.ProviderStatus = "COMPLETED";
            return;
        }

        if (status == TemplateGenerationStatus.Failed)
        {
            job.StartedAtUtc = now.AddSeconds(-30);
            job.CompletedAtUtc = now;
            job.LastErrorCode = TemplatesErrors.AiProviderFailed.Code;
            job.LastErrorMessage = "Generation failed in a QA fixture.";
        }
    }

    private async Task<Result<RequiredTemplates>> LoadRequiredTemplatesAsync(
        CreateQaGenerationFixturesCommand command,
        IReadOnlyCollection<string> scenarios,
        CancellationToken cancellationToken)
    {
        var needsImage = scenarios.Any(x => x is "queued" or "failed" or "waitTooLongImage");
        var needsVideo = scenarios.Any(x => x is "providerQueued" or "providerProcessing" or "importingMedia" or "waitTooLongVideo");
        var imageTemplate = needsImage
            ? await LoadTemplateAsync(command.ImageTemplateId, TemplateType.Image, cancellationToken)
            : null;
        if (needsImage && imageTemplate is null)
        {
            return Result.Failure<RequiredTemplates>(TemplatesErrors.NotFound);
        }

        var videoTemplate = needsVideo
            ? await LoadTemplateAsync(command.VideoTemplateId, TemplateType.Video, cancellationToken)
            : null;
        if (needsVideo && videoTemplate is null)
        {
            return Result.Failure<RequiredTemplates>(TemplatesErrors.NotFound);
        }

        return Result.Success(new RequiredTemplates(imageTemplate!, videoTemplate!));
    }

    private Task<TemplateItem?> LoadTemplateAsync(
        Guid? templateId,
        TemplateType templateType,
        CancellationToken cancellationToken)
    {
        if (templateId is null || templateId.Value == Guid.Empty)
        {
            return dbContext.TemplateItems
                .Include(x => x.Assets)
                // TemplateVisibilityPolicy direct-check allowlist: QA fixture selection intentionally chooses
                // active, non-deleted seed candidates outside public traffic.
                .Where(x => x.TemplateType == templateType && x.Status == TemplateStatus.Active && x.DeletedAtUtc == null)
                .OrderByDescending(x => x.UpdatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }

        return dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(
                x => x.Id == templateId.Value
                    && x.TemplateType == templateType
                    // TemplateVisibilityPolicy direct-check allowlist: explicit QA fixture ids are still constrained
                    // to active, non-deleted templates without using the public visibility pipeline.
                    && x.Status == TemplateStatus.Active
                    && x.DeletedAtUtc == null,
                cancellationToken);
    }

    private static string[] NormalizeScenarios(string[]? scenarios)
    {
        if (scenarios is not { Length: > 0 })
        {
            return DefaultScenarios;
        }

        return scenarios
            .Select(x => x.Trim())
            .Where(x => x.Length > 0)
            .Select(NormalizeScenario)
            .Where(x => x is not null)
            .Cast<string>()
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    private static string? NormalizeScenario(string value)
    {
        return value.Replace("-", string.Empty, StringComparison.Ordinal).Replace("_", string.Empty, StringComparison.Ordinal).ToLowerInvariant() switch
        {
            "queued" or "queuedonly" => "queued",
            "providerqueued" => "providerQueued",
            "providerprocessing" => "providerProcessing",
            "importingmedia" or "importing" => "importingMedia",
            "failed" => "failed",
            "waittoolongimage" or "imagewaittoolong" => "waitTooLongImage",
            "waittoolongvideo" or "videowaittoolong" => "waitTooLongVideo",
            _ => null
        };
    }

    private int ResolveMaxEstimatedWaitSeconds(string mediaType, string tier)
    {
        var normalizedMediaType = TemplateGenerationQueue.NormalizeMediaType(mediaType);
        return TemplateGenerationQueue.NormalizeTier(tier) switch
        {
            TemplateGenerationQueue.TierAdmin => int.MaxValue,
            TemplateGenerationQueue.TierPrivileged => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.PrivilegedVideoMaxEstimatedWaitSeconds
                : options.PrivilegedImageMaxEstimatedWaitSeconds,
            TemplateGenerationQueue.TierPremium => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.PremiumVideoMaxEstimatedWaitSeconds
                : options.PremiumImageMaxEstimatedWaitSeconds,
            _ => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.FreeVideoMaxEstimatedWaitSeconds
                : options.FreeImageMaxEstimatedWaitSeconds
        };
    }

    private int ResolveVideoReservedConcurrency()
    {
        return options.VideoReservedConcurrentGenerations > 0
            ? options.VideoReservedConcurrentGenerations
            : options.VideoMaxConcurrentGenerations;
    }

    private sealed record RequiredTemplates(TemplateItem ImageTemplate, TemplateItem VideoTemplate);
}
