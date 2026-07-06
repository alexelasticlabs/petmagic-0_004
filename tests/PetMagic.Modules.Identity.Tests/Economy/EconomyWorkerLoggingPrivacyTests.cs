namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyWorkerLoggingPrivacyTests
{
    [Fact]
    public void EconomyBackgroundWorkers_ShouldNotSerializeRawExceptions()
    {
        var root = FindRepositoryRoot();
        var source = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyReconciliationWorker.cs"));

        Assert.DoesNotContain("LogWarning(ex", source, StringComparison.Ordinal);
        Assert.DoesNotContain("LogWarning(exception", source, StringComparison.Ordinal);
        Assert.DoesNotContain("LogError(exception", source, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(ex)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyFcmSender_ShouldReadProviderBodyOnlyOnFailure()
    {
        var root = FindRepositoryRoot();
        var source = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "FcmEconomyPushNotificationSender.cs"));

        var successCheckIndex = source.IndexOf("if (response.IsSuccessStatusCode)", StringComparison.Ordinal);
        var readBodyIndex = source.IndexOf("SafeHttpContentReader.ReadStringPrefixAsync(response.Content, cancellationToken)", StringComparison.Ordinal);

        Assert.True(successCheckIndex >= 0, "Success status check was not found.");
        Assert.True(readBodyIndex > successCheckIndex, "FCM response body should be read only after the success fast-path returns.");
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
