using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Threading.Channels;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

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
            "source-pet-image"u8.ToArray());

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
        Assert.Equal(generation.SourceImageAsset.Url, generation.NormalizedImageUrl);
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
            "source-pet-image"u8.ToArray());

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
        using var fileContent = new ByteArrayContent("source-pet-image"u8.ToArray());
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "pet.jpg");

        using var response = await application.Client.PostAsync($"/api/templates/{created.TemplateId}/generations", multipart);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("templates.invalid_status", body);
        Assert.Single(application.MediaStorage.DeletedUrls);
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
            "source-pet-image"u8.ToArray());

        var failed = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Failed");

        Assert.Equal("templates.generated_media_import_failed", failed.FailureCode);
        Assert.Null(failed.OutputUrl);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);
        Assert.Contains(queued.GenerationId, application.Billing.RefundedGenerationIds);
    }

}
