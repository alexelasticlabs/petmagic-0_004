using System.Text;

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
            CancellationToken.None);

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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("7.25", body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, statusCode);
        Assert.Contains("preview.mov", body);
        Assert.Contains("video/quicktime", body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("File content type is not allowed", body);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("File content type is not allowed", body);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("File content type is not allowed", body);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("maximum allowed size of 10 bytes", body);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("Preview video duration must be between", body);
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
            CancellationToken.None);

        var (statusCode, body) = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, statusCode);
        Assert.Contains("Preview video duration metadata is required", body);
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
        return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00];
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

    private sealed class RecordingMediaStorage(StoredMediaResponse? response = null) : IMediaStorage
    {
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
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class RecordingMediaMetadataReader(double? durationSeconds = null) : IMediaMetadataReader
    {
        public int StoredMediaCalls { get; private set; }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            StoredMediaCalls++;
            return Task.FromResult(Result.Success(durationSeconds));
        }
    }
}
