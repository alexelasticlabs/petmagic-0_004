using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateRenderScaleOperationWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<TemplateRenderScaleOperationWorker> logger) : BackgroundService
{
    private static readonly TimeSpan IdleDelay = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan ActiveDelay = TimeSpan.FromMilliseconds(250);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var processed = false;
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<TemplateRenderScaleOperationProcessor>();
                processed = await processor.ProcessNextAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(
                    "Render scale operation worker iteration failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
            }

            try
            {
                await Task.Delay(processed ? ActiveDelay : IdleDelay, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
        }
    }
}
