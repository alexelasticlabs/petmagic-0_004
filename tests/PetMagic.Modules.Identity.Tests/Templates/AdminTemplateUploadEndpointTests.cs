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
        var file = CreateFormFile("preview.jpg", "image/jpeg", Encoding.UTF8.GetBytes("image-bytes"));
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

        var response = await ExecuteAsync(result);
        var record = await dbContext.TemplateMediaRecords.SingleAsync();

        Assert.Equal(StatusCodes.Status200OK, response.StatusCode);
        Assert.Contains("preview.jpg", response.Body);
        Assert.Contains("image/jpeg", response.Body);
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
        var file = CreateFormFile("reference.mp4", "video/mp4", Encoding.UTF8.GetBytes("video-bytes"));
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

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, response.StatusCode);
        Assert.Contains("7.25", response.Body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldAcceptReferenceMp4_WhenMimeTypeFallsBackToOctetStream()
    {
        await using var dbContext = CreateDbContext();
        var lifecycleService = CreateLifecycleService(dbContext);
        var file = CreateFormFile("reference.mp4", "application/octet-stream", Encoding.UTF8.GetBytes("video-bytes"));
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

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, response.StatusCode);
        Assert.Contains("reference.mp4", response.Body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectReferenceWebm()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("reference.webm", "video/webm", Encoding.UTF8.GetBytes("video-bytes"));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(2048),
            new RecordingMediaMetadataReader(),
            CancellationToken.None);

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, response.StatusCode);
        Assert.Contains("File content type is not allowed", response.Body);
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

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, response.StatusCode);
        Assert.Contains("File content type is not allowed", response.Body);
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

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, response.StatusCode);
        Assert.Contains("File content type is not allowed", response.Body);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectOversizedFile_UsingConfiguredLimit()
    {
        await using var dbContext = CreateDbContext();
        var file = CreateFormFile("preview.jpg", "image/jpeg", new byte[11]);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            new RecordingMediaStorage(),
            CreateLifecycleService(dbContext),
            new FixedTemplateMediaUploadPolicy(10),
            new RecordingMediaMetadataReader(),
            CancellationToken.None);

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status400BadRequest, response.StatusCode);
        Assert.Contains("maximum allowed size of 10 bytes", response.Body);
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
                asset.Content.LongLength,
                null);

            return Task.FromResult(Result.Success(stored));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
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
