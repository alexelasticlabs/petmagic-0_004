using System.Net;

using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class HttpGeneratedMediaImporterTests
{
    [Fact]
    public async Task ImportImageAsync_ShouldRejectLoopbackUrlWithoutSendingRequest()
    {
        var handler = new RecordingHandler("image/png", [1, 2, 3]);
        var importer = CreateImporter(handler);

        var result = await importer.ImportImageAsync("https://localhost/generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(0, handler.RequestCount);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldRejectNonHttpsUrlWithoutSendingRequest()
    {
        var handler = new RecordingHandler("image/png", [1, 2, 3]);
        var importer = CreateImporter(handler);

        var result = await importer.ImportImageAsync("http://cdn.example.com/generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(0, handler.RequestCount);
    }

    [Theory]
    [InlineData("https://169.254.169.254/latest/meta-data/iam/security-credentials")]
    [InlineData("https://10.0.0.5/generated.png")]
    [InlineData("https://192.168.1.10/generated.png")]
    [InlineData("https://[::1]/generated.png")]
    [InlineData("https://[fc00::1]/generated.png")]
    [InlineData("https://[fd00::1]/generated.png")]
    public async Task ImportImageAsync_ShouldRejectPrivateNetworkUrlWithoutSendingRequest(string url)
    {
        var handler = new RecordingHandler("image/png", [1, 2, 3]);
        var importer = CreateImporter(handler);

        var result = await importer.ImportImageAsync(url, Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(0, handler.RequestCount);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldNotStore_WhenProviderReturnsRedirect()
    {
        var handler = new StatusHandler(HttpStatusCode.Redirect);
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync("https://cdn.example.com/generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(0, storage.StoreCount);
    }

    [Fact]
    public async Task ImportVideoAsync_ShouldRejectUnexpectedContentType()
    {
        var handler = new RecordingHandler("text/html", "<html></html>"u8.ToArray());
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportVideoAsync("https://cdn.example.com/generated.mp4", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(0, storage.StoreCount);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldRejectContentTypeMismatchWithoutStoring()
    {
        var handler = new RecordingHandler("image/png", "<html></html>"u8.ToArray());
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync("https://cdn.example.com/generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(0, storage.StoreCount);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldStoreDetectedContentType()
    {
        var handler = new RecordingHandler("image/png", PngPayload());
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync("https://cdn.example.com/generated.php", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(1, storage.StoreCount);
        Assert.NotNull(storage.LastAsset);
        Assert.Equal("image/png", storage.LastAsset.ContentType);
        Assert.EndsWith(".png", storage.LastAsset.FileName, StringComparison.OrdinalIgnoreCase);
        Assert.False(storage.LastAsset.FileName.EndsWith(".php", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task ImportImageAsync_ShouldSanitizeStorageFailureCode()
    {
        var handler = new RecordingHandler("image/png", PngPayload());
        var storage = new RecordingMediaStorage("templates.media_storage_failed token=import-storage-secret");
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync("https://cdn.example.com/generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.MediaStorageFailed.Code, result.Error.Code);
        Assert.DoesNotContain("import-storage-secret", result.Error.Code, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(1, storage.StoreCount);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldFailWithoutStoring_WhenProviderUrlReturnsNotFound()
    {
        var handler = new StatusHandler(HttpStatusCode.NotFound);
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync("https://cdn.example.com/expired-generated.png", Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal(0, storage.StoreCount);
    }

    private static HttpGeneratedMediaImporter CreateImporter(HttpMessageHandler handler, RecordingMediaStorage? storage = null)
    {
        storage ??= new RecordingMediaStorage();
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "https://app.petmagic.test",
            LocalMediaRootPath = Path.GetTempPath(),
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "image",
            AllowedImageModels = ["fal-ai/test-model"],
            AllowedPreprocessingModels = ["fal-ai/test-model"],
            AllowedKlingModels = ["fal-ai/test-model"],
            SupportedLocalizationLocales = ["en"]
        };

        return new HttpGeneratedMediaImporter(
            new StaticHttpClientFactory(new HttpClient(handler)),
            storage,
            options,
            NullLogger<HttpGeneratedMediaImporter>.Instance);
    }

    private sealed class StaticHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class RecordingHandler(string contentType, byte[] payload) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new ByteArrayContent(payload)
                {
                    Headers =
                    {
                        ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType)
                    }
                }
            });
        }
    }

    private sealed class StatusHandler(HttpStatusCode statusCode) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestCount++;
            return Task.FromResult(new HttpResponseMessage(statusCode));
        }
    }

    private sealed class RecordingMediaStorage(string? failureCode = null) : IMediaStorage
    {
        public int StoreCount { get; private set; }

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            StoreCount++;
            LastAsset = asset;
            if (failureCode is not null)
            {
                return Task.FromResult(Result.Failure<StoredMediaResponse>(
                    new Error(failureCode, "Media upload could not be stored.")));
            }

            return Task.FromResult(Result.Success(new StoredMediaResponse(
                "https://cdn.example.com/stored/generated.png",
                "templates/generated.png",
                asset.FileName,
                asset.ContentType,
                asset.ContentLengthBytes,
                null)));
        }

        public MediaUploadCommand? LastAsset { get; private set; }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private static byte[] PngPayload()
    {
        return
        [
            0x89, 0x50, 0x4E, 0x47,
            0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D,
            0x49, 0x48, 0x44, 0x52
        ];
    }
}
