using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportChatPushOutboxWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<SupportChatPushOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopeFactory.CreateAsyncScope();
                var processor = scope.ServiceProvider.GetRequiredService<SupportChatPushOutboxProcessor>();
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
                logger.LogError(exception, "Support push outbox worker iteration failed.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }
}
