using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateFeedRealtimeServiceTests
{
    [Fact]
    public async Task Subscribe_ShouldReceivePersistedEvent_FromSeparateServiceInstance()
    {
        var databaseName = $"template-realtime-tests-{Guid.NewGuid():N}";
        var databaseRoot = new InMemoryDatabaseRoot();
        await using var publisherProvider = CreateProvider(databaseName, databaseRoot);
        await using var subscriberProvider = CreateProvider(databaseName, databaseRoot);

        var subscriber = subscriberProvider.GetRequiredService<ITemplateFeedRealtimeService>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        var subscription = subscriber.Subscribe(timeout.Token);

        var publisher = publisherProvider.GetRequiredService<ITemplateFeedRealtimeService>();
        var generation = new TemplateGenerationResponse(
            GenerationId: Guid.NewGuid(),
            UserId: Guid.NewGuid(),
            TemplateId: Guid.NewGuid(),
            Status: "Completed",
            TokenCost: 10,
            SourceImageAsset: null,
            NormalizedImageUrl: null,
            ReferenceMotionUrl: null,
            OutputUrl: "templates-media/output.png",
            AttemptCount: 1,
            UsedPreprocessingModel: null,
            UsedKlingModel: null,
            PreprocessingProviderRequestId: null,
            PreprocessingInferenceTimeSeconds: null,
            MotionProviderRequestId: null,
            MotionInferenceTimeSeconds: null,
            OutputVideoDurationSeconds: null,
            MotionProviderCostUsd: null,
            FailureCode: null,
            FailureMessage: null,
            CreatedAtUtc: DateTime.UtcNow.AddMinutes(-1),
            UpdatedAtUtc: DateTime.UtcNow,
            StartedAtUtc: null,
            PreprocessingCompletedAtUtc: null,
            MotionGenerationCompletedAtUtc: null,
            MediaImportCompletedAtUtc: null,
            CompletedAtUtc: DateTime.UtcNow,
            UserMediaExpired: false,
            TemplateTitle: "Template",
            TemplateType: "Image",
            Stage: "completed",
            ProgressPercent: 100,
            EstimatedDurationLabel: "Usually under 1 minute",
            ChargedAtUtc: DateTime.UtcNow.AddMinutes(-1),
            RefundedAtUtc: null,
            IsUnread: true,
            QueuePosition: null,
            EstimatedWaitSeconds: null,
            HasWatermark: false,
            CanRemoveWatermark: false,
            IsWatermarkRemoved: false,
            RemoveWatermarkCostCredits: 1,
            UserPlan: "free",
            WatermarkMessage: null,
            SupportsGenerateSimilar: false,
            ParentGenerationId: null,
            ParentGenerationResultId: null,
            SimilarToGenerationId: null,
            GenerationMode: "normal",
            VariationStrength: null,
            GenerationSeed: null,
            PromptBeforeVariation: null,
            PromptAfterVariation: null,
            InputSourceType: "user_upload",
            InputMediaAssetId: null,
            ResultMediaAssetId: null,
            InputPreviewUrl: null,
            ResultPreviewUrl: null,
            CanCompareBeforeAfter: false,
            PetId: null,
            PetPhotoId: null);

        await publisher.PublishGenerationStatusChangedAsync(generation, timeout.Token);

        var realtimeEvent = await ReadNextAsync(subscription, timeout.Token);

        Assert.Equal(TemplateFeedRealtimeTopics.GenerationStatusChanged, realtimeEvent.Topic);
        Assert.Contains(generation.GenerationId.ToString(), realtimeEvent.Data, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Publish_ShouldPruneExpiredPersistedEvents_BoundedByRetention()
    {
        var databaseName = $"template-realtime-cleanup-tests-{Guid.NewGuid():N}";
        var databaseRoot = new InMemoryDatabaseRoot();
        await using var provider = CreateProvider(
            databaseName,
            databaseRoot,
            realtimeEventRetentionMinutes: 1,
            realtimeEventCleanupIntervalMinutes: 1,
            realtimeEventCleanupBatchSize: 10);

        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRealtimeEvents.AddRange(
                new TemplateRealtimeEventRecord
                {
                    Id = Guid.NewGuid(),
                    Topic = TemplateFeedRealtimeTopics.TemplatesFeedInvalidated,
                    Data = "{}",
                    CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5)
                },
                new TemplateRealtimeEventRecord
                {
                    Id = Guid.NewGuid(),
                    Topic = TemplateFeedRealtimeTopics.GenerationStatusChanged,
                    Data = "{}",
                    CreatedAtUtc = DateTime.UtcNow
                });
            await dbContext.SaveChangesAsync();
        }

        var realtime = provider.GetRequiredService<ITemplateFeedRealtimeService>();
        await realtime.PublishTemplatesFeedInvalidatedAsync(CancellationToken.None);

        await using var verifyScope = provider.CreateAsyncScope();
        var verifyDbContext = verifyScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var remainingEvents = await verifyDbContext.TemplateRealtimeEvents
            .AsNoTracking()
            .OrderBy(x => x.CreatedAtUtc)
            .ToArrayAsync();

        Assert.DoesNotContain(remainingEvents, x => x.CreatedAtUtc < DateTime.UtcNow.AddMinutes(-1));
        Assert.Contains(remainingEvents, x => x.Topic == TemplateFeedRealtimeTopics.GenerationStatusChanged);
        Assert.Contains(remainingEvents, x => x.Topic == TemplateFeedRealtimeTopics.TemplatesFeedInvalidated);
    }

    [Fact]
    public async Task Subscribe_ShouldNotSkipPersistedEvents_WhenTimestampBatchExceedsPageSize()
    {
        var databaseName = $"template-realtime-cursor-tests-{Guid.NewGuid():N}";
        var databaseRoot = new InMemoryDatabaseRoot();
        await using var provider = CreateProvider(databaseName, databaseRoot);

        var realtime = provider.GetRequiredService<ITemplateFeedRealtimeService>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var subscription = realtime.Subscribe(timeout.Token);

        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var createdAtUtc = DateTime.UtcNow.AddSeconds(1);
            for (var i = 0; i < 150; i++)
            {
                dbContext.TemplateRealtimeEvents.Add(new TemplateRealtimeEventRecord
                {
                    Id = Guid.NewGuid(),
                    Topic = TemplateFeedRealtimeTopics.GenerationStatusChanged,
                    Data = $$"""{"index":{{i}}}""",
                    CreatedAtUtc = createdAtUtc
                });
            }

            await dbContext.SaveChangesAsync(timeout.Token);
        }

        var received = new List<TemplateFeedRealtimeEvent>();
        while (received.Count < 150)
        {
            received.Add(await ReadNextAsync(subscription, timeout.Token));
        }

        Assert.Equal(150, received.Count(x => x.Topic == TemplateFeedRealtimeTopics.GenerationStatusChanged));
    }

    [Fact]
    public async Task PublishTemplatesFeedInvalidatedAsync_ShouldStillDeliverToSubscribers_WhenCallerTokenIsCanceled()
    {
        var databaseName = $"template-realtime-canceled-publish-{Guid.NewGuid():N}";
        var databaseRoot = new InMemoryDatabaseRoot();
        await using var provider = CreateProvider(databaseName, databaseRoot);

        var realtime = provider.GetRequiredService<ITemplateFeedRealtimeService>();
        using var subscriptionTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        var subscription = realtime.Subscribe(subscriptionTimeout.Token);

        using var canceledPublish = new CancellationTokenSource();
        canceledPublish.Cancel();

        await realtime.PublishTemplatesFeedInvalidatedAsync(canceledPublish.Token);

        var realtimeEvent = await ReadNextAsync(subscription, subscriptionTimeout.Token);
        Assert.Equal(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated, realtimeEvent.Topic);

        await using var verifyScope = provider.CreateAsyncScope();
        var dbContext = verifyScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        Assert.Contains(
            await dbContext.TemplateRealtimeEvents.AsNoTracking().ToArrayAsync(),
            x => x.Topic == TemplateFeedRealtimeTopics.TemplatesFeedInvalidated);
    }

    private static ServiceProvider CreateProvider(
        string databaseName,
        InMemoryDatabaseRoot databaseRoot,
        int realtimeEventRetentionMinutes = 60,
        int realtimeEventCleanupIntervalMinutes = 10,
        int realtimeEventCleanupBatchSize = 1_000)
    {
        var services = new ServiceCollection();
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName, databaseRoot));
        services.AddSingleton(new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "image",
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "video",
            AllowedImageModels = ["model"],
            AllowedPreprocessingModels = ["model"],
            AllowedKlingModels = ["model"],
            SupportedLocalizationLocales = ["en"],
            RealtimePollingIntervalMilliseconds = 50,
            RealtimeEventRetentionMinutes = realtimeEventRetentionMinutes,
            RealtimeEventCleanupIntervalMinutes = realtimeEventCleanupIntervalMinutes,
            RealtimeEventCleanupBatchSize = realtimeEventCleanupBatchSize
        });
        services.AddSingleton(NullLogger<TemplateFeedRealtimeService>.Instance);
        services.AddSingleton(typeof(ILogger<>), typeof(NullLogger<>));
        services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
        return services.BuildServiceProvider();
    }

    private static async Task<TemplateFeedRealtimeEvent> ReadNextAsync(
        ChannelReader<TemplateFeedRealtimeEvent> reader,
        CancellationToken cancellationToken)
    {
        while (await reader.WaitToReadAsync(cancellationToken))
        {
            if (reader.TryRead(out var realtimeEvent))
            {
                return realtimeEvent;
            }
        }

        throw new InvalidOperationException("Realtime subscription closed before an event arrived.");
    }
}
