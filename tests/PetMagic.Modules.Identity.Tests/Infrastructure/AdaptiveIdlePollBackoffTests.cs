using PetMagic.BuildingBlocks.BackgroundWorkers;

namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class AdaptiveIdlePollBackoffTests
{
    [Fact]
    public void GetNextDelay_ShouldGrowExponentiallyAndStopAtMaximum()
    {
        var backoff = new AdaptiveIdlePollBackoff(
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(5));

        var delays = Enumerable.Range(0, 6)
            .Select(_ => backoff.GetNextDelay())
            .ToArray();

        Assert.Equal(
            [
                TimeSpan.FromSeconds(1),
                TimeSpan.FromSeconds(2),
                TimeSpan.FromSeconds(4),
                TimeSpan.FromSeconds(5),
                TimeSpan.FromSeconds(5),
                TimeSpan.FromSeconds(5)
            ],
            delays);
    }

    [Fact]
    public void Reset_ShouldRestoreInitialDelay()
    {
        var backoff = new AdaptiveIdlePollBackoff(
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(5));

        _ = backoff.GetNextDelay();
        _ = backoff.GetNextDelay();
        backoff.Reset();

        Assert.Equal(TimeSpan.FromSeconds(1), backoff.GetNextDelay());
    }

    [Fact]
    public async Task DelayAsync_ShouldObserveCancellation()
    {
        var backoff = new AdaptiveIdlePollBackoff(
            TimeSpan.FromMinutes(1),
            TimeSpan.FromMinutes(1));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(
            () => backoff.DelayAsync(cancellation.Token));
    }
}
