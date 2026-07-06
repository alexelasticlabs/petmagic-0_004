using System.Linq;

using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class LocalAvatarStorageTests
{
    [Fact]
    public async Task StoreAsync_ShouldNormalizePngAvatarToJpeg()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalAvatarStorage(
            new AvatarStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxFileSizeBytes = 8 * 1024 * 1024
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalAvatarStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal("image/jpeg", stored.Value.ContentType);
            Assert.EndsWith(".jpg", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            Assert.NotNull(stored.Value.LocalPath);
            var bytes = await File.ReadAllBytesAsync(stored.Value.LocalPath!);
            Assert.Equal((byte)0xFF, bytes[0]);
            Assert.Equal((byte)0xD8, bytes[1]);
            Assert.Equal((byte)0xFF, bytes[2]);
            using var normalized = Image.Load(bytes);
            Assert.Equal(1200, normalized.Width);
            Assert.Equal(900, normalized.Height);
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
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.NotNull(stored.Value.LocalPath);
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
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.NotNull(stored.Value.LocalPath);
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
    public async Task DeleteAsync_ShouldIgnoreTraversalLikeManagedPaths()
    {
        var rootPath = CreateTempDirectory();
        var siblingPath = Path.Combine(
            Directory.GetParent(rootPath)!.FullName,
            $"petmagic-avatar-escape-{Guid.NewGuid():N}.jpg");
        var rootFilePath = Path.Combine(rootPath, "escape-avatar.jpg");
        var encodedSeparatorFilePath = Path.Combine(rootPath, "2026%2f..%2fencoded-avatar.jpg");
        var malformedPercentDirectory = Path.Combine(rootPath, "2026");
        var malformedPercentFilePath = Path.Combine(malformedPercentDirectory, "%zz-private-avatar.jpg");
        var storage = CreateStorage(rootPath);

        try
        {
            await File.WriteAllTextAsync(siblingPath, "outside-root");
            await File.WriteAllTextAsync(rootFilePath, "inside-root");
            await File.WriteAllTextAsync(encodedSeparatorFilePath, "encoded-separator");
            Directory.CreateDirectory(malformedPercentDirectory);
            await File.WriteAllTextAsync(malformedPercentFilePath, "malformed-percent");

            var siblingDelete = await storage.DeleteAsync(
                "user-avatars/../" + Path.GetFileName(siblingPath),
                CancellationToken.None);
            var rootDelete = await storage.DeleteAsync(
                "http://localhost:5000/user-avatars/2026/../escape-avatar.jpg?pmexp=123&pmsig=abc",
                CancellationToken.None);
            var encodedSeparatorDelete = await storage.DeleteAsync(
                "http://localhost:5000/user-avatars/2026%2f..%2fencoded-avatar.jpg",
                CancellationToken.None);
            var malformedPercentDelete = await storage.DeleteAsync(
                "http://localhost:5000/user-avatars/2026/%zz-private-avatar.jpg",
                CancellationToken.None);

            Assert.True(siblingDelete.IsSuccess);
            Assert.True(rootDelete.IsSuccess);
            Assert.True(encodedSeparatorDelete.IsSuccess);
            Assert.True(malformedPercentDelete.IsSuccess);
            Assert.True(File.Exists(siblingPath));
            Assert.True(File.Exists(rootFilePath));
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
        var unmanagedRootPath = Path.Combine(rootPath, "prefix-avatar.jpg");

        try
        {
            await File.WriteAllTextAsync(unmanagedRootPath, "unmanaged");

            var deleteResult = await storage.DeleteAsync(
                "http://localhost:5000user-avatars/prefix-avatar.jpg",
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
    public async Task StoreAsync_ShouldRejectOversizedStreamBeforeReadingBody()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalAvatarStorage(
            new AvatarStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxFileSizeBytes = 128
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalAvatarStorage>.Instance);

        try
        {
            await using var stream = new ThrowingReadStream();

            var stored = await storage.StoreAsync(
                new AvatarUploadCommand("avatar.png", "image/png", stream, contentLengthBytes: 129),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("users.avatar_file_too_large", stored.Error.Code);
            Assert.False(stream.ReadAttempted);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task StoreAsync_ShouldLogWarning_WhenDirectoryCreationOrWriteFails()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"petmagic-avatar-root-file-{Guid.NewGuid():N}");
        await File.WriteAllTextAsync(rootPath, "not-a-directory");
        var logger = new CapturingLogger<LocalAvatarStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsFailure);
            Assert.Equal("users.avatar_storage_failed", stored.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Avatar storage write failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "store")
                    && Equals(entry.Properties["ContentType"], "image/jpeg")
                    && Equals(entry.Properties["ExceptionType"], "IOException")
                    && entry.Exception is null
                    && !ContainsLogValue(entry, rootPath));
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
        var logger = new CapturingLogger<LocalAvatarStorage>();
        var storage = CreateStorage(rootPath, logger);

        try
        {
            var stored = await storage.StoreAsync(
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.NotNull(stored.Value.LocalPath);
            await using var lockStream = new FileStream(
                stored.Value.LocalPath!,
                FileMode.Open,
                FileAccess.Read,
                FileShare.None);

            var deleted = await storage.DeleteAsync(stored.Value.StorageKey, CancellationToken.None);

            Assert.True(deleted.IsFailure);
            Assert.Equal("users.avatar_storage_failed", deleted.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Avatar storage delete failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "delete")
                    && Equals(entry.Properties["StorageKeyHash"], SafeLogValues.StableHash(stored.Value.StorageKey))
                    && Equals(entry.Properties["ExceptionType"], "IOException")
                    && entry.Exception is null
                    && !entry.Properties.ContainsKey("AvatarFileName")
                    && !ContainsLogValue(entry, stored.Value.StorageKey)
                    && !ContainsLogValue(entry, stored.Value.LocalPath!));
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

    private static LocalAvatarStorage CreateStorage(
        string rootPath,
        ILogger<LocalAvatarStorage>? logger = null)
    {
        return new LocalAvatarStorage(
            new AvatarStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxFileSizeBytes = 8 * 1024 * 1024
            },
            new TestHostEnvironment(rootPath),
            logger ?? NullLogger<LocalAvatarStorage>.Instance);
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-avatar-{Guid.NewGuid():N}");
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

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private sealed class ThrowingReadStream : Stream
    {
        public bool ReadAttempted { get; private set; }

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
        {
            ReadAttempted = true;
            throw new InvalidOperationException("The oversized stream body should not be read.");
        }

        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();

        public override void SetLength(long value) => throw new NotSupportedException();

        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
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
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values
                    .Where(x => !string.Equals(x.Key, "{OriginalFormat}", StringComparison.Ordinal))
                    .ToDictionary(x => x.Key, x => x.Value)
                : [];

            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }

        private sealed class NullScope : IDisposable
        {
            public static readonly NullScope Instance = new();

            public void Dispose()
            {
            }
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);
}
