using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationWorker(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    ILogger<TemplateGenerationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.GenerationWorkerEnabled)
        {
            return;
        }

        var loopCount = Math.Max(1, options.MaxConcurrentJobsPerWorker);
        if (loopCount > 1)
        {
            await Task.WhenAll(Enumerable.Range(0, loopCount).Select(loopIndex => RunProcessingLoopAsync(loopIndex, stoppingToken)));
            return;
        }

        await RunProcessingLoopAsync(0, stoppingToken);
    }

    private async Task RunProcessingLoopAsync(int loopIndex, CancellationToken stoppingToken)
    {
        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplateGenerationJobProcessor>();
                var processed = await processor.ProcessNextAsync(stoppingToken);
                if (!processed)
                {
                    processed = await processor.RetryNextRefundAsync(stoppingToken);
                }

                if (!processed)
                {
                    processed = await processor.CleanupNextExpiredGenerationAsync(stoppingToken);
                }

                if (!processed)
                {
                    await Task.Delay(options.GenerationWorkerPollIntervalMilliseconds, stoppingToken);
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
                var correlationId = CorrelationContext.ResolveOrCreate();
                using var correlationScope = CorrelationContext.Push(correlationId);
                using var logScope = logger.BeginScope(new Dictionary<string, object?>
                {
                    ["CorrelationId"] = correlationId,
                    ["LoopIndex"] = loopIndex,
                    ["ConsecutiveFailures"] = consecutiveFailures
                });
                logger.LogError(
                    exception,
                    "Template generation worker loop failed. LoopIndex={LoopIndex} ConsecutiveFailures={ConsecutiveFailures} ElapsedMs={ElapsedMs}",
                    loopIndex,
                    consecutiveFailures,
                    ElapsedMsSince(startedAt));
                await Task.Delay(GetBackoffDelay(options.GenerationWorkerPollIntervalMilliseconds, consecutiveFailures), stoppingToken);
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

    private static int ElapsedMsSince(long startedAt)
    {
        return (int)Math.Min(int.MaxValue, System.Diagnostics.Stopwatch.GetElapsedTime(startedAt).TotalMilliseconds);
    }
}
