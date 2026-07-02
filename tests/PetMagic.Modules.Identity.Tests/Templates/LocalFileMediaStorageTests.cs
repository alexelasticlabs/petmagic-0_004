using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class LocalFileMediaStorageTests
{
    [Fact]
    public async Task DeleteAsync_ShouldRemoveManagedLocalFile()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", JpegBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var deleted = await storage.DeleteAsync(stored.Value.Url, CancellationToken.None);

            Assert.True(deleted.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldRemoveManagedLocalFile_ByStorageKey()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", JpegBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var deleted = await storage.DeleteAsync(stored.Value.StorageKey, CancellationToken.None);

            Assert.True(deleted.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldRemoveManagedLocalFile_BySignedUrl()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", JpegBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var signedUrl = $"{stored.Value.Url}?pmexp=123&pmsig=abc";
            var deleted = await storage.DeleteAsync(signedUrl, CancellationToken.None);

            Assert.True(deleted.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldIgnoreExternalUrl()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var deleted = await storage.DeleteAsync("https://cdn.example.com/preview.jpg", CancellationToken.None);

            Assert.True(deleted.IsSuccess);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldIgnoreTraversalLikeManagedPaths()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);
        var siblingPath = Path.Combine(
            Directory.GetParent(rootPath)!.FullName,
            $"petmagic-media-sibling-{Guid.NewGuid():N}.jpg");
        var unmanagedRootPath = Path.Combine(rootPath, "unmanaged-template.jpg");

        try
        {
            await File.WriteAllTextAsync(siblingPath, "sibling");
            await File.WriteAllTextAsync(unmanagedRootPath, "unmanaged");

            var siblingDelete = await storage.DeleteAsync(
                $"templates-media/../{Path.GetFileName(siblingPath)}",
                CancellationToken.None);
            var unmanagedDelete = await storage.DeleteAsync(
                "http://localhost:5000/templates-media/2026/../unmanaged-template.jpg?pmexp=123&pmsig=abc",
                CancellationToken.None);

            Assert.True(siblingDelete.IsSuccess);
            Assert.True(unmanagedDelete.IsSuccess);
            Assert.True(File.Exists(siblingPath));
            Assert.True(File.Exists(unmanagedRootPath));
        }
        finally
        {
            File.Delete(siblingPath);
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task CreateReadUrlAsync_ShouldRejectTraversalLikeManagedPath()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var readUrl = await storage.CreateReadUrlAsync(
                "http://localhost:5000/templates-media/2026/../private.png",
                TimeSpan.FromMinutes(5),
                CancellationToken.None);

            Assert.True(readUrl.IsFailure);
            Assert.Equal("templates.media_storage_failed", readUrl.Error.Code);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task CreateReadUrlAsync_ShouldRejectMalformedPublicBaseUrlPrefix()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var readUrl = await storage.CreateReadUrlAsync(
                "http://localhost:5000templates-media/2026/06/result.png",
                TimeSpan.FromMinutes(5),
                CancellationToken.None);

            Assert.True(readUrl.IsFailure);
            Assert.Equal("templates.media_storage_failed", readUrl.Error.Code);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldUseExtensionFromContentType_WhenFileNameExtensionIsUnsafe()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.html", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.EndsWith(".png", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            Assert.Equal("image/png", stored.Value.ContentType);
            Assert.DoesNotContain(".html", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldAcceptQuickTimeVideoUpload()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.mov", "video/quicktime", QuickTimeBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal("video/quicktime", stored.Value.ContentType);
            Assert.EndsWith(".mov", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            Assert.True(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Theory]
    [InlineData("templates-media/2026/06/result.png", "http://localhost:5000/templates-media/2026/06/result.png")]
    [InlineData("http://localhost:5000/templates-media/2026/06/result.png", "http://localhost:5000/templates-media/2026/06/result.png")]
    public async Task CreateReadUrlAsync_ShouldResolveManagedKeys(string assetUrl, string expected)
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var readUrl = await storage.CreateReadUrlAsync(assetUrl, TimeSpan.FromMinutes(5), CancellationToken.None);

            Assert.True(readUrl.IsSuccess);
            Assert.Equal(expected, readUrl.Value);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task CreateReadUrlAsync_ShouldRejectExternalUrl()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var readUrl = await storage.CreateReadUrlAsync(
                "https://cdn.example.com/result.png",
                TimeSpan.FromMinutes(5),
                CancellationToken.None);

            Assert.True(readUrl.IsFailure);
            Assert.Equal("templates.media_storage_failed", readUrl.Error.Code);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldRejectUnsafeOctetStreamExtension()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("payload.exe", "application/octet-stream", [1, 2, 3]),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("templates.invalid_media_upload", stored.Error.Code);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldLogWarning_WhenDirectoryCreationFails()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"petmagic-media-root-file-{Guid.NewGuid():N}");
        await File.WriteAllTextAsync(rootPath, "not-a-directory");
        var logger = new CapturingLogger<LocalFileMediaStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", JpegBytes()),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("templates.media_storage_failed", stored.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Local media store failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "store")
                    && Equals(entry.Properties["ContentType"], "image/jpeg"));
        }
        finally
        {
            File.Delete(rootPath);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldLogWarning_WhenManagedFileDeletionFails()
    {
        var rootPath = CreateTempDirectory();
        var logger = new CapturingLogger<LocalFileMediaStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", JpegBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            using var lockedFile = File.Open(
                stored.Value.LocalPath!,
                FileMode.Open,
                FileAccess.Read,
                FileShare.None);

            var deleted = await storage.DeleteAsync(stored.Value.StorageKey, CancellationToken.None);

            Assert.True(deleted.IsFailure);
            Assert.Equal("templates.media_storage_failed", deleted.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Local media delete failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "delete")
                    && Equals(entry.Properties["StorageKey"], stored.Value.StorageKey));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static LocalFileMediaStorage CreateStorage(string rootPath)
    {
        return CreateStorage(rootPath, null);
    }

    private static LocalFileMediaStorage CreateStorage(
        string rootPath,
        ILogger<LocalFileMediaStorage>? logger)
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = rootPath,
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            SeedSampleTemplates = false
        };

        return new LocalFileMediaStorage(options, new TestHostEnvironment(rootPath), logger);
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-media-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private static byte[] JpegBytes()
    {
        return [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x00, 0x00, 0x00];
    }

    private static byte[] PngBytes()
    {
        return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x00];
    }

    private static byte[] QuickTimeBytes()
    {
        return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00];
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> structured
                ? structured.ToDictionary(item => item.Key, item => item.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);
}
