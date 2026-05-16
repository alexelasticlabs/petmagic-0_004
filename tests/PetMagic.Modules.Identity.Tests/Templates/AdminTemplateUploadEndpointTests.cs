using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminTemplateUploadEndpointTests
{
    [Fact]
    public async Task UploadMediaAsync_ShouldReturnUploadedImage_WhenPreviewImageIsValid()
    {
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
            new FixedTemplateMediaUploadPolicy(1024),
            metadataReader,
            CancellationToken.None);

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, response.StatusCode);
        Assert.Contains("preview.jpg", response.Body);
        Assert.Contains("image/jpeg", response.Body);
        Assert.False(metadataReader.StoredMediaCalls > 0);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldReturnDuration_WhenReferenceVideoIsValid()
    {
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
            new FixedTemplateMediaUploadPolicy(2048),
            metadataReader,
            CancellationToken.None);

        var response = await ExecuteAsync(result);

        Assert.Equal(StatusCodes.Status200OK, response.StatusCode);
        Assert.Contains("7.25", response.Body);
        Assert.Equal(1, metadataReader.StoredMediaCalls);
    }

    [Fact]
    public async Task UploadMediaAsync_ShouldRejectInvalidContentType()
    {
        var file = CreateFormFile("notes.txt", "text/plain", Encoding.UTF8.GetBytes("not-media"));

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.ReferenceMotion.ToString(),
            new RecordingMediaStorage(),
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
        var file = CreateFormFile("preview.jpg", "image/jpeg", new byte[11]);

        var result = await AdminTemplateEndpoints.UploadMediaAsync(
            file,
            TemplateAssetKind.Preview.ToString(),
            new RecordingMediaStorage(),
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
