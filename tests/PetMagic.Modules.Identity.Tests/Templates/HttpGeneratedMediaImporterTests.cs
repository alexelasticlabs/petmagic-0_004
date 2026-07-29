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
    public void GeneratedMediaConnectionGuard_ShouldRejectMixedPublicAndPrivateDnsAnswer()
    {
        var target = new DnsEndPoint("cdn.example.com", 443);
        var addresses = new[]
        {
            IPAddress.Parse("93.184.216.34"),
            IPAddress.Parse("169.254.169.254")
        };

        var exception = Assert.Throws<HttpRequestException>(() =>
            GeneratedMediaHttpMessageHandler.BuildValidatedEndpoints(target, addresses));

        Assert.Contains("non-public", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void GeneratedMediaConnectionGuard_ShouldPinConnectionToValidatedPublicAddress()
    {
        var target = new DnsEndPoint("cdn.example.com", 443);
        var publicAddress = IPAddress.Parse("93.184.216.34");

        var endpoints = GeneratedMediaHttpMessageHandler.BuildValidatedEndpoints(
            target,
            new[] { publicAddress });

        var endpoint = Assert.Single(endpoints);
        Assert.Equal(publicAddress, endpoint.Address);
        Assert.Equal(443, endpoint.Port);
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
    public async Task ImportVideoAsync_ShouldSpoolProviderPayloadToFileInsteadOfBufferingItInMemory()
    {
        var payload = new byte[2 * 1024 * 1024];
        payload[4] = 0x66;
        payload[5] = 0x74;
        payload[6] = 0x79;
        payload[7] = 0x70;
        payload[8] = 0x69;
        payload[9] = 0x73;
        payload[10] = 0x6F;
        payload[11] = 0x6D;
        var handler = new RecordingHandler("video/mp4", payload);
        var storage = new RecordingMediaStorage(copyContent: true);
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportVideoAsync(
            "https://cdn.example.com/generated.mp4",
            Guid.NewGuid(),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(storage.LastAsset?.ContentStream);
        Assert.IsType<FileStream>(storage.LastAsset.ContentStream);
        Assert.Equal(payload.Length, storage.CopiedContentLength);
        Assert.NotNull(storage.LastSpoolPath);
        Assert.False(File.Exists(storage.LastSpoolPath));
    }

    [Fact]
    public async Task ImportImageAsync_ShouldDeleteSpoolWhenUnknownLengthPayloadExceedsLimit()
    {
        var generationId = Guid.NewGuid();
        var payload = PngPayload().Concat(new byte[64]).ToArray();
        var handler = new RecordingHandler("image/png", payload, omitContentLength: true);
        var storage = new RecordingMediaStorage();
        var importer = CreateImporter(
            handler,
            storage,
            generatedImageMaxFileSizeBytes: PngPayload().Length);

        var result = await importer.ImportImageAsync(
            "https://cdn.example.com/generated.png",
            generationId,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaTooLarge.Code, result.Error.Code);
        Assert.Equal(0, storage.StoreCount);
        AssertNoSpoolFiles(generationId);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldDeleteSpoolWhenStorageThrows()
    {
        var generationId = Guid.NewGuid();
        var handler = new RecordingHandler("image/png", PngPayload());
        var storage = new RecordingMediaStorage(throwDuringStore: true);
        var importer = CreateImporter(handler, storage);

        var result = await importer.ImportImageAsync(
            "https://cdn.example.com/generated.png",
            generationId,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GeneratedMediaImportFailed.Code, result.Error.Code);
        Assert.NotNull(storage.LastSpoolPath);
        Assert.False(File.Exists(storage.LastSpoolPath));
        AssertNoSpoolFiles(generationId);
    }

    [Fact]
    public async Task ImportImageAsync_ShouldDeleteSpoolWhenStorageCancels()
    {
        var generationId = Guid.NewGuid();
        var handler = new RecordingHandler("image/png", PngPayload());
        var storage = new RecordingMediaStorage(cancelDuringStore: true);
        var importer = CreateImporter(handler, storage);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => importer.ImportImageAsync(
            "https://cdn.example.com/generated.png",
            generationId,
            CancellationToken.None));

        Assert.NotNull(storage.LastSpoolPath);
        Assert.False(File.Exists(storage.LastSpoolPath));
        AssertNoSpoolFiles(generationId);
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
        Assert.NotNull(storage.LastSpoolPath);
        Assert.False(File.Exists(storage.LastSpoolPath));
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

    private static HttpGeneratedMediaImporter CreateImporter(
        HttpMessageHandler handler,
        RecordingMediaStorage? storage = null,
        long? generatedImageMaxFileSizeBytes = null)
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
            SupportedLocalizationLocales = ["en"],
            GeneratedImageMaxFileSizeBytes = generatedImageMaxFileSizeBytes
                ?? 30L * 1024 * 1024
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

    private sealed class RecordingHandler(
        string contentType,
        byte[] payload,
        bool omitContentLength = false) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestCount++;
            HttpContent content = omitContentLength
                ? new UnknownLengthContent(payload)
                : new ByteArrayContent(payload);
            content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = content
            });
        }
    }

    private sealed class UnknownLengthContent(byte[] payload) : HttpContent
    {
        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context)
        {
            return stream.WriteAsync(payload, 0, payload.Length);
        }

        protected override bool TryComputeLength(out long length)
        {
            length = 0;
            return false;
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

    private sealed class RecordingMediaStorage(
        string? failureCode = null,
        bool copyContent = false,
        bool throwDuringStore = false,
        bool cancelDuringStore = false) : IMediaStorage
    {
        public int StoreCount { get; private set; }

        public async Task<Result<StoredMediaResponse>> StoreAsync(
            MediaUploadCommand asset,
            CancellationToken cancellationToken)
        {
            StoreCount++;
            LastAsset = asset;
            LastSpoolPath = (asset.ContentStream as FileStream)?.Name;
            if (cancelDuringStore)
            {
                throw new OperationCanceledException("Storage write was cancelled.", cancellationToken);
            }

            if (throwDuringStore)
            {
                throw new InvalidOperationException("Storage write failed.");
            }

            if (failureCode is not null)
            {
                return Result.Failure<StoredMediaResponse>(
                    new Error(failureCode, "Media upload could not be stored."));
            }

            if (copyContent && asset.ContentStream is not null)
            {
                await asset.ContentStream.CopyToAsync(Stream.Null, cancellationToken);
                CopiedContentLength = asset.ContentStream.Position;
            }

            return Result.Success(new StoredMediaResponse(
                "https://cdn.example.com/stored/generated.png",
                "templates/generated.png",
                asset.FileName,
                asset.ContentType,
                asset.ContentLengthBytes,
                null));
        }

        public MediaUploadCommand? LastAsset { get; private set; }

        public string? LastSpoolPath { get; private set; }

        public long CopiedContentLength { get; private set; }

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

    private static void AssertNoSpoolFiles(Guid generationId)
    {
        Assert.Empty(Directory.GetFiles(
            Path.GetTempPath(),
            $"petmagic-generated-media-{generationId:N}-*.tmp"));
    }
}
