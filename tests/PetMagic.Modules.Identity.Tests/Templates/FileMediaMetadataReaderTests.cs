using System.Buffers.Binary;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FileMediaMetadataReaderTests
{
    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldReadMp4Version0Duration()
    {
        var filePath = CreateTempFile(BuildMp4WithMovieHeader(timescale: 1000, duration: 7250, version: 0));
        var reader = new FileMediaMetadataReader();

        try
        {
            var result = await reader.GetVideoDurationSecondsAsync(
                new StoredMediaResponse("https://cdn.example.com/video.mp4", "templates/video.mp4", "video.mp4", "video/mp4", null, filePath),
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal(7.25, result.Value);
        }
        finally
        {
            File.Delete(filePath);
        }
    }

    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldReadMp4Version1Duration()
    {
        var filePath = CreateTempFile(BuildMp4WithMovieHeader(timescale: 48000, duration: 360000, version: 1));
        var reader = new FileMediaMetadataReader();

        try
        {
            var result = await reader.GetVideoDurationSecondsAsync(
                new StoredMediaResponse("https://cdn.example.com/video.mp4", "templates/video.mp4", "video.mp4", "video/mp4", null, filePath),
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal(7.5, result.Value);
        }
        finally
        {
            File.Delete(filePath);
        }
    }

    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldReturnNull_WhenFileDoesNotExist()
    {
        var reader = new FileMediaMetadataReader();

        var result = await reader.GetVideoDurationSecondsAsync(
            new StoredMediaResponse("https://cdn.example.com/missing.mp4", "templates/missing.mp4", "missing.mp4", "video/mp4", null, Path.Combine(Path.GetTempPath(), $"missing-{Guid.NewGuid():N}.mp4")),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Null(result.Value);
    }

    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldReturnNull_ForNonMp4Video()
    {
        var filePath = CreateTempFile([0x1A, 0x45, 0xDF, 0xA3, 0x93], ".webm");
        var reader = new FileMediaMetadataReader();

        try
        {
            var result = await reader.GetVideoDurationSecondsAsync(
                new StoredMediaResponse("https://cdn.example.com/video.webm", "templates/video.webm", "video.webm", "video/webm", null, filePath),
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Null(result.Value);
        }
        finally
        {
            File.Delete(filePath);
        }
    }

    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldFail_WhenMp4PayloadIsMalformed()
    {
        var filePath = CreateTempFile([1, 2, 3, 4, 5, 6, 7, 8]);
        var logger = new CapturingLogger<FileMediaMetadataReader>();
        var reader = new FileMediaMetadataReader(logger);

        try
        {
            var result = await reader.GetVideoDurationSecondsAsync(
                new StoredMediaResponse("https://cdn.example.com/bad.mp4", "templates/bad.mp4", "bad.mp4", "video/mp4", null, filePath),
                CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.media_metadata_failed", result.Error.Code);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Template media metadata read failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "read_mp4_duration")
                    && !entry.Properties.ContainsKey("FileName")
                    && Equals(entry.Properties["FileNameHash"], SafeLogValues.StableHash("bad.mp4"))
                    && Equals(entry.Properties["ContentType"], "video/mp4"));
        }
        finally
        {
            File.Delete(filePath);
        }
    }

    [Fact]
    public async Task GetVideoDurationSecondsAsync_ShouldRespectHostFileLockSemantics_ForOwnedTempFile()
    {
        var logger = new CapturingLogger<FileMediaMetadataReader>();
        var reader = new FileMediaMetadataReader(logger);
        var filePath = await TemplateMediaTempFiles.WriteAsync([1, 2, 3, 4], ".mp4", CancellationToken.None);
        await using var lockStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.None);

        try
        {
            var result = await reader.GetVideoDurationSecondsAsync(
                new StoredMediaResponse(
                    "https://cdn.example.com/locked.mp4",
                    "templates/locked.mp4",
                    "locked.mp4",
                    "video/mp4",
                    null,
                    filePath),
                CancellationToken.None);

            Assert.True(result.IsFailure);
            if (OperatingSystem.IsWindows())
            {
                Assert.Contains(
                    logger.Entries,
                    entry => entry.Level == LogLevel.Warning
                        && entry.Message.Contains("Template metadata temp file cleanup failed.", StringComparison.Ordinal)
                        && Equals(entry.Properties["Operation"], "delete_owned")
                        && Equals(entry.Properties["TempFileName"], Path.GetFileName(filePath))
                        && Equals(entry.Properties["ExceptionType"], "IOException"));
            }
            else
            {
                Assert.Contains(
                    logger.Entries,
                    entry => entry.Level == LogLevel.Warning
                        && entry.Message.Contains("Template media metadata read threw", StringComparison.Ordinal)
                        && Equals(entry.Properties["Operation"], "read_mp4_duration")
                        && Equals(entry.Properties["ExceptionType"], "IOException"));
                Assert.False(File.Exists(filePath));
            }
        }
        finally
        {
            lockStream.Dispose();
            TemplateMediaTempFiles.TryDeleteIfOwned(filePath);
        }
    }

    private static string CreateTempFile(byte[] content, string extension = ".mp4")
    {
        var filePath = Path.Combine(Path.GetTempPath(), $"petmagic-media-{Guid.NewGuid():N}{extension}");
        File.WriteAllBytes(filePath, content);
        return filePath;
    }

    private static byte[] BuildMp4WithMovieHeader(uint timescale, ulong duration, byte version)
    {
        var payload = version == 0
            ? BuildVersion0MovieHeader(timescale, checked((uint)duration))
            : BuildVersion1MovieHeader(timescale, duration);

        var mvhd = BuildBox("mvhd", payload);
        var moov = BuildBox("moov", mvhd);
        var ftyp = BuildBox("ftyp", "isom0000isomiso2"u8.ToArray());

        return [.. ftyp, .. moov];
    }

    private static byte[] BuildVersion0MovieHeader(uint timescale, uint duration)
    {
        var buffer = new byte[20];
        buffer[0] = 0;
        BinaryPrimitives.WriteUInt32BigEndian(buffer.AsSpan(12, 4), timescale);
        BinaryPrimitives.WriteUInt32BigEndian(buffer.AsSpan(16, 4), duration);
        return buffer;
    }

    private static byte[] BuildVersion1MovieHeader(uint timescale, ulong duration)
    {
        var buffer = new byte[32];
        buffer[0] = 1;
        BinaryPrimitives.WriteUInt32BigEndian(buffer.AsSpan(20, 4), timescale);
        BinaryPrimitives.WriteUInt64BigEndian(buffer.AsSpan(24, 8), duration);
        return buffer;
    }

    private static byte[] BuildBox(string type, byte[] payload)
    {
        var box = new byte[8 + payload.Length];
        BinaryPrimitives.WriteUInt32BigEndian(box.AsSpan(0, 4), (uint)box.Length);
        box[4] = (byte)type[0];
        box[5] = (byte)type[1];
        box[6] = (byte)type[2];
        box[7] = (byte)type[3];
        payload.CopyTo(box, 8);
        return box;
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

            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), properties));
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
        IReadOnlyDictionary<string, object?> Properties);
}
