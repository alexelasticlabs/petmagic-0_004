using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
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
        var mediaStorage = new RecordingMediaStorage(signReadUrls: true);
        var service = CreateService(dbContext, mediaStorage);

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
        var recent = await service.GetAdminRecentGenerationsAsync(created.Value.TemplateId, 3, CancellationToken.None);
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
        Assert.Equal(3, recent.Value.Count);
        Assert.Equal(TemplateGenerationStatus.Queued.ToString(), recent.Value[0].Status);
        Assert.Equal(failedId, recent.Value[1].GenerationId);
        Assert.Equal(2, recent.Value[1].AttemptCount);
        Assert.Equal("Completed", recent.Value[2].Status);
        Assert.Equal("https://cdn.example.com/output-1.mp4?signed=1", recent.Value[2].OutputUrl);
        Assert.Contains("https://cdn.example.com/output-1.mp4", mediaStorage.ReadUrls);

        Assert.True(failures.IsSuccess);
        var failure = Assert.Single(failures.Value);
        Assert.Equal("templates.ai_provider_failed", failure.FailureCode);
        Assert.Equal(1, failure.Count);
        Assert.Equal(now.AddMinutes(-6), failure.LastOccurredAtUtc);
    }

    [Fact]
    public async Task GetAdminAnalyticsAsync_ShouldNotExposeRawGenerationUrls_WhenSigningFails()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext, new FailingReadMediaStorage());

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Private Analytics Portrait",
                "Template with private output",
                "Portrait",
                ["analytics"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/private-preview.jpg", "private-preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "keep pet",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var generationId = Guid.NewGuid();
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = generationId,
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "templates-media/private/source.jpg",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                ResultUrl = "templates-media/private/result.png",
                CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2),
                QueuedAtUtc = DateTime.UtcNow.AddMinutes(-2),
                CompletedAtUtc = DateTime.UtcNow.AddMinutes(-1),
                UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-1)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = TemplateGenerationService.AdminTestUserId,
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 0,
                SourceImageUrl = "templates-media/private/admin-source.jpg",
                SourceImageFileName = "admin-source.jpg",
                SourceImageContentType = "image/jpeg",
                ResultUrl = "templates-media/private/admin-result.png",
                CreatedAtUtc = DateTime.UtcNow.AddMinutes(-3),
                QueuedAtUtc = DateTime.UtcNow.AddMinutes(-3),
                CompletedAtUtc = DateTime.UtcNow.AddMinutes(-2),
                UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-2)
            });
        await dbContext.SaveChangesAsync();

        var recent = await service.GetAdminRecentGenerationsAsync(created.Value.TemplateId, 10, CancellationToken.None);
        var testHistory = await service.GetAdminTestHistoryAsync(created.Value.TemplateId, 10, CancellationToken.None);

        Assert.True(recent.IsSuccess);
        Assert.Null(recent.Value.Single(x => x.GenerationId == generationId).OutputUrl);
        Assert.True(testHistory.IsSuccess);
        var adminTest = Assert.Single(testHistory.Value);
        Assert.Null(adminTest.OutputUrl);
        Assert.Null(adminTest.SourceImageAsset);
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
    public async Task RecordAnalyticsEventAsync_ShouldPersistTemplateOfTheDayLifecycleEventsWithMetadata()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Daily Analytics",
                "Template of the Day analytics",
                "Portrait",
                ["daily"],
                true,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/daily-analytics.jpg", "daily-analytics.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "keep pet",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var now = new DateTime(2026, 6, 14, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = created.Value.TemplateId,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/daily-source.jpg",
            SourceImageFileName = "daily-source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "https://cdn.example.com/daily-result.jpg",
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            StartedAtUtc = now.AddMinutes(1),
            CompletedAtUtc = now.AddMinutes(3),
            UpdatedAtUtc = now.AddMinutes(3)
        });
        await dbContext.SaveChangesAsync();

        var eventTypes = new[]
        {
            TemplateAnalyticsEventTypes.TemplateOfTheDayViewed,
            TemplateAnalyticsEventTypes.TemplateOfTheDayClicked,
            TemplateAnalyticsEventTypes.TemplateOfTheDayOpened,
            TemplateAnalyticsEventTypes.GenerationStarted,
            TemplateAnalyticsEventTypes.GenerationCompleted,
            TemplateAnalyticsEventTypes.GenerationFailed
        };

        foreach (var eventType in eventTypes)
        {
            var result = await service.RecordAnalyticsEventAsync(
                new RecordTemplateAnalyticsEventCommand(
                    created.Value.TemplateId,
                    eventType,
                    "manual",
                    "ios",
                    "us",
                    userId,
                    generationId,
                    MetadataJson: """
                    {"templateId":"daily-template","type":"image","source":"manual","isPremium":true,"userPlan":"premium","date":"2026-06-14","screen":"templates"}
                    """),
                CancellationToken.None);

            Assert.True(result.IsSuccess);
        }

        var stored = await dbContext.TemplateAnalyticsEvents
            .Where(item => item.TemplateId == created.Value.TemplateId)
            .OrderBy(item => item.CreatedAtUtc)
            .ToArrayAsync();

        Assert.Equal(eventTypes, stored.Select(item => item.EventType));
        Assert.All(stored, item =>
        {
            Assert.Equal("manual", item.Source);
            Assert.Equal(generationId, item.GenerationId);
            Assert.NotNull(item.MetadataJson);
            Assert.Contains("\"screen\":\"templates\"", item.MetadataJson);
            Assert.Contains("\"date\":\"2026-06-14\"", item.MetadataJson);
        });
    }

    [Fact]
    public async Task RecordAnalyticsEventAsync_ShouldIgnoreGenerationIdThatDoesNotMatchTemplateOrUser()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Analytics Ownership",
                "Template with generation ownership checks",
                "Portrait",
                ["analytics"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/ownership.jpg", "ownership.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "keep pet",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var ownerUserId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var now = new DateTime(2026, 6, 14, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = ownerUserId,
            TemplateId = created.Value.TemplateId,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/owner-source.jpg",
            SourceImageFileName = "owner-source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "https://cdn.example.com/owner-result.jpg",
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            StartedAtUtc = now.AddMinutes(1),
            CompletedAtUtc = now.AddMinutes(3),
            UpdatedAtUtc = now.AddMinutes(3)
        });
        await dbContext.SaveChangesAsync();

        var result = await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                created.Value.TemplateId,
                TemplateAnalyticsEventTypes.Feedback,
                "gallery",
                "ios",
                "us",
                otherUserId,
                generationId,
                "feedback for unrelated generation"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var stored = await dbContext.TemplateAnalyticsEvents.SingleAsync();
        Assert.Null(stored.GenerationId);
        Assert.Equal(otherUserId, stored.UserId);
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
    public async Task AdminModerationQueue_ShouldListAndDecideItemsWithAudit()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Moderated Template",
                "Template with moderation events",
                "Dance",
                ["moderation"],
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

        var userId = Guid.NewGuid();
        await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                created.Value.TemplateId,
                "complaint",
                "profile",
                "web",
                "us",
                userId,
                null,
                "Unsafe result"),
            CancellationToken.None);

        var queue = await service.GetAdminModerationQueueAsync(
            new AdminModerationQueueQuery("pending", "unsafe", 0, 10),
            CancellationToken.None);

        Assert.True(queue.IsSuccess);
        var item = Assert.Single(queue.Value.Items);
        Assert.Equal(1, queue.Value.TotalCount);
        Assert.Equal("pending", item.Status);
        Assert.Equal("Unsafe result", item.Message);

        var decided = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(item.EventId, "reject", "Policy violation"),
            CancellationToken.None);

        Assert.True(decided.IsSuccess);
        Assert.Equal("rejected", decided.Value.Status);
        Assert.Equal("Policy violation", decided.Value.ModerationComment);
        var audit = Assert.Single(auditLog.Entries, entry => entry.Action == "admin.content.rejected");
        Assert.Equal("admin.content.rejected", audit.Action);
        Assert.Equal("template_analytics_event", audit.TargetType);
        Assert.Equal(item.EventId.ToString("D"), audit.TargetId);
        Assert.Equal(userId, audit.SubjectUserId);
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

    [Fact]
    public async Task GetAdminTemplatesAnalyticsAsync_ShouldNormalizeLegacyNullPreviewAssetFields()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Legacy Analytics Portrait",
                "Template with legacy analytics preview asset",
                "Portrait",
                ["analytics"],
                false,
                30,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/legacy-analytics.jpg", "legacy-analytics.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .SingleAsync(x => x.Id == created.Value.TemplateId);
        var previewAsset = Assert.Single(template.Assets, x => x.AssetKind == TemplateAssetKind.Preview);
        previewAsset.FileName = null!;
        previewAsset.ContentType = null!;
        await dbContext.SaveChangesAsync();

        var overview = await service.GetAdminTemplatesAnalyticsAsync(
            new AdminTemplatesAnalyticsQuery(null, null, null, null, null, "views", 10),
            CancellationToken.None);

        Assert.True(overview.IsSuccess);
        var row = Assert.Single(overview.Value.TopTemplates, x => x.TemplateId == created.Value.TemplateId);
        Assert.NotNull(row.PreviewAsset);
        Assert.Equal(string.Empty, row.PreviewAsset!.FileName);
        Assert.Equal(string.Empty, row.PreviewAsset!.ContentType);
    }


}
