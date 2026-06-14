using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{

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

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Succeeded");
        Assert.NotNull(generation);

        Assert.Equal(TestUserId, generation!.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Succeeded", generation.Status);
        Assert.Equal("succeeded", generation.Stage);
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
        Assert.Equal("Succeeded", fetched.Status);
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

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Succeeded");

        Assert.Equal(TestUserId, generation.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Succeeded", generation.Status);
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
        Assert.Equal("Succeeded", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
    }

    [Fact]
    public async Task GenerationCanonicalAliases_ShouldReturnResultDownloadShareAndRemoveWatermark()
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
        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Succeeded");

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/generations/{generation.GenerationId}");
        using var fetchedJsonResponse = await application.Client.GetAsync($"/api/generations/{generation.GenerationId}");
        fetchedJsonResponse.EnsureSuccessStatusCode();
        using var fetchedJson = JsonDocument.Parse(await fetchedJsonResponse.Content.ReadAsStringAsync());
        var download = await GetFromJsonAsync<GenerationDownloadResponse>(
            application.Client,
            $"/api/generations/{generation.GenerationId}/download");
        var share = await PostAsJsonAsync<GenerationDownloadResponse>(
            application.Client,
            $"/api/generations/{generation.GenerationId}/share",
            new { });
        var unlock = await PostAsJsonAsync<RemoveGenerationWatermarkResponse>(
            application.Client,
            $"/api/generations/{generation.GenerationId}/remove-watermark",
            new { paymentMethod = "credit" });

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Succeeded", fetched.Status);
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
