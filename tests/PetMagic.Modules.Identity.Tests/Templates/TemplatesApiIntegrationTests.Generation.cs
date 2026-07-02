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
        var download = await GetFromJsonAsync<GenerationDownloadResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}/download");
        var share = await PostAsJsonAsync<GenerationDownloadResponse>(
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
        Assert.Equal(generation.OutputUrl, download.MediaUrl);
        Assert.Equal(generation.OutputUrl, share.MediaUrl);
        Assert.False(download.HasWatermark);
        Assert.False(share.HasWatermark);
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
