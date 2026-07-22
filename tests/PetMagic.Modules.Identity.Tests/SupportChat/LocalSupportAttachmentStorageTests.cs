using System.Linq;

using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Observability;
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
    public async Task StoreAsync_ShouldRejectImageStream_WhenActualBytesExceedLimit()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxImageFileSizeBytes = 64
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);
        var payload = PngBytes();

        try
        {
            Assert.True(payload.Length > 64);
            await using var stream = new MemoryStream(payload);

            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    stream,
                    contentLengthBytes: 8),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("support.attachment_file_too_large", stored.Error.Code);
            Assert.Empty(Directory.GetFiles(rootPath, "*", SearchOption.AllDirectories));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldRejectVideoStream_WhenActualBytesExceedLimit()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxVideoFileSizeBytes = 32
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);
        var payload = Mp4Bytes(128);

        try
        {
            await using var stream = new MemoryStream(payload);

            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.mp4",
                    "video/mp4",
                    stream,
                    contentLengthBytes: 12),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("support.attachment_file_too_large", stored.Error.Code);
            Assert.Empty(Directory.GetFiles(rootPath, "*", SearchOption.AllDirectories));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldWriteCompleteVideo_WhenStreamCannotSeek()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxVideoFileSizeBytes = 256
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);
        var payload = Mp4Bytes(96);

        try
        {
            await using var stream = new NonSeekableReadStream(payload);

            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.mp4",
                    "video/mp4",
                    stream,
                    contentLengthBytes: payload.LongLength),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal(payload.LongLength, stored.Value.FileSizeBytes);
            Assert.Equal(payload, await File.ReadAllBytesAsync(stored.Value.LocalPath!));
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
    public async Task DeleteAsync_ShouldIgnoreTraversalLikeManagedPaths()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);
        var siblingPath = Path.Combine(
            Directory.GetParent(rootPath)!.FullName,
            $"petmagic-support-sibling-{Guid.NewGuid():N}.jpg");
        var unmanagedRootPath = Path.Combine(rootPath, "unmanaged-support.jpg");
        var encodedSeparatorFilePath = Path.Combine(rootPath, "2026%2f..%2fencoded-support.jpg");
        var malformedPercentDirectory = Path.Combine(rootPath, "2026");
        var malformedPercentFilePath = Path.Combine(malformedPercentDirectory, "%zz-private-support.jpg");

        try
        {
            await File.WriteAllTextAsync(siblingPath, "sibling");
            await File.WriteAllTextAsync(unmanagedRootPath, "unmanaged");
            await File.WriteAllTextAsync(encodedSeparatorFilePath, "encoded-separator");
            Directory.CreateDirectory(malformedPercentDirectory);
            await File.WriteAllTextAsync(malformedPercentFilePath, "malformed-percent");

            var siblingDelete = await storage.DeleteAsync(
                $"support-attachments/../{Path.GetFileName(siblingPath)}",
                CancellationToken.None);
            var unmanagedDelete = await storage.DeleteAsync(
                "http://localhost:5000/support-attachments/2026/../unmanaged-support.jpg?pmexp=123&pmsig=abc",
                CancellationToken.None);
            var encodedSeparatorDelete = await storage.DeleteAsync(
                "http://localhost:5000/support-attachments/2026%2f..%2fencoded-support.jpg",
                CancellationToken.None);
            var malformedPercentDelete = await storage.DeleteAsync(
                "http://localhost:5000/support-attachments/2026/%zz-private-support.jpg",
                CancellationToken.None);

            Assert.True(siblingDelete.IsSuccess);
            Assert.True(unmanagedDelete.IsSuccess);
            Assert.True(encodedSeparatorDelete.IsSuccess);
            Assert.True(malformedPercentDelete.IsSuccess);
            Assert.True(File.Exists(siblingPath));
            Assert.True(File.Exists(unmanagedRootPath));
            Assert.True(File.Exists(encodedSeparatorFilePath));
            Assert.True(File.Exists(malformedPercentFilePath));
        }
        finally
        {
            File.Delete(siblingPath);
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldIgnoreMalformedPublicBaseUrlPrefix()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);
        var unmanagedRootPath = Path.Combine(rootPath, "prefix-support.jpg");

        try
        {
            await File.WriteAllTextAsync(unmanagedRootPath, "unmanaged");

            var deleteResult = await storage.DeleteAsync(
                "http://localhost:5000support-attachments/prefix-support.jpg",
                CancellationToken.None);

            Assert.True(deleteResult.IsSuccess);
            Assert.True(File.Exists(unmanagedRootPath));
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
                    && Equals(entry.Properties["ContentType"], "image/jpeg")
                    && Equals(entry.Properties["ExceptionType"], "IOException")
                    && entry.Exception is null
                    && entry.Properties["StorageKeyHash"] is string { Length: 16 }
                    && !entry.Properties.ContainsKey("StorageKey")
                    && !ContainsLogValue(entry, rootPath));
        }
        finally
        {
            File.Delete(rootPath);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldRespectHostFileLockSemantics_WhenManagedFileIsOpen()
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

            if (OperatingSystem.IsWindows())
            {
                Assert.True(deleted.IsFailure);
                Assert.Equal("support.attachment_storage_failed", deleted.Error.Code);
                Assert.Contains(
                    logger.Entries,
                    entry => entry.Level == LogLevel.Warning
                        && entry.Message.Contains("Support attachment delete failed.", StringComparison.Ordinal)
                        && Equals(entry.Properties["Operation"], "delete")
                        && Equals(entry.Properties["StorageKeyHash"], SafeLogValues.StableHash(stored.Value.StorageKey))
                        && Equals(entry.Properties["ExceptionType"], "IOException")
                        && entry.Exception is null
                        && !entry.Properties.ContainsKey("StorageKey")
                        && !ContainsLogValue(entry, stored.Value.StorageKey)
                        && !ContainsLogValue(entry, stored.Value.LocalPath!));
            }
            else
            {
                Assert.True(deleted.IsSuccess);
                Assert.False(File.Exists(stored.Value.LocalPath));
            }
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static bool ContainsLogValue(CapturedLogEntry entry, string value)
    {
        return entry.Message.Contains(value, StringComparison.Ordinal)
            || entry.Properties.Values.Any(property =>
                property?.ToString()?.Contains(value, StringComparison.Ordinal) == true)
            || entry.Exception?.ToString().Contains(value, StringComparison.Ordinal) == true;
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

    private static byte[] Mp4Bytes(int length)
    {
        var bytes = new byte[length];
        bytes[0] = 0x00;
        bytes[1] = 0x00;
        bytes[2] = 0x00;
        bytes[3] = 0x18;
        bytes[4] = 0x66;
        bytes[5] = 0x74;
        bytes[6] = 0x79;
        bytes[7] = 0x70;
        bytes[8] = 0x6D;
        bytes[9] = 0x70;
        bytes[10] = 0x34;
        bytes[11] = 0x32;
        return bytes;
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

    private sealed class NonSeekableReadStream(byte[] content) : Stream
    {
        private readonly MemoryStream inner = new(content);

        public override bool CanRead => true;

        public override bool CanSeek => false;

        public override bool CanWrite => false;

        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override void Flush()
        {
        }

        public override int Read(byte[] buffer, int offset, int count)
            => inner.Read(buffer, offset, count);

        public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
            => inner.ReadAsync(buffer, cancellationToken);

        public override long Seek(long offset, SeekOrigin origin)
            => throw new NotSupportedException();

        public override void SetLength(long value)
            => throw new NotSupportedException();

        public override void Write(byte[] buffer, int offset, int count)
            => throw new NotSupportedException();

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                inner.Dispose();
            }

            base.Dispose(disposing);
        }
    }
}
