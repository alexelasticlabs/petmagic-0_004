using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationWorker(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    TemplateGenerationWorkerRuntimeState runtimeState,
    ILogger<TemplateGenerationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.GenerationWorkerEnabled)
        {
            return;
        }

        if (!options.GenerationSchedulerV2Enabled)
        {
            logger.LogWarning(
                "Template generation worker is running the Scheduler V1 compatibility loop. Enable Templates__GenerationSchedulerV2Enabled only after migration, backfill, and canary validation.");
            await RunCompatibilityLoopAsync(stoppingToken);
            return;
        }

        var loops = new List<Task>(
            options.GenerationDispatchConcurrency
            + options.ProviderReconciliationConcurrency
            + options.MediaImportConcurrency
            + options.GenerationMaintenanceConcurrency);

        AddLaneLoops(loops, GenerationWorkerLane.Dispatch, options.GenerationDispatchConcurrency, stoppingToken);
        AddLaneLoops(loops, GenerationWorkerLane.ProviderReconciliation, options.ProviderReconciliationConcurrency, stoppingToken);
        AddLaneLoops(loops, GenerationWorkerLane.MediaImport, options.MediaImportConcurrency, stoppingToken);
        AddLaneLoops(loops, GenerationWorkerLane.Maintenance, options.GenerationMaintenanceConcurrency, stoppingToken);

        logger.LogInformation(
            "Template generation worker started bounded lanes. DispatchConcurrency={DispatchConcurrency} ProviderReconciliationConcurrency={ProviderReconciliationConcurrency} MediaImportConcurrency={MediaImportConcurrency} MaintenanceConcurrency={MaintenanceConcurrency}",
            options.GenerationDispatchConcurrency,
            options.ProviderReconciliationConcurrency,
            options.MediaImportConcurrency,
            options.GenerationMaintenanceConcurrency);

        await Task.WhenAll(loops);
    }

    private async Task RunCompatibilityLoopAsync(CancellationToken stoppingToken)
    {
        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplateGenerationJobProcessor>();
                var generationService = scope.ServiceProvider.GetRequiredService<TemplateGenerationService>();
                var processed = await generationService.ProcessNextPendingCancellationAsync(stoppingToken);
                if (!processed)
                {
                    processed = await processor.ProcessNextAsync(stoppingToken);
                }

                if (!processed)
                {
                    processed = await processor.RetryNextRefundAsync(stoppingToken);
                }

                if (!processed)
                {
                    processed = await processor.CleanupNextExpiredGenerationAsync(stoppingToken);
                }

                if (await processor.ProcessNextPendingGamificationAsync(stoppingToken))
                {
                    processed = true;
                }

                if (await generationService.ProcessNextPendingGamificationShareAsync(stoppingToken))
                {
                    processed = true;
                }

                if (processed)
                {
                    runtimeState.MarkProgress();
                }
                else
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
                logger.LogError(
                    "Template generation Scheduler V1 compatibility loop failed. ConsecutiveFailures={ConsecutiveFailures} ElapsedMs={ElapsedMs} ExceptionType={ExceptionType}",
                    consecutiveFailures,
                    ElapsedMsSince(startedAt),
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(
                    GetBackoffDelay(options.GenerationWorkerPollIntervalMilliseconds, consecutiveFailures),
                    stoppingToken);
            }
        }
    }

    private void AddLaneLoops(
        ICollection<Task> loops,
        GenerationWorkerLane lane,
        int concurrency,
        CancellationToken stoppingToken)
    {
        for (var loopIndex = 0; loopIndex < Math.Max(1, concurrency); loopIndex++)
        {
            loops.Add(RunLaneLoopAsync(lane, loopIndex, stoppingToken));
        }
    }

    private async Task RunLaneLoopAsync(
        GenerationWorkerLane lane,
        int loopIndex,
        CancellationToken stoppingToken)
    {
        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplateGenerationJobProcessor>();
                var generationService = scope.ServiceProvider.GetRequiredService<TemplateGenerationService>();
                var processed = await ProcessLaneAsync(lane, processor, generationService, stoppingToken);

                if (processed)
                {
                    runtimeState.MarkProgress();
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
                    ["Lane"] = lane.ToString(),
                    ["LoopIndex"] = loopIndex,
                    ["ConsecutiveFailures"] = consecutiveFailures
                });
                logger.LogError(
                    "Template generation worker lane failed. Lane={Lane} LoopIndex={LoopIndex} ConsecutiveFailures={ConsecutiveFailures} ElapsedMs={ElapsedMs} ExceptionType={ExceptionType}",
                    lane,
                    loopIndex,
                    consecutiveFailures,
                    ElapsedMsSince(startedAt),
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(GetBackoffDelay(options.GenerationWorkerPollIntervalMilliseconds, consecutiveFailures), stoppingToken);
            }
        }
    }

    private static async Task<bool> ProcessLaneAsync(
        GenerationWorkerLane lane,
        TemplateGenerationJobProcessor processor,
        TemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        switch (lane)
        {
            case GenerationWorkerLane.Dispatch:
                return await processor.ProcessNextDispatchAsync(cancellationToken);
            case GenerationWorkerLane.ProviderReconciliation:
                return await processor.ProcessNextProviderReconciliationAsync(cancellationToken);
            case GenerationWorkerLane.MediaImport:
                return await processor.ProcessNextMediaImportAsync(cancellationToken);
            case GenerationWorkerLane.Maintenance:
                {
                    var processed = await generationService.ProcessNextPendingCancellationAsync(cancellationToken);
                    if (!processed)
                    {
                        processed = await processor.ProcessNextMaintenanceAsync(cancellationToken);
                    }

                    if (await generationService.ProcessNextPendingGamificationShareAsync(cancellationToken))
                    {
                        processed = true;
                    }

                    return processed;
                }
            default:
                throw new ArgumentOutOfRangeException(nameof(lane), lane, null);
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

    private enum GenerationWorkerLane
    {
        Dispatch,
        ProviderReconciliation,
        MediaImport,
        Maintenance
    }
}
