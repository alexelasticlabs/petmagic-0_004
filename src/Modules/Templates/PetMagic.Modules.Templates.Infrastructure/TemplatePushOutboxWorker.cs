using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePushOutboxWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<TemplatePushOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopeFactory.CreateAsyncScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplatePushOutboxProcessor>();
                if (!await processor.ProcessNextAsync(stoppingToken))
                {
                    await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogWarning(
                    "Template push outbox worker iteration failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }
}
