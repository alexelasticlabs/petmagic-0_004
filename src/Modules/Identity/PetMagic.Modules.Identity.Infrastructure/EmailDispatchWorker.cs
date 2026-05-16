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
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Email dispatch worker loop failed.");
                await Task.Delay(options.DispatchPollIntervalMilliseconds, stoppingToken);
            }
        }
    }
}