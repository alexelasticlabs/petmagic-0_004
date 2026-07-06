using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class R2MediaStorageLoggingTests
{
    [Fact]
    public async Task DeleteAsync_ShouldLogWarning_WhenS3DeleteThrows()
    {
        var logger = new CapturingLogger<R2MediaStorage>();
        var storage = CreateStorage(logger);
        const string storageKey = "templates-media/2026/07/result.png";

        var result = await storage.DeleteAsync(
            $"https://cdn.petmagic.test/{storageKey}",
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Contains(
            logger.Entries,
            entry => entry.Level == LogLevel.Warning
                && entry.Message.Contains("R2 media delete failed.", StringComparison.Ordinal)
                && Equals(entry.Properties["Operation"], "delete")
                && Equals(entry.Properties["StorageKeyHash"], SafeLogValues.StableHash(storageKey))
                && Equals(entry.Properties["ExceptionType"], "NullReferenceException")
                && !ContainsLogValue(entry, storageKey));
    }

    [Fact]
    public async Task CreateReadUrlAsync_ShouldLogWarning_WhenSigningThrows()
    {
        var logger = new CapturingLogger<R2MediaStorage>();
        var storage = CreateStorage(logger);
        const string storageKey = "templates-media/2026/07/result.png";

        var result = await storage.CreateReadUrlAsync(
            $"https://cdn.petmagic.test/{storageKey}",
            TimeSpan.FromMinutes(5),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Contains(
            logger.Entries,
            entry => entry.Level == LogLevel.Warning
                && entry.Message.Contains("R2 media read-url signing failed.", StringComparison.Ordinal)
                && Equals(entry.Properties["Operation"], "sign_read_url")
                && Equals(entry.Properties["StorageKeyHash"], SafeLogValues.StableHash(storageKey))
                && Equals(entry.Properties["ExceptionType"], "NullReferenceException")
                && !ContainsLogValue(entry, storageKey));
    }

    [Fact]
    public async Task StoreAsync_ShouldLogWarning_WhenUploadThrows()
    {
        var logger = new CapturingLogger<R2MediaStorage>();
        var storage = CreateStorage(logger);
        const string storageKey = "templates-media/tests/tiny.png";

        var result = await storage.StoreAsync(
            new MediaUploadCommand(
                "tiny.png",
                "image/png",
                TinyPngBytes,
                null,
                TinyPngBytes.LongLength,
                "tests/tiny.png"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Contains(
            logger.Entries,
            entry => entry.Level == LogLevel.Warning
                && entry.Message.Contains("R2 media store failed.", StringComparison.Ordinal)
                && Equals(entry.Properties["Operation"], "store")
                && Equals(entry.Properties["StorageKeyHash"], SafeLogValues.StableHash(storageKey))
                && Equals(entry.Properties["ContentLength"], TinyPngBytes.LongLength)
                && Equals(entry.Properties["HasPreferredStorageKey"], true)
                && Equals(entry.Properties["ExceptionType"], "NullReferenceException")
                && !ContainsLogValue(entry, storageKey));
    }

    private static bool ContainsLogValue(CapturedLogEntry entry, string value)
    {
        return entry.Message.Contains(value, StringComparison.Ordinal)
            || entry.Properties.Values.Any(property =>
                property?.ToString()?.Contains(value, StringComparison.Ordinal) == true);
    }

    private static R2MediaStorage CreateStorage(ILogger<R2MediaStorage> logger)
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "unused",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            SeedSampleTemplates = false,
            R2 = new R2StorageOptions
            {
                AccountId = "account",
                AccessKey = "access",
                SecretKey = "secret",
                BucketName = "bucket",
                PublicBaseUrl = "https://cdn.petmagic.test",
                ObjectKeyPrefix = "templates-media"
            }
        };

        return new R2MediaStorage(options, null!, logger);
    }

    private static readonly byte[] TinyPngBytes =
    [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
        0xB1, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
    ];

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
