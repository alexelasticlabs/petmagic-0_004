using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task GenerationStatusContract_ShouldReturnNamedStatusesAcrossStatusHistoryAndRealtime()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Status Contract Portrait",
            "Portrait",
            ["status-contract"]);
        var now = DateTime.UtcNow;
        var expectedStatuses = new (TemplateGenerationStatus StoredStatus, string ApiStatus)[]
        {
            (TemplateGenerationStatus.Queued, "Queued"),
            (TemplateGenerationStatus.ProviderQueued, "ProviderQueued"),
            (TemplateGenerationStatus.ProviderProcessing, "ProviderProcessing"),
            (TemplateGenerationStatus.ImportingMedia, "ImportingMedia"),
            (TemplateGenerationStatus.Completed, "Completed"),
            (TemplateGenerationStatus.Failed, "Failed"),
            (TemplateGenerationStatus.Cancelled, "Cancelled")
        };
        var generationIds = new Dictionary<string, Guid>(StringComparer.Ordinal);

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            foreach (var (storedStatus, apiStatus) in expectedStatuses)
            {
                var generationId = Guid.NewGuid();
                generationIds[apiStatus] = generationId;
                dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
                {
                    Id = generationId,
                    UserId = TestUserId,
                    TemplateId = created.TemplateId,
                    Status = storedStatus,
                    TokenCost = created.TokenCost,
                    SourceImageUrl = $"https://cdn.example.com/{apiStatus.ToLowerInvariant()}-source.jpg",
                    SourceImageFileName = $"{apiStatus.ToLowerInvariant()}-source.jpg",
                    SourceImageContentType = "image/jpeg",
                    SourceImageFileSizeBytes = 2048,
                    ResultUrl = storedStatus == TemplateGenerationStatus.Completed
                        ? $"https://cdn.example.com/{apiStatus.ToLowerInvariant()}-result.png"
                        : null,
                    AttemptCount = storedStatus == TemplateGenerationStatus.Failed ? 2 : 1,
                    LastErrorCode = storedStatus == TemplateGenerationStatus.Failed
                        ? "templates.ai_provider_failed"
                        : null,
                    LastErrorMessage = storedStatus == TemplateGenerationStatus.Failed
                        ? "Provider failed."
                        : null,
                    CreatedAtUtc = now.AddMinutes(-generationIds.Count - 1),
                    QueuedAtUtc = now.AddMinutes(-generationIds.Count - 1),
                    StartedAtUtc = storedStatus == TemplateGenerationStatus.Queued
                        ? null
                        : now.AddMinutes(-generationIds.Count),
                    CompletedAtUtc = storedStatus is TemplateGenerationStatus.Completed or TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled
                        ? now
                        : null,
                    UpdatedAtUtc = now,
                    ChargedAtUtc = now.AddMinutes(-generationIds.Count - 1),
                    QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                    QueueTier = TemplateGenerationQueue.TierFree
                });
            }

            await dbContext.SaveChangesAsync();
        }

        foreach (var (_, apiStatus) in expectedStatuses)
        {
            using var statusResponse = await application.Client.GetAsync($"/api/templates/generations/{generationIds[apiStatus]}");
            await EnsureSuccessStatusCodeAsync(statusResponse, $"/api/templates/generations/{generationIds[apiStatus]}");
            using var statusJson = JsonDocument.Parse(await statusResponse.Content.ReadAsStringAsync());

            Assert.Equal(JsonValueKind.String, statusJson.RootElement.GetProperty("status").ValueKind);
            Assert.Equal(apiStatus, statusJson.RootElement.GetProperty("status").GetString());
        }

        using (var historyResponse = await application.Client.GetAsync("/api/templates/generations?take=20"))
        {
            await EnsureSuccessStatusCodeAsync(historyResponse, "/api/templates/generations?take=20");
            using var historyJson = JsonDocument.Parse(await historyResponse.Content.ReadAsStringAsync());
            var statusByGenerationId = historyJson.RootElement
                .GetProperty("items")
                .EnumerateArray()
                .ToDictionary(
                    item => item.GetProperty("generationId").GetGuid(),
                    item => item.GetProperty("status"));

            foreach (var (_, apiStatus) in expectedStatuses)
            {
                var statusElement = statusByGenerationId[generationIds[apiStatus]];
                Assert.Equal(JsonValueKind.String, statusElement.ValueKind);
                Assert.Equal(apiStatus, statusElement.GetString());
            }
        }

        var realtime = application.Services.GetRequiredService<ITemplateFeedRealtimeService>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var subscription = realtime.Subscribe(timeout.Token);
        foreach (var (_, apiStatus) in expectedStatuses)
        {
            var generation = await GetFromJsonAsync<TemplateGenerationResponse>(
                application.Client,
                $"/api/templates/generations/{generationIds[apiStatus]}");
            await realtime.PublishGenerationStatusChangedAsync(generation);
        }

        var receivedEvents = new List<TemplateFeedRealtimeEvent>(expectedStatuses.Length);
        for (var index = 0; index < expectedStatuses.Length; index++)
        {
            Assert.True(await subscription.WaitToReadAsync(timeout.Token));
            Assert.True(subscription.TryRead(out var realtimeEvent));
            receivedEvents.Add(realtimeEvent);
        }

        var realtimeStatuses = receivedEvents.Select(realtimeEvent =>
        {
            Assert.Equal(TemplateFeedRealtimeTopics.GenerationStatusChanged, realtimeEvent.Topic);
            using var eventJson = JsonDocument.Parse(realtimeEvent.Data);
            var statusElement = eventJson.RootElement.GetProperty("status");
            Assert.Equal(JsonValueKind.String, statusElement.ValueKind);
            return statusElement.GetString();
        });

        Assert.Equal(
            expectedStatuses.Select(x => x.ApiStatus).OrderBy(status => status, StringComparer.Ordinal),
            realtimeStatuses.OrderBy(status => status, StringComparer.Ordinal));
    }

    [Fact]
    public async Task GenerationUserEndpoints_ShouldReturnNotFound_ForForeignGenerationId()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Ownership Contract Portrait",
            "Portrait",
            ["ownership-contract"]);
        var ownerUserId = TestUserId;
        var otherUserId = Guid.Parse("8DE72914-19F0-4C4C-9F55-C534DB8C0D7A");
        var generationId = Guid.NewGuid();
        var resultUrl = "http://localhost:5000/templates-media/foreign-result.png";
        var now = DateTime.UtcNow;

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
            {
                Id = generationId,
                UserId = ownerUserId,
                TemplateId = created.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = created.TokenCost,
                SourceImageUrl = "http://localhost:5000/templates-media/foreign-source.jpg",
                SourceImageFileName = "foreign-source.jpg",
                SourceImageContentType = "image/jpeg",
                SourceImageFileSizeBytes = 2048,
                ResultUrl = resultUrl,
                AttemptCount = 1,
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                StartedAtUtc = now.AddMinutes(-4),
                MediaImportCompletedAtUtc = now.AddMinutes(-1),
                CompletedAtUtc = now.AddMinutes(-1),
                UpdatedAtUtc = now.AddMinutes(-1),
                ChargedAtUtc = now.AddMinutes(-5),
                QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                QueueTier = TemplateGenerationQueue.TierFree
            });
            await dbContext.SaveChangesAsync();
        }

        application.Client.DefaultRequestHeaders.Remove("X-Test-UserId");
        application.Client.DefaultRequestHeaders.Add("X-Test-UserId", otherUserId.ToString());
        application.Client.DefaultRequestHeaders.Remove("X-Test-Role");
        application.Client.DefaultRequestHeaders.Add("X-Test-Role", "User");

        var endpoints = new (HttpMethod Method, string Path)[]
        {
            (HttpMethod.Get, $"/api/templates/generations/{generationId}"),
            (HttpMethod.Post, $"/api/templates/generations/{generationId}/mark-read"),
            (HttpMethod.Delete, $"/api/templates/generations/{generationId}"),
            (HttpMethod.Get, $"/api/templates/generations/{generationId}/download"),
            (HttpMethod.Post, $"/api/templates/generations/{generationId}/share")
        };

        foreach (var (method, path) in endpoints)
        {
            using var request = new HttpRequestMessage(method, path)
            {
                Content = method == HttpMethod.Post
                    ? new StringContent("{}", Encoding.UTF8, "application/json")
                    : null
            };
            using var response = await application.Client.SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();

            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
            Assert.DoesNotContain(resultUrl, body, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("mediaUrl", body, StringComparison.OrdinalIgnoreCase);
        }

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == generationId);
            Assert.Equal(ownerUserId, persisted.UserId);
            Assert.Null(persisted.ResultViewedAtUtc);
            Assert.Null(persisted.HiddenByUserAtUtc);
            Assert.Equal(resultUrl, persisted.ResultUrl);
        }
    }

    [Fact]
    public async Task GenerationGalleryList_ShouldUseStableCursorPagination()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Cursor Gallery Portrait",
            "Portrait",
            ["cursor-gallery"]);
        var otherUserId = Guid.Parse("5E1347E2-DA5C-40A7-B9B4-2D3F93B55A11");
        var sharedCreatedAt = DateTime.UtcNow.AddMinutes(-3);
        var olderCreatedAt = sharedCreatedAt.AddMinutes(-1);
        var newestId = Guid.Parse("FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFF0");
        var secondId = Guid.Parse("EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEE0");
        var thirdId = Guid.Parse("DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDD0");
        var fourthId = Guid.Parse("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCC0");
        var fifthId = Guid.Parse("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB0");
        var hiddenId = Guid.Parse("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA0");
        var foreignId = Guid.Parse("99999999-9999-9999-9999-999999999990");
        var failedId = Guid.Parse("88888888-8888-8888-8888-888888888880");

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateGenerationJobs.AddRange(
                CompletedJob(newestId, TestUserId, created.TemplateId, created.TokenCost, sharedCreatedAt, "newest"),
                CompletedJob(secondId, TestUserId, created.TemplateId, created.TokenCost, sharedCreatedAt, "second"),
                CompletedJob(thirdId, TestUserId, created.TemplateId, created.TokenCost, olderCreatedAt, "third"),
                CompletedJob(fourthId, TestUserId, created.TemplateId, created.TokenCost, olderCreatedAt.AddMinutes(-1), "fourth", viewed: false),
                CompletedJob(fifthId, TestUserId, created.TemplateId, created.TokenCost, olderCreatedAt.AddMinutes(-2), "fifth"),
                CompletedJob(hiddenId, TestUserId, created.TemplateId, created.TokenCost, olderCreatedAt.AddMinutes(-3), "hidden", hidden: true),
                CompletedJob(foreignId, otherUserId, created.TemplateId, created.TokenCost, sharedCreatedAt.AddMinutes(1), "foreign"),
                CompletedJob(failedId, TestUserId, created.TemplateId, created.TokenCost, sharedCreatedAt.AddMinutes(2), "failed", status: TemplateGenerationStatus.Failed));
            await dbContext.SaveChangesAsync();
        }

        var firstPage = await GetFromJsonAsync<GalleryPageResponse>(
            application.Client,
            "/api/templates/generations?status=completed&take=3");

        Assert.True(firstPage.HasMore);
        Assert.False(string.IsNullOrWhiteSpace(firstPage.NextCursor));
        Assert.Equal("completed", firstPage.AppliedFilter);
        Assert.Equal(1, firstPage.UnreadCount);
        Assert.Equal([newestId, secondId, thirdId], firstPage.Items.Select(x => x.GenerationId).ToArray());
        Assert.DoesNotContain(firstPage.Items, x => x.GenerationId == hiddenId);
        Assert.DoesNotContain(firstPage.Items, x => x.GenerationId == foreignId);
        Assert.DoesNotContain(firstPage.Items, x => x.GenerationId == failedId);

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateGenerationJobs.Add(
                CompletedJob(
                    Guid.Parse("77777777-7777-7777-7777-777777777770"),
                    TestUserId,
                    created.TemplateId,
                    created.TokenCost,
                    DateTime.UtcNow.AddMinutes(1),
                    "inserted-between-pages"));
            await dbContext.SaveChangesAsync();
        }

        var secondPage = await GetFromJsonAsync<GalleryPageResponse>(
            application.Client,
            $"/api/templates/generations?status=completed&take=3&cursor={Uri.EscapeDataString(firstPage.NextCursor!)}");

        Assert.False(secondPage.HasMore);
        Assert.Null(secondPage.NextCursor);
        Assert.Equal([fourthId, fifthId], secondPage.Items.Select(x => x.GenerationId).ToArray());
        Assert.Empty(secondPage.Items.Select(x => x.GenerationId).Intersect(firstPage.Items.Select(x => x.GenerationId)));
    }

    private static TemplateGenerationJob CompletedJob(
        Guid generationId,
        Guid userId,
        Guid templateId,
        int tokenCost,
        DateTime createdAtUtc,
        string slug,
        TemplateGenerationStatus status = TemplateGenerationStatus.Completed,
        bool hidden = false,
        bool viewed = true)
    {
        return new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = templateId,
            Status = status,
            TokenCost = tokenCost,
            SourceImageUrl = $"https://cdn.example.com/{slug}-source.jpg",
            SourceImageFileName = $"{slug}-source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 2048,
            ResultUrl = status == TemplateGenerationStatus.Completed
                ? $"https://cdn.example.com/{slug}-result.png"
                : null,
            AttemptCount = status == TemplateGenerationStatus.Failed ? 2 : 1,
            LastErrorCode = status == TemplateGenerationStatus.Failed
                ? "templates.ai_provider_failed"
                : null,
            LastErrorMessage = status == TemplateGenerationStatus.Failed
                ? "Provider failed."
                : null,
            CreatedAtUtc = createdAtUtc,
            QueuedAtUtc = createdAtUtc,
            StartedAtUtc = createdAtUtc.AddSeconds(10),
            MediaImportCompletedAtUtc = status == TemplateGenerationStatus.Completed
                ? createdAtUtc.AddSeconds(40)
                : null,
            CompletedAtUtc = status is TemplateGenerationStatus.Completed or TemplateGenerationStatus.Failed
                ? createdAtUtc.AddSeconds(45)
                : null,
            UpdatedAtUtc = createdAtUtc.AddSeconds(45),
            ChargedAtUtc = createdAtUtc,
            ResultViewedAtUtc = viewed ? createdAtUtc.AddSeconds(50) : null,
            HiddenByUserAtUtc = hidden ? createdAtUtc.AddSeconds(60) : null,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree
        };
    }

    [Fact]
    public async Task GenerationGalleryList_ShouldReturnExplicitMediaStates()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Media State Portrait",
            "Portrait",
            ["media-state-gallery"]);
        var now = DateTime.UtcNow.AddMinutes(-10);
        var resultReadyId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        var watermarkPreparingId = Guid.Parse("10000000-0000-0000-0000-000000000002");
        var expiredId = Guid.Parse("10000000-0000-0000-0000-000000000003");
        var storageUnavailableId = Guid.Parse("10000000-0000-0000-0000-000000000004");
        var previewOnlyId = Guid.Parse("10000000-0000-0000-0000-000000000005");
        var failedId = Guid.Parse("10000000-0000-0000-0000-000000000006");
        var unlockedId = Guid.Parse("10000000-0000-0000-0000-000000000007");

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var resultReady = CompletedJob(resultReadyId, TestUserId, created.TemplateId, created.TokenCost, now, "media-ready");
            var watermarkPreparing = CompletedJob(watermarkPreparingId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-1), "watermark-preparing");
            watermarkPreparing.IsWatermarkRequired = true;
            watermarkPreparing.WatermarkedResultUrl = null;
            var expired = CompletedJob(expiredId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-2), "media-expired");
            expired.UserMediaDeletedAtUtc = now.AddSeconds(30);
            var storageUnavailable = CompletedJob(storageUnavailableId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-3), "storage-unavailable");
            storageUnavailable.MediaRecords.Add(CreateResultMediaRecord(storageUnavailable, isDeleted: true));
            var previewOnly = CompletedJob(previewOnlyId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-4), "preview-only");
            previewOnly.ResultUrl = null;
            previewOnly.MediaRecords.Add(CreateResultMediaRecord(previewOnly, includeResult: false, includePreview: true));
            var failed = CompletedJob(failedId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-5), "media-failed", status: TemplateGenerationStatus.Failed);
            var unlocked = CompletedJob(unlockedId, TestUserId, created.TemplateId, created.TokenCost, now.AddSeconds(-6), "watermark-unlocked");
            unlocked.IsWatermarkRequired = true;
            unlocked.WatermarkedResultUrl = "https://cdn.example.com/watermark-unlocked-watermarked.png";

            dbContext.TemplateGenerationJobs.AddRange(
                resultReady,
                watermarkPreparing,
                expired,
                storageUnavailable,
                previewOnly,
                failed,
                unlocked);
            dbContext.TemplateGenerationWatermarkUnlocks.Add(new TemplateGenerationWatermarkUnlock
            {
                Id = Guid.Parse("20000000-0000-0000-0000-000000000001"),
                UserId = TestUserId,
                GenerationJobId = unlocked.Id,
                UnlockMethod = TemplateWatermarkUnlockMethod.Credit,
                CreditsSpent = 1,
                CreatedAtUtc = now
            });
            await dbContext.SaveChangesAsync();
        }

        GalleryPageResponse page;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var generationService = scope.ServiceProvider.GetRequiredService<ITemplateGenerationService>();
            var result = await generationService.ListPageAsync(
                TestUserId,
                new TemplateGenerationHistoryQuery(null, null, 20),
                isPremium: false,
                CancellationToken.None);
            Assert.True(result.IsSuccess, result.Error.Code);
            page = result.Value;
        }
        var byId = page.Items.ToDictionary(x => x.GenerationId);

        Assert.Equal(GalleryMediaState.resultReady, byId[resultReadyId].Media.State);
        Assert.True(byId[resultReadyId].Media.CanDownload);
        Assert.True(byId[resultReadyId].Media.CanShare);
        Assert.Equal(GalleryMediaState.watermarkPreparing, byId[watermarkPreparingId].Media.State);
        Assert.False(byId[watermarkPreparingId].Media.CanDownload);
        Assert.Equal(GalleryMediaState.expired, byId[expiredId].Media.State);
        Assert.Equal("gallery.media.expired", byId[expiredId].Media.UserMessageKey);
        Assert.Equal(GalleryMediaState.storageUnavailable, byId[storageUnavailableId].Media.State);
        Assert.Equal(GalleryMediaState.previewReadyOnly, byId[previewOnlyId].Media.State);
        Assert.NotNull(byId[previewOnlyId].Media.PreviewUrl);
        Assert.Null(byId[previewOnlyId].Media.ResultUrl);
        Assert.Equal(GalleryMediaState.failed, byId[failedId].Media.State);
        Assert.Equal(GalleryMediaState.resultReady, byId[unlockedId].Media.State);
        Assert.True(byId[unlockedId].Media.IsWatermarkRemoved);
        Assert.False(byId[unlockedId].Media.HasWatermark);
    }

    private static TemplateMediaRecord CreateResultMediaRecord(
        TemplateGenerationJob job,
        bool includeResult = true,
        bool includePreview = false,
        bool isDeleted = false)
    {
        var mediaId = Guid.NewGuid();
        if (includeResult)
        {
            job.ResultMediaAssetId = mediaId;
        }

        return new TemplateMediaRecord
        {
            Id = mediaId,
            UserId = job.UserId,
            MediaType = "image",
            StoragePath = includeResult ? $"users/{job.UserId:N}/generations/{job.Id:N}/result.png" : string.Empty,
            PreviewUrl = includePreview ? $"users/{job.UserId:N}/generations/{job.Id:N}/preview.webp" : null,
            SourceType = "generation_result",
            GenerationId = job.Id,
            Url = includeResult ? job.ResultUrl ?? string.Empty : string.Empty,
            FileName = "result.png",
            ContentType = "image/png",
            FileSizeBytes = 1024,
            Role = TemplateMediaRole.GenerationOutputImage,
            LifecycleState = isDeleted ? TemplateMediaLifecycleState.Deleted : TemplateMediaLifecycleState.AttachedToGeneration,
            GenerationJobId = job.Id,
            UploadedAtUtc = job.CreatedAtUtc,
            AttachedAtUtc = job.CreatedAtUtc,
            DeletedAtUtc = isDeleted ? job.CreatedAtUtc.AddMinutes(1) : null,
            IsDeleted = isDeleted
        };
    }

    [Fact]
    public async Task VideoGenerationFlow_ShouldUploadSourceCreateCompletedJobAndFetchResult()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "preview-video-content"u8.ToArray());

        var referenceAsset = await UploadMediaAsync(
            application.Client,
            "reference.mp4",
            "video/mp4",
            TemplateAssetKind.ReferenceMotion,
            "reference-video-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Funny dance.",
                true,
                TemplateStatus.Active.ToString()));

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());

        Assert.Equal(TestUserId, queued.UserId);
        Assert.Equal(created.TemplateId, queued.TemplateId);
        Assert.Equal("Queued", queued.Status);
        Assert.Null(queued.StartedAtUtc);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Completed");
        Assert.NotNull(generation);

        Assert.Equal(TestUserId, generation!.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Completed", generation.Status);
        Assert.Equal("completed", generation.Stage);
        Assert.Equal(100, generation.ProgressPercent);
        Assert.Equal(60, generation.TokenCost);
        Assert.False(generation.UserMediaExpired);
        Assert.NotNull(generation.SourceImageAsset);
        Assert.Equal("pet.jpg", generation.SourceImageAsset!.FileName);
        Assert.NotNull(generation.NormalizedImageUrl);
        Assert.Equal(referenceAsset.Url, generation.ReferenceMotionUrl);
        Assert.EndsWith($"generated-{generation.GenerationId:N}.mp4", generation.OutputUrl, StringComparison.OrdinalIgnoreCase);
        Assert.Null(generation.FailureCode);
        Assert.Empty(application.Billing.RefundedGenerationIds);

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}");

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Completed", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
        Assert.EndsWith($"generation-{generation.GenerationId:N}-result-preview.jpg", fetched.ResultPreviewUrl, StringComparison.OrdinalIgnoreCase);

        var gallery = await GetFromJsonAsync<GalleryPageResponse>(
            application.Client,
            "/api/templates/generations?status=completed&take=10");
        var galleryItem = Assert.Single(gallery.Items, item => item.GenerationId == generation.GenerationId);
        Assert.Equal("video", galleryItem.Media.MediaType);
        Assert.Equal(GalleryMediaState.resultReady, galleryItem.Media.State);
        Assert.Equal(fetched.ResultPreviewUrl, galleryItem.Media.PreviewUrl);
    }

    [Fact]
    public async Task ImageGenerationFlow_ShouldUploadSourceCreateCompletedJobAndFetchResult()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "portrait.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "portrait-image-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Cozy Portrait",
                "Warm portrait template",
                "Portrait",
                ["cozy", "portrait"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());

        Assert.Equal(TestUserId, queued.UserId);
        Assert.Equal(created.TemplateId, queued.TemplateId);
        Assert.Equal("Queued", queued.Status);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Completed");

        Assert.Equal(TestUserId, generation.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Completed", generation.Status);
        Assert.Equal(20, generation.TokenCost);
        Assert.NotNull(generation.SourceImageAsset);
        Assert.Equal("pet.jpg", generation.SourceImageAsset!.FileName);
        Assert.Null(generation.NormalizedImageUrl);
        Assert.Null(generation.ReferenceMotionUrl);
        Assert.EndsWith($"generated-{generation.GenerationId:N}.png", generation.OutputUrl, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("openai/gpt-image-2/edit", generation.UsedPreprocessingModel);
        Assert.Null(generation.UsedKlingModel);
        Assert.NotNull(generation.PreprocessingCompletedAtUtc);
        Assert.Null(generation.MotionGenerationCompletedAtUtc);
        Assert.Equal(0.219m, generation.MotionProviderCostUsd);
        Assert.Null(generation.FailureCode);
        Assert.Empty(application.Billing.RefundedGenerationIds);

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}");

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Completed", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
    }

    [Fact]
    public async Task GenerationCreate_ShouldReturnStructuredWaitTooLongProblemBeforeCharge()
    {
        await using var application = await TestApplication.CreateAsync(
            freeImageMaxEstimatedWaitSeconds: 30,
            startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Busy Queue Portrait",
            "Portrait",
            ["busy", "queue"]);

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == created.TemplateId);
            var now = DateTime.UtcNow.AddMinutes(-5);
            dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.TemplateId,
                Template = template,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = created.TokenCost,
                QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = "templates-media/existing.jpg",
                SourceImageFileName = "existing.jpg",
                SourceImageContentType = "image/jpeg",
                SourceImageFileSizeBytes = 2048,
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now,
                ChargedAtUtc = now
            });
            await dbContext.SaveChangesAsync();
        }

        using var response = await UploadGenerationSourceWithClaimsAsync(
            application.Client,
            created.TemplateId,
            premiumClaim: false,
            role: "User");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;
        Assert.Equal("GENERATION_WAIT_TOO_LONG", root.GetProperty("title").GetString());
        Assert.Equal("GENERATION_WAIT_TOO_LONG", root.GetProperty("code").GetString());
        Assert.Equal("image", root.GetProperty("mediaType").GetString());
        Assert.Equal("free", root.GetProperty("tier").GetString());
        Assert.Equal(45, root.GetProperty("estimatedWaitSeconds").GetInt32());
        Assert.Equal(30, root.GetProperty("maxAllowedWaitSeconds").GetInt32());
        Assert.Equal(30, root.GetProperty("retryAfterSeconds").GetInt32());
        Assert.True(root.GetProperty("canRetry").GetBoolean());
        Assert.True(root.GetProperty("canUpgradeForPriority").GetBoolean());
        Assert.DoesNotContain("lock", body, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(application.Billing.ChargedGenerationIds);

        await using var verifyScope = application.Services.CreateAsyncScope();
        var verifyDbContext = verifyScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        Assert.Equal(1, await verifyDbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task GenerationCanonicalRoutes_ShouldReturnResultDownloadShareAndRemoveWatermark()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Canonical Alias Portrait",
            "Portrait",
            ["canonical", "alias"]);
        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());
        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Completed");

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}");
        using var fetchedJsonResponse = await application.Client.GetAsync($"/api/templates/generations/{generation.GenerationId}");
        fetchedJsonResponse.EnsureSuccessStatusCode();
        using var fetchedJson = JsonDocument.Parse(await fetchedJsonResponse.Content.ReadAsStringAsync());
        var download = await GetFromJsonAsync<GalleryDownloadResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}/download");
        var share = await PostAsJsonAsync<GalleryShareResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}/share",
            new { });
        var unlock = await PostAsJsonAsync<RemoveGenerationWatermarkResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}/remove-watermark",
            new { paymentMethod = "credit" });

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Completed", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
        Assert.Equal(fetched.OutputUrl, fetched.MediaUrl);
        Assert.Equal(fetched.OutputUrl, fetchedJson.RootElement.GetProperty("outputUrl").GetString());
        Assert.Equal(fetched.OutputUrl, fetchedJson.RootElement.GetProperty("mediaUrl").GetString());
        Assert.Equal(generation.OutputUrl, download.SignedMediaUrl);
        Assert.Equal(generation.OutputUrl, download.MediaUrl);
        Assert.Equal(generation.OutputUrl, share.SignedMediaUrl);
        Assert.Equal(generation.OutputUrl, share.MediaUrl);
        Assert.NotEmpty(share.ShareToken);
        Assert.StartsWith("http://localhost:5000/share/generation/", share.ShareUrl);
        Assert.DoesNotContain("cdn.example.com", share.ShareUrl, StringComparison.OrdinalIgnoreCase);
        Assert.NotNull(download.ExpiresAtUtc);
        Assert.NotNull(share.ExpiresAtUtc);
        Assert.Equal("image/png", download.ContentType);
        Assert.Equal("image/png", share.ContentType);
        Assert.Equal(GalleryMediaState.resultReady.ToString(), share.MediaState);
        Assert.False(download.HasWatermark);
        Assert.False(share.HasWatermark);

        var publicShare = await GetFromJsonAsync<PublicGalleryShareResponse>(
            application.Client,
            $"/api/templates/generations/share/{Uri.EscapeDataString(share.ShareToken)}");
        Assert.Equal(share.ShareToken, publicShare.ShareToken);
        Assert.Equal(GalleryMediaState.resultReady.ToString(), publicShare.MediaState);
        Assert.Equal(generation.OutputUrl, publicShare.MediaUrl);
        Assert.Null(publicShare.ReasonCode);
        using var publicPage = await application.Client.GetAsync($"/share/generation/{Uri.EscapeDataString(share.ShareToken)}");
        publicPage.EnsureSuccessStatusCode();
        var publicPageBody = await publicPage.Content.ReadAsStringAsync();
        Assert.Contains(generation.OutputUrl!, publicPageBody, StringComparison.Ordinal);
        Assert.DoesNotContain(TestUserId.ToString(), publicPageBody, StringComparison.OrdinalIgnoreCase);

        using var invalidShare = await application.Client.GetAsync("/api/templates/generations/share/not-a-token");
        Assert.Equal(HttpStatusCode.NotFound, invalidShare.StatusCode);
        Assert.True(unlock.WatermarkRemoved);
        Assert.Equal(generation.OutputUrl, unlock.MediaUrl);
    }

    [Theory]
    [InlineData("/api/templates/generations?status=ready")]
    [InlineData("/api/templates/generations?status=queued")]
    [InlineData("/api/templates/generations?status=processing")]
    [InlineData("/api/templates/generations?status=canceled")]
    public async Task ListGenerationsAsync_ShouldRejectLegacyStatusAliases(string path)
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_status", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task VideoGenerationFlow_ShouldRejectDraftTemplateAndCleanupUploadedSource()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "preview-video-content"u8.ToArray());

        var referenceAsset = await UploadMediaAsync(
            application.Client,
            "reference.mp4",
            "video/mp4",
            TemplateAssetKind.ReferenceMotion,
            "reference-video-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Draft Dance",
                "Draft dance template",
                "Dance",
                ["draft"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/standard/motion-control",
                "Dance prompt.",
                true,
                TemplateStatus.Draft.ToString()));

        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(JpegBytes());
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "pet.jpg");

        using var response = await application.Client.PostAsync($"/api/templates/{created.TemplateId}/generations", multipart);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("templates.invalid_status", body);
        Assert.Equal(2, application.MediaStorage.DeletedUrls.Count);
        Assert.Contains(application.MediaStorage.DeletedUrls, url => url.EndsWith("/pet.jpg", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(application.MediaStorage.DeletedUrls, url => url.EndsWith("/pet-preview.webp", StringComparison.OrdinalIgnoreCase));
        Assert.Empty(application.Billing.ChargedGenerationIds);
    }

    [Fact]
    public async Task VideoGenerationFlow_ShouldRefundCharge_WhenGeneratedMediaImportFails()
    {
        await using var application = await TestApplication.CreateAsync(failGeneratedMediaImport: true);

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "preview-video-content"u8.ToArray());

        var referenceAsset = await UploadMediaAsync(
            application.Client,
            "reference.mp4",
            "video/mp4",
            TemplateAssetKind.ReferenceMotion,
            "reference-video-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Refund Dance",
                "Refund on failed generation",
                "Dance",
                ["refund"],
                true,
                45,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/standard/motion-control",
                "Dance prompt.",
                true,
                TemplateStatus.Active.ToString()));

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());

        var failed = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Failed");

        Assert.Equal("templates.generated_media_import_failed", failed.FailureCode);
        Assert.Null(failed.OutputUrl);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);
        Assert.Contains(queued.GenerationId, application.Billing.RefundedGenerationIds);
    }

    [Fact]
    public async Task PremiumTemplateGeneration_ShouldReturnForbidden_WhenUserHasNoPremiumAccess()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "premium-lock.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "premium-lock-preview"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Premium Lock",
                "Premium lock test template",
                "Portrait",
                ["premium", "lock"],
                true,
                25,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));

        using var response = await UploadGenerationSourceWithClaimsAsync(
            application.Client,
            created.TemplateId,
            premiumClaim: false,
            role: "User");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Contains("templates.premium_required", body);
    }

    [Fact]
    public async Task PremiumTemplateGeneration_ShouldSucceed_WhenPremiumClaimIsTrue()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "premium-open.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "premium-open-preview"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Premium Open",
                "Premium access test template",
                "Portrait",
                ["premium", "open"],
                true,
                25,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));

        using var response = await UploadGenerationSourceWithClaimsAsync(
            application.Client,
            created.TemplateId,
            premiumClaim: true,
            role: "User");
        await EnsureSuccessStatusCodeAsync(response, $"/api/templates/{created.TemplateId}/generations");
        var queued = await ReadJsonAsync<TemplateGenerationResponse>(response);

        Assert.Equal(created.TemplateId, queued.TemplateId);
        Assert.Equal("Queued", queued.Status);
    }

    [Fact]
    public async Task GenerationCreate_ShouldHandleSeventyFiveConcurrentRequests_ForDifferentUsers()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Concurrent Portrait",
            "Load",
            ["concurrent"]);

        var requests = Enumerable.Range(0, 75)
            .Select(async index =>
            {
                var userId = Guid.Parse($"00000000-0000-0000-0000-{index + 1:000000000000}");
                using var multipart = new MultipartFormDataContent();
                using var fileContent = new ByteArrayContent(JpegBytes(index));
                fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
                multipart.Add(fileContent, "sourceImage", $"pet-{index}.jpg");

                using var request = new HttpRequestMessage(HttpMethod.Post, $"/api/templates/{created.TemplateId}/generations")
                {
                    Content = multipart
                };
                request.Headers.Add("X-Test-UserId", userId.ToString("D"));

                using var response = await application.Client.SendAsync(request);
                await EnsureSuccessStatusCodeAsync(response, $"/api/templates/{created.TemplateId}/generations");
                return await ReadJsonAsync<TemplateGenerationResponse>(response);
            });

        var queued = await Task.WhenAll(requests);

        Assert.Equal(75, queued.Length);
        Assert.Equal(75, queued.Select(x => x.GenerationId).Distinct().Count());
        Assert.Equal(75, queued.Select(x => x.UserId).Distinct().Count());
        Assert.All(queued, generation =>
        {
            Assert.Equal(created.TemplateId, generation.TemplateId);
            Assert.Equal("Queued", generation.Status);
        });
        Assert.Equal(75, application.Billing.ChargedGenerationIds.Distinct().Count());
    }

    private static async Task<HttpResponseMessage> UploadGenerationSourceWithClaimsAsync(
        HttpClient client,
        Guid templateId,
        bool premiumClaim,
        string role)
    {
        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(JpegBytes());
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "pet.jpg");

        using var request = new HttpRequestMessage(HttpMethod.Post, $"/api/templates/{templateId}/generations")
        {
            Content = multipart
        };
        request.Headers.Add("X-Test-Role", role);
        request.Headers.Add("X-Test-Premium", premiumClaim ? "true" : "false");

        return await client.SendAsync(request);
    }

    private static byte[] JpegBytes(int marker = 0)
    {
        return [0xFF, 0xD8, 0xFF, 0xE0, (byte)(marker & 0xFF), 0x00, 0x00, 0x00];
    }

}
