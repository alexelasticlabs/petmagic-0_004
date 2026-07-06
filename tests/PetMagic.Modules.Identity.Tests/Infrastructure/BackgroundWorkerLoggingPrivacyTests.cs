namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class BackgroundWorkerLoggingPrivacyTests
{
    [Fact]
    public void IdentityAndSupportBackgroundWorkers_ShouldNotSerializeRawExceptions()
    {
        var root = FindRepositoryRoot();
        foreach (var relativePath in new[]
        {
            Path.Combine("src", "Modules", "Identity", "PetMagic.Modules.Identity.Infrastructure", "AccountLifecycleCleanupWorker.cs"),
            Path.Combine("src", "Modules", "Identity", "PetMagic.Modules.Identity.Infrastructure", "EmailDispatchWorker.cs"),
            Path.Combine("src", "Modules", "SupportChat", "PetMagic.Modules.SupportChat.Infrastructure", "SupportAttachmentCleanupWorker.cs")
        })
        {
            var source = File.ReadAllText(Path.Combine(root, relativePath));

            Assert.DoesNotContain("LogError(exception", source, StringComparison.Ordinal);
            Assert.Contains("ExceptionType={ExceptionType}", source, StringComparison.Ordinal);
            Assert.Contains("SafeLogValues.ExceptionType(exception)", source, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void AccountLifecycleCleanupWorker_ShouldNotLogRawUserIdsOrIdentityErrorDescriptions()
    {
        var root = FindRepositoryRoot();
        var source = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "AccountLifecycleCleanupWorker.cs"));

        Assert.Contains("UserIdHash={UserIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(user.Id.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.Contains("ErrorCodes={ErrorCodes}", source, StringComparison.Ordinal);
        Assert.Contains("deleteResult.Errors.Select(x => x.Code)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("user {UserId}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("UserId={UserId}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("x.Description", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Errors={Errors}", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(
        "src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/SupportAttachmentCleanupProcessor.cs",
        "AttachmentIdHash={AttachmentIdHash}",
        "SafeLogValues.StableHash(attachment.Id.ToString(\"D\"))",
        "AttachmentId={AttachmentId}")]
    [InlineData(
        "src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateMediaCleanupProcessor.cs",
        "MediaRecordIdHash={MediaRecordIdHash}",
        "TemplateLogSanitizer.SafeId(record.Id)",
        "MediaRecordId={MediaRecordId}")]
    public void CleanupProcessors_ShouldNotLogRawStorageRecordIdentifiers(
        string relativePath,
        string expectedHashProperty,
        string expectedSanitizerCall,
        string forbiddenRawProperty)
    {
        var source = File.ReadAllText(Path.Combine(FindRepositoryRoot(), relativePath));

        Assert.Contains(expectedHashProperty, source, StringComparison.Ordinal);
        Assert.Contains(expectedSanitizerCall, source, StringComparison.Ordinal);
        Assert.DoesNotContain(forbiddenRawProperty, source, StringComparison.Ordinal);
    }

    [Fact]
    public void EmailDispatchProcessor_ShouldNotLogRawEmailJobIds()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "EmailDispatchProcessor.cs"));

        Assert.Contains("EmailJobIdHash={EmailJobIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(job.Id.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.DoesNotContain("EmailJobId={EmailJobId}", source, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "src"))
                && Directory.Exists(Path.Combine(directory.FullName, "tests")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException("Repository root could not be found.");
    }
}
