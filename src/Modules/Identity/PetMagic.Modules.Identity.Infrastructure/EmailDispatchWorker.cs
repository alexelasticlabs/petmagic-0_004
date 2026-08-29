using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.BackgroundWorkers;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class EmailDispatchWorker(
    IServiceScopeFactory scopeFactory,
    EmailOptions options,
    ILogger<EmailDispatchWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.DispatchWorkerEnabled)
        {
            return;
        }

        if (!options.IsConfigured)
        {
            logger.LogWarning("Email dispatch worker is enabled but SMTP configuration is incomplete.");
            return;
        }

        var consecutiveFailures = 0;
        var initialIdleDelay = TimeSpan.FromMilliseconds(Math.Max(1, options.DispatchPollIntervalMilliseconds));
        var idleBackoff = new AdaptiveIdlePollBackoff(
            initialIdleDelay,
            initialIdleDelay > TimeSpan.FromSeconds(5) ? initialIdleDelay : TimeSpan.FromSeconds(5));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                bool processed;
                using (var scope = scopeFactory.CreateScope())
                {
                    var processor = scope.ServiceProvider.GetRequiredService<EmailDispatchProcessor>();
                    processed = await processor.ProcessNextAsync(stoppingToken);

                    if (!processed)
                    {
                        processed = await processor.CleanupNextExpiredDispatchAsync(stoppingToken);
                    }
                }

                if (processed)
                {
                    idleBackoff.Reset();
                }
                else
                {
                    await idleBackoff.DelayAsync(stoppingToken);
                }

                consecutiveFailures = 0;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                idleBackoff.Reset();
                consecutiveFailures++;
                logger.LogError(
                    "Email dispatch worker loop failed. ConsecutiveFailures={ConsecutiveFailures} ExceptionType={ExceptionType}",
                    consecutiveFailures,
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(GetBackoffDelay(options.DispatchPollIntervalMilliseconds, consecutiveFailures), stoppingToken);
            }
        }
    }

    private static TimeSpan GetBackoffDelay(int pollIntervalMilliseconds, int consecutiveFailures)
    {
        var baseDelayMilliseconds = Math.Max(1_000, pollIntervalMilliseconds);
        var multiplier = 1 << Math.Min(consecutiveFailures - 1, 5);
        var delayMilliseconds = Math.Min(baseDelayMilliseconds * multiplier, 300_000);
        return TimeSpan.FromMilliseconds(delayMilliseconds);
    }
}
