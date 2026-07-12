using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyPushOutboxWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<EconomyPushOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<EconomyPushOutboxProcessor>();
                var processed = await processor.ProcessNextAsync(stoppingToken);
                consecutiveFailures = 0;
                if (!processed)
                {
                    await Task.Delay(1_000, stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                consecutiveFailures++;
                logger.LogWarning(
                    "Economy push outbox worker failed. ConsecutiveFailures={ConsecutiveFailures} ExceptionType={ExceptionType}",
                    consecutiveFailures,
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(TimeSpan.FromSeconds(Math.Min(30, 1 << Math.Min(consecutiveFailures, 5))), stoppingToken);
            }
        }
    }
}
