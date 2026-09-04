using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminTemplateUploadEndpointTests
{
    [Fact]
    public async Task UploadMediaAsync_ShouldReturnOptimizedPreviewVariants_AndDeleteRawUpload()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/raw.jpg",
            "templates/raw.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null);
        var thumbnail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/thumbnail.webp",
            "template-previews/batch/thumbnail.webp",
            "preview-thumbnail.webp",
            "image/webp",
            12,
            null);
        var detail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/detail.webp",
            "template-previews/batch/detail.webp",
            "preview-detail.webp",
            "image/webp",
            24,
            null);
        var storage = new RecordingMediaStorage(raw);
        var optimizer = new FixedTemplatePreviewOptimizer(new TemplatePreviewOptimizationResult(
            detail,
            thumbnail,
            null,
            thumbnail,
            null,
            detail,
            true));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(1024),
            new RecordingMediaMetadataReader(),
            optimizer,
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;
        var records = await dbContext.TemplateMediaRecords.OrderBy(record => record.Url).ToArrayAsync();

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Equal(detail.Url, root.GetProperty("url").GetString());
        Assert.Equal(detail.FileSizeBytes, root.GetProperty("fileSizeBytes").GetInt64());
        Assert.True(root.GetProperty("wasOptimized").GetBoolean());
        Assert.Equal(thumbnail.Url, root.GetProperty("thumbnailAsset").GetProperty("url").GetString());
        Assert.Equal(thumbnail.Url, root.GetProperty("feedLoopLowAsset").GetProperty("url").GetString());
        Assert.Equal(detail.Url, root.GetProperty("detailPreviewAsset").GetProperty("url").GetString());
        Assert.Null(root.GetProperty("animatedPreviewAsset").GetString());
        Assert.Equal(1, optimizer.Calls);
        Assert.Equal([raw.Url], storage.DeletedUrls);
        Assert.Equal(3, records.Length);
        Assert.Equal(TemplateMediaLifecycleState.Deleted, records.Single(record => record.Url == raw.Url).LifecycleState);
        Assert.All(
            records.Where(record => record.Url != raw.Url),
            record => Assert.Equal(TemplateMediaLifecycleState.Temporary, record.LifecycleState));
    }

    [Theory]
    [InlineData("templates.preview_optimization_failed", StatusCodes.Status503ServiceUnavailable)]
    [InlineData("templates.preview_optimization_timed_out", StatusCodes.Status504GatewayTimeout)]
    [InlineData("templates.preview_optimization_invalid", StatusCodes.Status422UnprocessableEntity)]
    public async Task UploadMediaAsync_ShouldDeleteRawUpload_WhenOptimizationFails(
        string errorCode,
        int expectedStatusCode)
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/raw.jpg",
            "templates/raw.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null);
        var storage = new RecordingMediaStorage(raw);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(1024),
            new RecordingMediaMetadataReader(),
            new FailingTemplatePreviewOptimizer(new Error(errorCode, "Internal test detail.")),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal(expectedStatusCode, statusCode);
        Assert.Contains(errorCode, body, StringComparison.Ordinal);
        Assert.DoesNotContain("Internal test detail.", body, StringComparison.Ordinal);
        Assert.Equal([raw.Url], storage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.Deleted, record.LifecycleState);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldKeepSuccessfulVariants_AndAuditRawCleanupFailure()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/raw.jpg",
            "templates/raw.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null);
        var thumbnail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/thumbnail.webp",
            "template-previews/batch/thumbnail.webp",
            "preview-thumbnail.webp",
            "image/webp",
            12,
            null);
        var detail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/detail.webp",
            "template-previews/batch/detail.webp",
            "preview-detail.webp",
            "image/webp",
            24,
            null);
        var storage = new RecordingMediaStorage(raw, failDeletes: true);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(1024),
            new RecordingMediaMetadataReader(),
            new FixedTemplatePreviewOptimizer(new TemplatePreviewOptimizationResult(
                detail,
                thumbnail,
                null,
                thumbnail,
                null,
                detail,
                true)),
            CancellationToken.None);

        var (statusCode, _) = await ExecuteAsync(result);
        var rawRecord = await dbContext.TemplateMediaRecords.SingleAsync(record => record.Url == raw.Url);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, rawRecord.LifecycleState);
        Assert.Equal("templates.media_storage_failed", rawRecord.FailureCode);
        Assert.Equal(2, await dbContext.TemplateMediaRecords.CountAsync(
            record => record.LifecycleState == TemplateMediaLifecycleState.Temporary));
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRollbackAndAuditVariants_WhenLifecycleSaveFails()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = new FailOnSaveLifecycleService(
            CreateLifecycleService(dbContext),
            failSaveCall: 2,
            "Simulated optimized lifecycle save failure.");
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/raw.jpg",
            "templates/raw.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null);
        var thumbnail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/thumbnail.webp",
            "template-previews/batch/thumbnail.webp",
            "preview-thumbnail.webp",
            "image/webp",
            12,
            null);
        var detail = new StoredMediaResponse(
            "https://cdn.example.com/template-previews/batch/detail.webp",
            "template-previews/batch/detail.webp",
            "preview-detail.webp",
            "image/webp",
            24,
            null);
        var storage = new RecordingMediaStorage(raw, failDeletes: true);

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            AdminTemplateEndpoints.UploadMediaAsync(
                file,
                TemplateAssetKind.Preview.ToString(),
                storage,
                lifecycleService,
                new FixedTemplateMediaUploadPolicy(1024),
                new RecordingMediaMetadataReader(),
                new FixedTemplatePreviewOptimizer(new TemplatePreviewOptimizationResult(
                    detail,
                    thumbnail,
                    null,
                    thumbnail,
                    null,
                    detail,
                    true)),
                CancellationToken.None));
        var records = await dbContext.TemplateMediaRecords.ToArrayAsync();

        Assert.Equal("Simulated optimized lifecycle save failure.", exception.Message);
        Assert.Equal(3, records.Length);
        Assert.All(records, record =>
        {
            Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, record.LifecycleState);
            Assert.Equal("templates.media_storage_failed", record.FailureCode);
        });
        Assert.Equal(3, storage.DeletedUrls.Count);
        Assert.Contains(raw.Url, storage.DeletedUrls);
        Assert.Contains(thumbnail.Url, storage.DeletedUrls);
        Assert.Contains(detail.Url, storage.DeletedUrls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldCleanupAndAuditRaw_WhenInitialLifecycleSaveFails()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = new FailOnSaveLifecycleService(
            CreateLifecycleService(dbContext),
            failSaveCall: 1,
            "Simulated raw lifecycle save failure.");
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/raw.jpg",
            "templates/raw.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null);
        var storage = new RecordingMediaStorage(raw, failDeletes: true);

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            AdminTemplateEndpoints.UploadMediaAsync(
                file,
                TemplateAssetKind.Preview.ToString(),
                storage,
                lifecycleService,
                new FixedTemplateMediaUploadPolicy(1024),
                new RecordingMediaMetadataReader(),
                new UnexpectedTemplatePreviewOptimizer(),
                CancellationToken.None));
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal("Simulated raw lifecycle save failure.", exception.Message);
        Assert.Equal([raw.Url], storage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, record.LifecycleState);
        Assert.Equal("templates.media_storage_failed", record.FailureCode);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldAuditAmbiguousRawStore_WhenStorageCleanupFails()
    {
        await using var dbContext = CreateDbContext();
        const string ambiguousKey = "templates-media/2026/09/ambiguous-preview.jpg";
        var storage = new AmbiguousFailingMediaStorage(ambiguousKey);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            CreateFormFile("preview.jpg", "image/jpeg", JpegBytes()),
            TemplateAssetKind.Preview.ToString(),
            storage,
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(1024),
            new RecordingMediaMetadataReader(),
            new UnexpectedTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal(StatusCodes.Status503ServiceUnavailable, statusCode);
        Assert.Contains("templates.media_storage_failed", body, StringComparison.Ordinal);
        Assert.Equal([ambiguousKey], storage.DeletedUrls);
        Assert.Equal(ambiguousKey, record.StoragePath);
        Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, record.LifecycleState);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldAuditAmbiguousRawStore_ThenPropagateCancellation()
    {
        await using var dbContext = CreateDbContext();
        using var cancellationSource = new CancellationTokenSource();
        const string ambiguousKey = "templates-media/2026/09/cancelled-preview.jpg";
        var storage = new AmbiguousFailingMediaStorage(ambiguousKey, cancellationSource);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            AdminTemplateEndpoints.UploadMediaAsync(
                CreateFormFile("preview.jpg", "image/jpeg", JpegBytes()),
                TemplateAssetKind.Preview.ToString(),
                storage,
                CreateLifecycleService(dbContext),
                new FixedTemplateMediaUploadPolicy(1024),
                new RecordingMediaMetadataReader(),
                new UnexpectedTemplatePreviewOptimizer(),
                cancellationSource.Token));
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal([ambiguousKey], storage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, record.LifecycleState);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldReturnUploadedImage_WhenPreviewImageIsValid()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.jpg",
            "templates/preview.jpg",
            "preview.jpg",
            "image/jpeg",
            file.Length,
            null));
        var metadataReader = new RecordingMediaMetadataReader();

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(1024),
            metadataReader,
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None,
            durationSeconds: "7");

        var (statusCode, body) = await ExecuteAsync(result);
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("preview.jpg", body);
        Assert.Contains("image/jpeg", body);
        Assert.False(metadataReader.StoredMediaCalls > 0);
        Assert.Equal(TemplateMediaLifecycleState.Temporary, record.LifecycleState);
        Assert.Equal(TemplateMediaRole.PreviewAsset, record.Role);
        Assert.Equal("https://cdn.example.com/templates/preview.jpg", record.Url);
        Assert.NotNull(record.ExpiresAtUtc);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldReturnDuration_WhenReferenceVideoIsValid()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("reference.mp4", "video/mp4", Mp4Bytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/reference.mp4",
            "templates/reference.mp4",
            "reference.mp4",
            "video/mp4",
            file.Length,
            "c:/temp/reference.mp4"));
        var metadataReader = new RecordingMediaMetadataReader(7.25);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            new UnexpectedTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("7.25", body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
        Assert.False(metadataReader.RetainLocalPathOnSuccess);
        Assert.Equal(0, metadataReader.ReleaseRetainedLocalPathCalls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldAcceptQuickTimePreviewVideo()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.mov", "video/quicktime", QuickTimeBytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.mov",
            "templates/preview.mov",
            "preview.mov",
            "video/quicktime",
            file.Length,
            "c:/temp/preview.mov"));
        var metadataReader = new RecordingMediaMetadataReader(7.25);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None,
            durationSeconds: "7");

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("preview.mov", body);
        Assert.Contains("video/quicktime", body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
        Assert.True(metadataReader.RetainLocalPathOnSuccess);
        Assert.Equal(1, metadataReader.ReleaseRetainedLocalPathCalls);
    }

    [Theory]
    [InlineData("preview.mov", "video/quicktime", "mp42", "video/mp4")]
    [InlineData("preview.mp4", "video/mp4", "qt  ", "video/quicktime")]
    public async Task UploadMediaAsync_ShouldAcceptPreviewIsoBmffMimeAliases(
        string fileName,
        string declaredContentType,
        string majorBrand,
        string expectedContentType)
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile(fileName, declaredContentType, IsoBmffBytes(majorBrand));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(7.25),
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains(expectedContentType, body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldNotApplyQuickTimeAliasToReferenceMotion()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("reference.mov", "video/quicktime", Mp4Bytes());

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(7.25),
            new UnexpectedTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.file_type_not_allowed", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldAcceptReferenceMp4_WhenMimeTypeFallsBackToOctetStream()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("reference.mp4", "application/octet-stream", Mp4Bytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/reference.mp4",
            "templates/reference.mp4",
            "reference.mp4",
            "video/mp4",
            file.Length,
            "c:/temp/reference.mp4"));
        var metadataReader = new RecordingMediaMetadataReader(7.25);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("reference.mp4", body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectReferenceWebm()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("reference.webm", "video/webm", WebmBytes());

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(),
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.file_type_not_allowed", body);
        Assert.DoesNotContain("File content type is not allowed", body);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectInvalidContentType()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("notes.txt", "text/plain", Encoding.UTF8.GetBytes("not-media"));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(),
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.file_type_not_allowed", body);
        Assert.DoesNotContain("File content type is not allowed", body);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectSvgPreviewUpload()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("preview.svg", "image/svg+xml", Encoding.UTF8.GetBytes("<svg></svg>"));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(),
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.file_type_not_allowed", body);
        Assert.DoesNotContain("File content type is not allowed", body);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectOversizedFile_UsingConfiguredLimit()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("preview.jpg", "image/jpeg", JpegBytes(11));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(10),
            new RecordingMediaMetadataReader(),
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.file_too_large", body);
        Assert.DoesNotContain("maximum allowed size of 10 bytes", body);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectPreviewVideo_WhenDurationIsTooLong()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.mp4", "video/mp4", Mp4Bytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.mp4",
            "templates/preview.mp4",
            "preview.mp4",
            "video/mp4",
            file.Length,
            "c:/temp/preview.mp4"));
        var metadataReader = new RecordingMediaMetadataReader(28.0);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None,
            durationSeconds: "7");

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.preview_duration_invalid", body);
        Assert.DoesNotContain("Preview video duration must be between", body);
        Assert.True(metadataReader.RetainLocalPathOnSuccess);
        Assert.Equal(1, metadataReader.ReleaseRetainedLocalPathCalls);
    }

    [Theory]
    [InlineData("templates.media_metadata_invalid", StatusCodes.Status422UnprocessableEntity)]
    [InlineData("templates.media_metadata_timed_out", StatusCodes.Status504GatewayTimeout)]
    public async Task UploadMediaAsync_ShouldRejectServerMetadataFailure_EvenWithClientDuration(
        string errorCode,
        int expectedStatusCode)
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("preview.mov", "video/quicktime", QuickTimeBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.mov",
            "templates/preview.mov",
            "preview.mov",
            "video/quicktime",
            file.Length,
            "c:/temp/preview.mov");
        var storage = new RecordingMediaStorage(raw);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new FailingMediaMetadataReader(new Error(errorCode, "Internal metadata detail.")),
            new UnexpectedTemplatePreviewOptimizer(),
            CancellationToken.None,
            durationSeconds: "7");

        var (statusCode, body) = await ExecuteAsync(result);
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal(expectedStatusCode, statusCode);
        Assert.Contains(errorCode, body, StringComparison.Ordinal);
        Assert.DoesNotContain("Internal metadata detail.", body, StringComparison.Ordinal);
        Assert.Equal([raw.Url], storage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.Deleted, record.LifecycleState);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldCleanupRaw_WhenMetadataProbeIsCancelled()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("preview.mov", "video/quicktime", QuickTimeBytes());
        var raw = new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.mov",
            "templates/preview.mov",
            "preview.mov",
            "video/quicktime",
            file.Length,
            "c:/temp/preview.mov");
        var storage = new RecordingMediaStorage(raw);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            AdminTemplateEndpoints.UploadMediaAsync(
                file,
                TemplateAssetKind.Preview.ToString(),
                storage,
                CreateLifecycleService(dbContext),
                new FixedTemplateMediaUploadPolicy(2048),
                new CancelingMediaMetadataReader(),
                new UnexpectedTemplatePreviewOptimizer(),
                CancellationToken.None));
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal([raw.Url], storage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.Deleted, record.LifecycleState);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectPreviewVideo_WhenDurationMetadataMissing()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("preview.mp4", "video/mp4", Mp4Bytes());
        var storage = new RecordingMediaStorage(new StoredMediaResponse(
            "https://cdn.example.com/templates/preview.mp4",
            "templates/preview.mp4",
            "preview.mp4",
            "video/mp4",
            file.Length,
            "c:/temp/preview.mp4"));
        var metadataReader = new RecordingMediaMetadataReader(null);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            storage,
            lifecycleService,
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            new PassthroughTemplatePreviewOptimizer(),
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("templates.preview_duration_required", body);
        Assert.DoesNotContain("Preview video duration metadata is required", body);
        Assert.True(metadataReader.RetainLocalPathOnSuccess);
        Assert.Equal(1, metadataReader.ReleaseRetainedLocalPathCalls);
    }

    private static FormFile CreateFormFile(string fileName, string contentType, byte[] content)
    {
        var stream = new MemoryStream(content);
        return new FormFile(stream, 0, content.Length, "file", fileName)
        {
            Headers = new HeaderDictionary(),
            ContentType = contentType
        };
    }

    private static byte[] JpegBytes(int length = 32)
    {
        var bytes = new byte[Math.Max(length, 4)];
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;
        bytes[3] = 0xE0;
        return bytes;
    }

    private static byte[] Mp4Bytes()
    {
        return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32, 0x00, 0x00, 0x00, 0x00];
    }

    private static byte[] QuickTimeBytes()
    {
        return IsoBmffBytes("qt  ");
    }

    private static byte[] IsoBmffBytes(string majorBrand)
    {
        var brandBytes = Encoding.ASCII.GetBytes(majorBrand);
        Assert.Equal(4, brandBytes.Length);
        return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, .. brandBytes, 0x00, 0x00, 0x00, 0x00];
    }

    private static byte[] WebmBytes()
    {
        return [0x1A, 0x45, 0xDF, 0xA3, 0x00, 0x00, 0x00, 0x00];
    }

    private static async Task<(int StatusCode, string Body)> ExecuteAsync(IResult result)
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        context.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .ConfigureHttpJsonOptions(_ => { })
            .BuildServiceProvider();

        await result.ExecuteAsync(context);

        context.Response.Body.Position = 0;
        using var reader = new StreamReader(context.Response.Body, Encoding.UTF8);
        return (context.Response.StatusCode, await reader.ReadToEndAsync());
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"admin-template-upload-endpoint-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static ITemplateMediaLifecycleService CreateLifecycleService(TemplatesDbContext dbContext)
    {
        return new TemplateMediaLifecycleService(dbContext, new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            TemporaryUploadRetentionMinutes = 60
        });
    }

    private sealed class FixedTemplateMediaUploadPolicy(long maxFileSizeBytes) : ITemplateMediaUploadPolicy
    {
        public long GetMaxFileSizeBytes(TemplateAssetKind assetKind) => maxFileSizeBytes;
    }

    private sealed class RecordingMediaStorage(
        StoredMediaResponse? response = null,
        bool failDeletes = false) : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            var stored = response ?? new StoredMediaResponse(
                "https://cdn.example.com/templates/file.bin",
                "templates/file.bin",
                asset.FileName,
                asset.ContentType,
                asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0,
                null);

            return Task.FromResult(Result.Success(stored));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(failDeletes
                ? Result.Failure(new Error("templates.media_storage_failed", "Test storage failure."))
                : Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class AmbiguousFailingMediaStorage(
        string ambiguousStorageKey,
        CancellationTokenSource? cancelOnStore = null) : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(
            MediaUploadCommand asset,
            CancellationToken cancellationToken)
        {
            cancelOnStore?.Cancel();
            return Task.FromResult(Result.Failure<StoredMediaResponse>(new Error(
                "templates.media_storage_failed",
                "Internal ambiguous storage detail.",
                new Dictionary<string, object?>
                {
                    ["ambiguousStorageKey"] = ambiguousStorageKey
                })));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(Result.Failure(new Error(
                "templates.media_storage_failed",
                "Test delete failure.")));
        }

        public Task<Result<string>> CreateReadUrlAsync(
            string assetUrl,
            TimeSpan ttl,
            CancellationToken cancellationToken) =>
            Task.FromResult(Result.Failure<string>(new Error(
                "templates.media_storage_failed",
                "Unexpected read URL request.")));
    }

    private sealed class RecordingMediaMetadataReader(double? durationSeconds = null) : IMediaMetadataReader
    {
        public int StoredMediaCalls { get; private set; }

        public bool RetainLocalPathOnSuccess { get; private set; }

        public int ReleaseRetainedLocalPathCalls { get; private set; }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            StoredMediaCalls++;
            return Task.FromResult(Result.Success(durationSeconds));
        }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(
            StoredMediaResponse storedMedia,
            bool retainLocalPathOnSuccess,
            CancellationToken cancellationToken)
        {
            RetainLocalPathOnSuccess = retainLocalPathOnSuccess;
            return GetVideoDurationSecondsAsync(storedMedia, cancellationToken);
        }

        public void ReleaseRetainedLocalPath(StoredMediaResponse storedMedia)
        {
            ReleaseRetainedLocalPathCalls++;
        }
    }

    private sealed class FailingMediaMetadataReader(Error error) : IMediaMetadataReader
    {
        public Task<Result<double?>> GetVideoDurationSecondsAsync(
            TemplateAssetCommand asset,
            CancellationToken cancellationToken) =>
            Task.FromResult(Result.Failure<double?>(error));

        public Task<Result<double?>> GetVideoDurationSecondsAsync(
            StoredMediaResponse storedMedia,
            CancellationToken cancellationToken) =>
            Task.FromResult(Result.Failure<double?>(error));
    }

    private sealed class CancelingMediaMetadataReader : IMediaMetadataReader
    {
        public Task<Result<double?>> GetVideoDurationSecondsAsync(
            TemplateAssetCommand asset,
            CancellationToken cancellationToken) =>
            Task.FromCanceled<Result<double?>>(new CancellationToken(canceled: true));

        public Task<Result<double?>> GetVideoDurationSecondsAsync(
            StoredMediaResponse storedMedia,
            CancellationToken cancellationToken) =>
            Task.FromCanceled<Result<double?>>(new CancellationToken(canceled: true));
    }

    private sealed class PassthroughTemplatePreviewOptimizer : ITemplatePreviewOptimizer
    {
        public Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
            StoredMediaResponse original,
            double? durationSeconds,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new TemplatePreviewOptimizationResult(
                original,
                null,
                null,
                null,
                null,
                null,
                false)));
        }
    }

    private sealed class FixedTemplatePreviewOptimizer(TemplatePreviewOptimizationResult result) : ITemplatePreviewOptimizer
    {
        public int Calls { get; private set; }

        public Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
            StoredMediaResponse original,
            double? durationSeconds,
            CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(Result.Success(result));
        }
    }

    private sealed class FailingTemplatePreviewOptimizer(Error error) : ITemplatePreviewOptimizer
    {
        public Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
            StoredMediaResponse original,
            double? durationSeconds,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<TemplatePreviewOptimizationResult>(error));
        }
    }

    private sealed class UnexpectedTemplatePreviewOptimizer : ITemplatePreviewOptimizer
    {
        public Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
            StoredMediaResponse original,
            double? durationSeconds,
            CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("ReferenceMotion must not be optimized.");
        }
    }

    private sealed class FailOnSaveLifecycleService(
        ITemplateMediaLifecycleService inner,
        int failSaveCall,
        string failureMessage) : ITemplateMediaLifecycleService
    {
        private int saveCalls;

        public Task RegisterTemporaryUploadAsync(
            TemplateAssetCommand asset,
            TemplateMediaRole role,
            CancellationToken cancellationToken) =>
            inner.RegisterTemporaryUploadAsync(asset, role, cancellationToken);

        public Task ClaimTemplateAssetAsync(
            Guid templateId,
            TemplateAssetCommand? asset,
            TemplateMediaRole role,
            CancellationToken cancellationToken) =>
            inner.ClaimTemplateAssetAsync(templateId, asset, role, cancellationToken);

        public Task MarkDeletedAsync(string url, CancellationToken cancellationToken) =>
            inner.MarkDeletedAsync(url, cancellationToken);

        public Task MarkCleanupFailureAsync(
            string url,
            string errorCode,
            string errorMessage,
            CancellationToken cancellationToken) =>
            inner.MarkCleanupFailureAsync(url, errorCode, errorMessage, cancellationToken);

        public Task SaveChangesAsync(CancellationToken cancellationToken)
        {
            saveCalls++;
            return saveCalls == failSaveCall
                ? Task.FromException(new InvalidOperationException(failureMessage))
                : inner.SaveChangesAsync(cancellationToken);
        }
    }
}
