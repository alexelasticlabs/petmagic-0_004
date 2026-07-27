using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class DataProtectionCertificateLoaderTests
{
    [Fact]
    public void LoadOrCreateDevelopmentCertificate_ShouldGenerateNewCertificate_WhenMissing()
    {
        var tempDirectory = CreateTempDirectory();
        try
        {
            var certificatePath = Path.Combine(tempDirectory, "petmagic-data-protection-dev.pfx");
            var logger = new CapturingLogger();

            using var certificate = DataProtectionCertificateLoader.LoadOrCreateDevelopmentCertificate(
                certificatePath,
                "test-password",
                "PetMagic.Host.Api",
                logger);

            Assert.True(File.Exists(certificatePath));
            Assert.False(string.IsNullOrWhiteSpace(certificate.Thumbprint));
            Assert.True(certificate.HasPrivateKey);
            var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Information);
            Assert.Contains("Development Data Protection certificate generated.", entry.Message, StringComparison.Ordinal);
            Assert.Equal(Path.GetFileName(certificatePath), entry.Properties["CertificateFileName"]);
            Assert.Equal(SafeLogValues.StableHash(certificatePath), entry.Properties["CertificatePathHash"]);
            Assert.DoesNotContain("CertificatePath", entry.Properties.Keys);
            Assert.Equal("PetMagic.Host.Api", entry.Properties["ApplicationName"]);
        }
        finally
        {
            Directory.Delete(tempDirectory, recursive: true);
        }
    }

    [Fact]
    public void LoadOrCreateDevelopmentCertificate_ShouldReloadExistingCertificate_WithPrivateKey()
    {
        var tempDirectory = CreateTempDirectory();
        try
        {
            var certificatePath = Path.Combine(tempDirectory, "petmagic-data-protection-dev.pfx");

            using var generatedCertificate = DataProtectionCertificateLoader.LoadOrCreateDevelopmentCertificate(
                certificatePath,
                "test-password",
                "PetMagic.Host.Api");
            using var reloadedCertificate = DataProtectionCertificateLoader.LoadOrCreateDevelopmentCertificate(
                certificatePath,
                "test-password",
                "PetMagic.Host.Api");

            Assert.Equal(generatedCertificate.Thumbprint, reloadedCertificate.Thumbprint);
            Assert.True(reloadedCertificate.HasPrivateKey);
            using var privateKey = reloadedCertificate.GetRSAPrivateKey();
            Assert.NotNull(privateKey);
        }
        finally
        {
            Directory.Delete(tempDirectory, recursive: true);
        }
    }

    [Fact]
    public void LoadOrCreateDevelopmentCertificate_ShouldRegenerateUnreadableCertificate_AndLogWarning()
    {
        var tempDirectory = CreateTempDirectory();
        try
        {
            var certificatePath = Path.Combine(tempDirectory, "petmagic-data-protection-dev.pfx");
            File.WriteAllBytes(certificatePath, [1, 2, 3, 4, 5]);
            var logger = new CapturingLogger();

            using var certificate = DataProtectionCertificateLoader.LoadOrCreateDevelopmentCertificate(
                certificatePath,
                "test-password",
                "PetMagic.Host.Api",
                logger);

            Assert.True(File.Exists(certificatePath));
            Assert.False(string.IsNullOrWhiteSpace(certificate.Thumbprint));

            var warning = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
            Assert.Contains("Development Data Protection certificate is unreadable and will be regenerated.", warning.Message, StringComparison.Ordinal);
            Assert.Equal(Path.GetFileName(certificatePath), warning.Properties["CertificateFileName"]);
            Assert.Equal(SafeLogValues.StableHash(certificatePath), warning.Properties["CertificatePathHash"]);
            Assert.DoesNotContain("CertificatePath", warning.Properties.Keys);
            Assert.Equal("PetMagic.Host.Api", warning.Properties["ApplicationName"]);
            Assert.Equal(nameof(CryptographicException), warning.Properties["ExceptionType"]);
            Assert.Null(warning.Exception);

            var info = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Information);
            Assert.Contains("Development Data Protection certificate generated.", info.Message, StringComparison.Ordinal);
        }
        finally
        {
            Directory.Delete(tempDirectory, recursive: true);
        }
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-host-tests-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private sealed class CapturingLogger : ILogger
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
                ? values.ToDictionary(x => x.Key, x => x.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel LogLevel,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
