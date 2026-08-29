using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.BackgroundWorkers;
using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePushOutboxWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<TemplatePushOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var idleBackoff = new AdaptiveIdlePollBackoff();
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                bool processed;
                await using (var scope = scopeFactory.CreateAsyncScope())
                {
                    var processor = scope.ServiceProvider.GetRequiredService<TemplatePushOutboxProcessor>();
                    processed = await processor.ProcessNextAsync(stoppingToken);
                }

                if (processed)
                {
                    idleBackoff.Reset();
                }
                else
                {
                    await idleBackoff.DelayAsync(stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                idleBackoff.Reset();
                logger.LogWarning(
                    "Template push outbox worker iteration failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }
}
