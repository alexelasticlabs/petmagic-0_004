using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{

    [Fact]
    public async Task GetAdminStatisticsAsync_ShouldAggregateGenerationMetrics()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Stats Dance",
                "Template with generation history",
                "Dance",
                ["stats"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                ResultUrl = "https://cdn.example.com/output-1.mp4",
                MotionProviderCostUsd = 0.1200m,
                CreatedAtUtc = now.AddMinutes(-40),
                QueuedAtUtc = now.AddMinutes(-40),
                StartedAtUtc = now.AddMinutes(-39),
                CompletedAtUtc = now.AddMinutes(-36),
                UpdatedAtUtc = now.AddMinutes(-36)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                ResultUrl = "https://cdn.example.com/output-2.mp4",
                MotionProviderCostUsd = 0.1800m,
                CreatedAtUtc = now.AddMinutes(-24),
                QueuedAtUtc = now.AddMinutes(-24),
                StartedAtUtc = now.AddMinutes(-23),
                CompletedAtUtc = now.AddMinutes(-21),
                UpdatedAtUtc = now.AddMinutes(-21)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                LastErrorCode = "templates.ai_provider_failed",
                LastErrorMessage = "Provider failed",
                CreatedAtUtc = now.AddMinutes(-12),
                QueuedAtUtc = now.AddMinutes(-12),
                StartedAtUtc = now.AddMinutes(-11),
                CompletedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-4.jpg",
                SourceImageFileName = "source-4.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3)
            });
        await dbContext.SaveChangesAsync();

        var statistics = await service.GetAdminStatisticsAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(statistics.IsSuccess);
        Assert.Equal(created.Value.TemplateId, statistics.Value.TemplateId);
        Assert.Equal(4, statistics.Value.TotalRuns);
        Assert.Equal(1, statistics.Value.QueuedRuns);
        Assert.Equal(0, statistics.Value.ProcessingRuns);
        Assert.Equal(2, statistics.Value.CompletedRuns);
        Assert.Equal(1, statistics.Value.FailedRuns);
        Assert.Equal(50, statistics.Value.SuccessRatePercent);
        Assert.Equal(240, statistics.Value.TotalTokenCost);
        Assert.Equal(60, statistics.Value.AverageTokenCost);
        Assert.Equal(0.3000m, statistics.Value.TotalProviderCostUsd);
        Assert.Equal(0.1500m, statistics.Value.AverageProviderCostUsd);
        Assert.Equal(now.AddMinutes(-3), statistics.Value.LastRunAtUtc);
        Assert.Equal(now.AddMinutes(-21), statistics.Value.LastCompletedAtUtc);
        Assert.Equal(150, statistics.Value.AverageGenerationSeconds);
    }

    [Fact]
    public async Task GetAdminAnalyticsAsync_ShouldReturnTrendRecentRunsAndFailureBreakdown()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Dance",
                "Template with analytics history",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        var failedId = Guid.NewGuid();
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                ResultUrl = "https://cdn.example.com/output-1.mp4",
                UsedPreprocessingModel = "openai/gpt-image-2/edit",
                UsedKlingModel = "fal-ai/kling-video/v3/pro/motion-control",
                MotionProviderCostUsd = 0.2400m,
                CreatedAtUtc = now.AddDays(-1).AddMinutes(-40),
                QueuedAtUtc = now.AddDays(-1).AddMinutes(-40),
                StartedAtUtc = now.AddDays(-1).AddMinutes(-39),
                CompletedAtUtc = now.AddDays(-1).AddMinutes(-36),
                UpdatedAtUtc = now.AddDays(-1).AddMinutes(-36)
            },
            new TemplateGenerationJob
            {
                Id = failedId,
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                AttemptCount = 2,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                LastErrorCode = "templates.ai_provider_failed",
                LastErrorMessage = "Provider failed",
                MotionProviderCostUsd = 0.0600m,
                CreatedAtUtc = now.AddMinutes(-8),
                QueuedAtUtc = now.AddMinutes(-8),
                StartedAtUtc = now.AddMinutes(-7),
                CompletedAtUtc = now.AddMinutes(-6),
                UpdatedAtUtc = now.AddMinutes(-6)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3)
            });
        await dbContext.SaveChangesAsync();

        var trend = await service.GetAdminTrendAsync(created.Value.TemplateId, CancellationToken.None);
        var recent = await service.GetAdminRecentGenerationsAsync(created.Value.TemplateId, 2, CancellationToken.None);
        var failures = await service.GetAdminFailureBreakdownAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(trend.IsSuccess);
        Assert.Equal(2, trend.Value.Count);
        Assert.Equal(now.AddDays(-1).Date, trend.Value[0].DateUtc);
        Assert.Equal(1, trend.Value[0].CompletedRuns);
        Assert.Equal(0.2400m, trend.Value[0].TotalProviderCostUsd);
        Assert.Equal(now.Date, trend.Value[1].DateUtc);
        Assert.Equal(2, trend.Value[1].TotalRuns);
        Assert.Equal(1, trend.Value[1].QueuedRuns);
        Assert.Equal(1, trend.Value[1].FailedRuns);
        Assert.Equal(0.0600m, trend.Value[1].TotalProviderCostUsd);
        Assert.Equal(0, trend.Value[1].SuccessRatePercent);

        Assert.True(recent.IsSuccess);
        Assert.Equal(2, recent.Value.Count);
        Assert.Equal(TemplateGenerationStatus.Queued.ToString(), recent.Value[0].Status);
        Assert.Equal(failedId, recent.Value[1].GenerationId);
        Assert.Equal(2, recent.Value[1].AttemptCount);

        Assert.True(failures.IsSuccess);
        var failure = Assert.Single(failures.Value);
        Assert.Equal("templates.ai_provider_failed", failure.FailureCode);
        Assert.Equal(1, failure.Count);
        Assert.Equal(now.AddMinutes(-6), failure.LastOccurredAtUtc);
    }

    [Fact]
    public async Task GetAdminEventAnalyticsAsync_ShouldAggregateViewEventDimensions()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Events",
                "Template with tracked public events",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "home", "ios", "us", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "home", "android", "us", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "search", "web", "br", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "video_view", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null), CancellationToken.None);

        var analytics = await service.GetAdminEventAnalyticsAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(analytics.IsSuccess);
        Assert.Equal(3, analytics.Value.TotalViews);
        Assert.Equal(1, analytics.Value.TotalVideoViews);
        Assert.Equal(1, analytics.Value.TotalComplaints);

        var home = Assert.Single(analytics.Value.Sources, x => x.Key == "home");
        Assert.Equal(2, home.Count);
        Assert.Equal(66.7, home.SharePercent);

        Assert.Contains(analytics.Value.Devices, x => x.Key == "ios" && x.Count == 1);
        Assert.Contains(analytics.Value.Devices, x => x.Key == "android" && x.Count == 1);
        Assert.Contains(analytics.Value.Geography, x => x.Key == "us" && x.Label == "US" && x.Count == 2);
    }

    [Fact]
    public async Task GetAdminFeedbackAsync_ShouldReturnLatestComplaintAndFeedbackItems()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Feedback Events",
                "Template with user feedback",
                "Dance",
                ["feedback"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null, "Видео зависло на обработке"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid(), "Хочу больше вариантов музыки"), CancellationToken.None);

        var feedback = await service.GetAdminFeedbackAsync(created.Value.TemplateId, new AdminTemplateFeedbackQuery(null, null, 10), CancellationToken.None);

        Assert.True(feedback.IsSuccess);
        Assert.Equal(2, feedback.Value.Count);
        Assert.Contains(feedback.Value, x => x.EventType == "complaint" && x.FeedbackMessage == "Видео зависло на обработке");
        Assert.Contains(feedback.Value, x => x.EventType == "feedback" && x.FeedbackMessage == "Хочу больше вариантов музыки");
    }

    [Fact]
    public async Task GetAdminFeedbackAsync_ShouldFilterByTypeAndSearchMessage()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Feedback Filters",
                "Template with searchable feedback",
                "Dance",
                ["feedback"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null, "Видео зависло на обработке"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid(), "Хочу больше вариантов музыки"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "web", "us", Guid.NewGuid(), Guid.NewGuid(), "Нужен более быстрый рендер"), CancellationToken.None);

        var filtered = await service.GetAdminFeedbackAsync(
            created.Value.TemplateId,
            new AdminTemplateFeedbackQuery("feedback", "музыки", 10),
            CancellationToken.None);

        Assert.True(filtered.IsSuccess);
        var item = Assert.Single(filtered.Value);
        Assert.Equal("feedback", item.EventType);
        Assert.Equal("Хочу больше вариантов музыки", item.FeedbackMessage);
    }

    [Fact]
    public async Task GetAdminTemplatesAnalyticsAsync_ShouldAggregateTemplatesJobsEventsAndCosts()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var video = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Dance",
                "Template with global analytics",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);
        var image = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait Magic",
                "Image analytics template",
                "Portrait",
                ["analytics"],
                true,
                30,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait.jpg", "portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(video.IsSuccess);
        Assert.True(image.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = video.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                ResultUrl = "https://cdn.example.com/output.mp4",
                MotionProviderCostUsd = 0.5000m,
                CreatedAtUtc = now.AddDays(-1),
                QueuedAtUtc = now.AddDays(-1),
                StartedAtUtc = now.AddDays(-1).AddMinutes(1),
                CompletedAtUtc = now.AddDays(-1).AddMinutes(4),
                UpdatedAtUtc = now.AddDays(-1).AddMinutes(4)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = video.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                LastErrorCode = "templates.ai_provider_failed",
                MotionProviderCostUsd = 0.1200m,
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                StartedAtUtc = now.AddMinutes(1),
                CompletedAtUtc = now.AddMinutes(2),
                UpdatedAtUtc = now.AddMinutes(2)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = image.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 30,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                StartedAtUtc = now.AddMinutes(1),
                CompletedAtUtc = now.AddMinutes(2),
                UpdatedAtUtc = now.AddMinutes(2)
            });
        dbContext.TemplateAnalyticsEvents.AddRange(
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "view", Source = "home", DeviceClass = "ios", CountryCode = "US", CreatedAtUtc = now.AddDays(-1) },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "view", Source = "search", DeviceClass = "web", CountryCode = "US", CreatedAtUtc = now },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = image.Value.TemplateId, EventType = "view", Source = "home", DeviceClass = "android", CountryCode = "BR", CreatedAtUtc = now },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "complaint", Source = "profile", DeviceClass = "web", CountryCode = "US", CreatedAtUtc = now });
        await dbContext.SaveChangesAsync();

        var overview = await service.GetAdminTemplatesAnalyticsAsync(new AdminTemplatesAnalyticsQuery(null, null, null, null, null, "views", 10), CancellationToken.None);

        Assert.True(overview.IsSuccess);
        Assert.Equal(2, overview.Value.Summary.TotalTemplates);
        Assert.Equal(1, overview.Value.Summary.VideoTemplates);
        Assert.Equal(1, overview.Value.Summary.ImageTemplates);
        Assert.Equal(3, overview.Value.Summary.TotalViews);
        Assert.Equal(3, overview.Value.Summary.TotalGenerationStarts);
        Assert.Equal(2, overview.Value.Summary.CompletedGenerations);
        Assert.Equal(1, overview.Value.Summary.FailedGenerations);
        Assert.Equal(66.7, overview.Value.Summary.ConversionPercent);
        Assert.Equal(150, overview.Value.Summary.TotalTokenCost);
        Assert.Equal(0.6200m, overview.Value.Summary.TotalProviderCostUsd);
        Assert.Equal(1, overview.Value.Summary.TotalComplaints);
        Assert.Equal(video.Value.TemplateId, overview.Value.TopTemplates[0].TemplateId);
        Assert.Contains(overview.Value.Categories, x => x.Key == "dance" && x.Views == 2 && x.GenerationStarts == 2);
        Assert.Contains(overview.Value.TemplateTypes, x => x.Key == "video" && x.TemplateCount == 1 && x.TotalProviderCostUsd == 0.6200m);
        Assert.Contains(overview.Value.Sources, x => x.Key == "home" && x.Count == 2 && x.SharePercent == 66.7);
        Assert.Contains(overview.Value.Devices, x => x.Key == "ios" && x.Count == 1);
        Assert.Contains(overview.Value.Geography, x => x.Key == "us" && x.Count == 2);
        Assert.Equal(2, overview.Value.TrendPoints.Count);
        Assert.Single(overview.Value.FeedbackItems);
        Assert.Equal("complaint", overview.Value.FeedbackItems[0].EventType);
        Assert.Contains("Dance", overview.Value.AvailableCategories);
        Assert.Contains("Portrait", overview.Value.AvailableCategories);
    }


}
