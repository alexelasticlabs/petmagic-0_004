using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

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
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<EmailDispatchProcessor>();
                var processed = await processor.ProcessNextAsync(stoppingToken);

                if (!processed)
                {
                    processed = await processor.CleanupNextExpiredDispatchAsync(stoppingToken);
                }

                if (!processed)
                {
                    await Task.Delay(options.DispatchPollIntervalMilliseconds, stoppingToken);
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
                logger.LogError(exception, "Email dispatch worker loop failed.");
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
