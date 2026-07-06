namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalTransientProviderPipelineSourceTests
{
    [Fact]
    public void FalQueueClient_ShouldClassifyStatusAndResponseTransientFailures()
    {
        var source = File.ReadAllText(SourcePath("FalQueueClient.cs"));

        Assert.Contains("status.timeout", source, StringComparison.Ordinal);
        Assert.Contains("status.network", source, StringComparison.Ordinal);
        Assert.Contains("status.parse", source, StringComparison.Ordinal);
        Assert.Contains("response.timeout", source, StringComparison.Ordinal);
        Assert.Contains("response.network", source, StringComparison.Ordinal);
        Assert.Contains("response.parse", source, StringComparison.Ordinal);
        Assert.True(Count(source, "IsTransientStatusCode(response.StatusCode)") >= 2);
    }

    [Fact]
    public void FalQueueClient_ShouldBoundProviderResponseReads()
    {
        var source = File.ReadAllText(SourcePath("FalQueueClient.cs"));

        Assert.Contains("HttpCompletionOption.ResponseHeadersRead", source, StringComparison.Ordinal);
        Assert.Contains("SafeHttpContentReader.ReadRawStringPrefixAsync(", source, StringComparison.Ordinal);
        Assert.Contains("QueueMetadataMaxChars", source, StringComparison.Ordinal);
        Assert.Contains("QueueResponseMaxChars", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ReadAsStringAsync(cancellationToken)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FalQueueClient_ShouldSanitizeConfiguredQueueUrlInFailureLogs()
    {
        var source = File.ReadAllText(SourcePath("FalQueueClient.cs"));

        Assert.Contains("QueueBaseUrl={QueueBaseUrl}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.SanitizeText(queueBaseUri.ToString())", source, StringComparison.Ordinal);
        Assert.DoesNotContain("QueueBaseUrl={queueBaseUri}", source, StringComparison.Ordinal);
        Assert.Contains("ProviderRequestIdHash={ProviderRequestIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(requestId)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ProviderRequestId={ProviderRequestId}", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ProviderPipeline_ShouldDeferTransientPollingWithoutTerminalFailure()
    {
        var source = File.ReadAllText(SourcePath("TemplateGenerationJobProcessor.ProviderPipeline.cs"));

        Assert.Contains("DeferProviderPollAfterTransientFailureAsync", source, StringComparison.Ordinal);
        Assert.Contains("job.NextAttemptEarliestAtUtc = now.AddSeconds(delaySeconds)", source, StringComparison.Ordinal);
        Assert.Contains("SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true)", source, StringComparison.Ordinal);
        Assert.Contains("provider_poll_transient", source, StringComparison.Ordinal);
        Assert.True(
            source.IndexOf("IsProviderTransientFailure(statusResult.Error)", StringComparison.Ordinal)
            < source.IndexOf("MarkFailedAsync(job, statusResult.Error", StringComparison.Ordinal));
        Assert.True(
            source.IndexOf("IsProviderTransientFailure(response.Error)", StringComparison.Ordinal)
            < source.IndexOf("MarkFailedAsync(job, response.Error", StringComparison.Ordinal));
    }

    private static int Count(string source, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }

    private static string SourcePath(string fileName)
    {
        var root = FindRepositoryRoot();
        return Path.Combine(
            root,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            fileName);
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

        throw new DirectoryNotFoundException("Repository root was not found.");
    }
}
