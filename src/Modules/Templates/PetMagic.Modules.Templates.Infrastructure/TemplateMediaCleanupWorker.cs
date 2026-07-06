using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateMediaCleanupWorker(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    ILogger<TemplateMediaCleanupWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.MediaCleanupWorkerEnabled)
        {
            return;
        }

        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplateMediaCleanupProcessor>();
                var processed = await processor.CleanupNextExpiredTemporaryUploadAsync(stoppingToken);

                if (!processed)
                {
                    processed = await processor.CleanupNextExpiredGenerationMediaAsync(stoppingToken);
                }

                if (!processed)
                {
                    processed = await processor.CleanupNextExpiredMetadataTempFileAsync(stoppingToken);
                }

                if (!processed)
                {
                    await Task.Delay(options.MediaCleanupPollIntervalMilliseconds, stoppingToken);
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
                logger.LogError(
                    "Template media cleanup worker loop failed. ConsecutiveFailures={ConsecutiveFailures} ExceptionType={ExceptionType}",
                    consecutiveFailures,
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(GetBackoffDelay(options.MediaCleanupPollIntervalMilliseconds, consecutiveFailures), stoppingToken);
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
