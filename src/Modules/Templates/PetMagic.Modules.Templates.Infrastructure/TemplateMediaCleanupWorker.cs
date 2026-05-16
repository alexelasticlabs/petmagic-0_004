using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
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
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Template media cleanup worker loop failed.");
                await Task.Delay(options.MediaCleanupPollIntervalMilliseconds, stoppingToken);
            }
        }
    }
}
