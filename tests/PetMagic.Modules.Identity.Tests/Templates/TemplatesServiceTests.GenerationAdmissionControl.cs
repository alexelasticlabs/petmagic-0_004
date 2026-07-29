using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task StartAdminTestAsync_ShouldRejectPausedAdmissionWithoutCreatingJob()
    {
        await using var dbContext = CreateDbContext();
        var templatesService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            templatesService,
            "Paused Admin Portrait",
            "Portrait",
            ["admin-pause"]);
        var providerHealth = new AdmissionCapturingProviderHealthService(
            Result.Failure(TemplatesErrors.ProviderCapacityUnavailable));
        var generationService = CreateGenerationService(
            dbContext,
            aiProviderHealthService: providerHealth);

        var result = await generationService.StartAdminTestAsync(
            templateId,
            CreateAdminSourceAsset(),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.Equal(TemplateGenerationQueue.TierAdmin, providerHealth.LastTier);
        Assert.Empty(await dbContext.TemplateGenerationJobs.ToArrayAsync());
    }

    [Fact]
    public async Task StartAdminTestAsync_ShouldRejectWhenGlobalQueueIsFull()
    {
        await using var dbContext = CreateDbContext();
        var templatesService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            templatesService,
            "Admin Queue Portrait",
            "Portrait",
            ["admin-queue"]);
        var providerHealth = new AdmissionCapturingProviderHealthService(Result.Success());
        var generationService = CreateGenerationService(
            dbContext,
            CreateTemplatesOptions(queueMaxSize: 1),
            aiProviderHealthService: providerHealth);

        var first = await generationService.StartAdminTestAsync(
            templateId,
            CreateAdminSourceAsset(),
            CancellationToken.None);
        var second = await generationService.StartAdminTestAsync(
            templateId,
            CreateAdminSourceAsset(),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationQueueOverloaded.Code, second.Error.Code);
        Assert.Single(await dbContext.TemplateGenerationJobs.ToArrayAsync());
        Assert.Equal(1, providerHealth.CheckCount);
    }

    [Fact]
    public async Task RetryAdminGenerationAsync_ShouldRejectPausedAdmissionWithoutMutatingTerminalJob()
    {
        await using var dbContext = CreateDbContext();
        var templatesService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            templatesService,
            "Paused Retry Portrait",
            "Portrait",
            ["retry-pause"]);
        var target = CreateRetryableFailedGeneration(templateId, TemplateGenerationQueue.TierFree);
        dbContext.TemplateGenerationJobs.Add(target);
        await dbContext.SaveChangesAsync();

        var providerHealth = new AdmissionCapturingProviderHealthService(
            Result.Failure(TemplatesErrors.ProviderCapacityUnavailable));
        var generationService = CreateGenerationService(
            dbContext,
            aiProviderHealthService: providerHealth);

        var result = await generationService.RetryAdminGenerationAsync(
            Guid.NewGuid(),
            target.Id,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.Equal(TemplateGenerationQueue.TierAdmin, providerHealth.LastTier);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == target.Id);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Equal(TemplateGenerationQueue.TierFree, persisted.QueueTier);
    }

    [Fact]
    public async Task RetryAdminGenerationAsync_ShouldRejectWhenGlobalQueueIsFull()
    {
        await using var dbContext = CreateDbContext();
        var templatesService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            templatesService,
            "Queue Retry Portrait",
            "Portrait",
            ["retry-queue"]);
        var target = CreateRetryableFailedGeneration(templateId, TemplateGenerationQueue.TierFree);
        var active = CreateRetryableFailedGeneration(templateId, TemplateGenerationQueue.TierPremium);
        active.Id = Guid.NewGuid();
        active.UserId = Guid.NewGuid();
        active.Status = TemplateGenerationStatus.Queued;
        active.QueuedAtUtc = DateTime.UtcNow.AddMinutes(-1);
        dbContext.TemplateGenerationJobs.AddRange(target, active);
        await dbContext.SaveChangesAsync();

        var providerHealth = new AdmissionCapturingProviderHealthService(Result.Success());
        var generationService = CreateGenerationService(
            dbContext,
            CreateTemplatesOptions(queueMaxSize: 1),
            aiProviderHealthService: providerHealth);

        var result = await generationService.RetryAdminGenerationAsync(
            Guid.NewGuid(),
            target.Id,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationQueueOverloaded.Code, result.Error.Code);
        Assert.Equal(0, providerHealth.CheckCount);
        Assert.Equal(
            TemplateGenerationStatus.Failed,
            (await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == target.Id)).Status);
    }

    [Fact]
    public async Task RetryAdminGenerationAsync_ShouldRequeueUsingAdminTier()
    {
        await using var dbContext = CreateDbContext();
        var templatesService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            templatesService,
            "Admin Tier Retry Portrait",
            "Portrait",
            ["retry-tier"]);
        var target = CreateRetryableFailedGeneration(templateId, TemplateGenerationQueue.TierFree);
        dbContext.TemplateGenerationJobs.Add(target);
        await dbContext.SaveChangesAsync();

        var providerHealth = new AdmissionCapturingProviderHealthService(Result.Success());
        var generationService = CreateGenerationService(
            dbContext,
            aiProviderHealthService: providerHealth);

        var result = await generationService.RetryAdminGenerationAsync(
            Guid.NewGuid(),
            target.Id,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(TemplateGenerationQueue.TierAdmin, providerHealth.LastTier);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == target.Id);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);
        Assert.Equal(TemplateGenerationQueue.TierAdmin, persisted.QueueTier);
        Assert.NotNull(persisted.EstimatedCompletionAtQueueUtc);
    }

    private static TemplateAssetCommand CreateAdminSourceAsset() => new(
        "https://cdn.example.com/admin-source.jpg",
        "admin-source.jpg",
        "image/jpeg",
        2_048,
        null);

    private static TemplateGenerationJob CreateRetryableFailedGeneration(Guid templateId, string queueTier)
    {
        var now = DateTime.UtcNow;
        return new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Status = TemplateGenerationStatus.Failed,
            TokenCost = 20,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = queueTier,
            SourceImageUrl = "https://cdn.example.com/retry-source.jpg",
            SourceImageFileName = "retry-source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 2_048,
            CreatedAtUtc = now.AddMinutes(-10),
            QueuedAtUtc = now.AddMinutes(-10),
            UpdatedAtUtc = now,
            CompletedAtUtc = now,
            ChargedAtUtc = now.AddMinutes(-9),
            AttemptCount = 3,
            LastErrorCode = TemplatesErrors.AiProviderFailed.Code
        };
    }

    private sealed class AdmissionCapturingProviderHealthService(Result result)
        : ITemplateAiProviderHealthService
    {
        public int CheckCount { get; private set; }

        public string? LastTier { get; private set; }

        public Task<Result> EnsureCanAcceptGenerationAsync(
            string mediaType,
            string tier,
            CancellationToken cancellationToken)
        {
            CheckCount++;
            LastTier = tier;
            return Task.FromResult(result);
        }
    }
}
