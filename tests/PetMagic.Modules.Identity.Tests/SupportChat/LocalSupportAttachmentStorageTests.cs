using System.Linq;

using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class LocalSupportAttachmentStorageTests
{
    [Fact]
    public async Task StoreAsync_ShouldNormalizeImageAttachmentToJpeg()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal("image/jpeg", stored.Value.ContentType);
            Assert.EndsWith(".jpg", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            var bytes = await File.ReadAllBytesAsync(stored.Value.LocalPath!);
            Assert.Equal((byte)0xFF, bytes[0]);
            Assert.Equal((byte)0xD8, bytes[1]);
            Assert.Equal((byte)0xFF, bytes[2]);
            using var normalized = Image.Load(bytes);
            Assert.Equal(1800, normalized.Width);
            Assert.Equal(1350, normalized.Height);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldRejectUnsupportedIsoBmffBrandForVideoUpload()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.mp4",
                    "video/mp4",
                    HeicFtypBytes()),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("support.attachment_mime_mismatch", stored.Error.Code);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldDeleteStoredAttachment_WhenCalledWithStorageKey()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var deleteResult = await storage.DeleteAsync(stored.Value.StorageKey, CancellationToken.None);

            Assert.True(deleteResult.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldDeleteStoredAttachment_WhenCalledWithSignedUrl()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var signedUrl = $"{stored.Value.Url}?pmexp=123&pmsig=abc";
            var deleteResult = await storage.DeleteAsync(signedUrl, CancellationToken.None);

            Assert.True(deleteResult.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldLogWarning_WhenDirectoryCreationFails()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"petmagic-support-root-file-{Guid.NewGuid():N}");
        await File.WriteAllTextAsync(rootPath, "not-a-directory");
        var logger = new CapturingLogger<LocalSupportAttachmentStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("support.attachment_storage_failed", stored.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Support attachment store failed.", StringComparison.Ordinal)
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
        var logger = new CapturingLogger<LocalSupportAttachmentStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            using var lockedFile = File.Open(
                stored.Value.LocalPath!,
                FileMode.Open,
                FileAccess.Read,
                FileShare.None);

            var deleted = await storage.DeleteAsync(stored.Value.StorageKey, CancellationToken.None);

            Assert.True(deleted.IsFailure);
            Assert.Equal("support.attachment_storage_failed", deleted.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Support attachment delete failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "delete")
                    && Equals(entry.Properties["StorageKey"], stored.Value.StorageKey));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static LocalSupportAttachmentStorage CreateStorage(
        string rootPath,
        ILogger<LocalSupportAttachmentStorage>? logger = null)
    {
        return new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            logger ?? NullLogger<LocalSupportAttachmentStorage>.Instance);
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-support-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private static byte[] PngBytes()
    {
        using var image = new Image<Rgba32>(2400, 1800);
        for (var y = 0; y < image.Height; y++)
        {
            for (var x = 0; x < image.Width; x++)
            {
                image[x, y] = new Rgba32(
                    (byte)((x * 31 + y * 17) & 0xFF),
                    (byte)((x * 13 + y * 29) & 0xFF),
                    (byte)((x * 7 + y * 19) & 0xFF));
            }
        }

        using var buffer = new MemoryStream();
        image.Save(buffer, new PngEncoder());
        return buffer.ToArray();
    }

    private static byte[] HeicFtypBytes()
    {
        return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0x00, 0x00, 0x00, 0x00];
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
