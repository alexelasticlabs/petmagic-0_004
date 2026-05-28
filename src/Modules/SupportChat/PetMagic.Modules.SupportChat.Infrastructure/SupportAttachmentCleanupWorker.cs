using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportAttachmentCleanupWorker(
    IServiceScopeFactory scopeFactory,
    SupportAttachmentStorageOptions options,
    ILogger<SupportAttachmentCleanupWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.CleanupWorkerEnabled)
        {
            return;
        }

        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<SupportAttachmentCleanupProcessor>();
                var processed = await processor.CleanupExpiredBatchAsync(stoppingToken);
                if (!processed)
                {
                    await Task.Delay(options.CleanupPollIntervalMilliseconds, stoppingToken);
                }

                consecutiveFailures = 0;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                consecutiveFailures++;
                logger.LogError(exception, "Support attachment cleanup worker loop failed.");
                await Task.Delay(GetBackoffDelay(options.CleanupRetryDelayMilliseconds, consecutiveFailures), stoppingToken);
            }
        }
    }

    private static TimeSpan GetBackoffDelay(int retryDelayMilliseconds, int consecutiveFailures)
    {
        var baseDelayMilliseconds = Math.Max(1_000, retryDelayMilliseconds);
        var multiplier = 1 << Math.Min(consecutiveFailures - 1, 5);
        var delayMilliseconds = Math.Min(baseDelayMilliseconds * multiplier, 300_000);
        return TimeSpan.FromMilliseconds(delayMilliseconds);
    }
}

