using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class EconomyReconciliationWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<EconomyOptions> options,
    ILogger<EconomyReconciliationWorker>? logger = null) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.EconomyReconciliationEnabled)
        {
            logger?.LogInformation("Economy reconciliation worker is disabled by configuration.");
            return;
        }

        var interval = TimeSpan.FromMinutes(Math.Max(1, options.Value.EconomyReconciliationIntervalMinutes));
        await RunOnceAsync(stoppingToken);

        using var timer = new PeriodicTimer(interval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await RunOnceAsync(stoppingToken);
        }
    }

    private async Task RunOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<IEconomyAdminService>();
            var result = await service.RunEconomyReconciliationAsync(cancellationToken);
            if (result.IsFailure)
            {
                logger?.LogWarning(
                    "Economy reconciliation failed. ErrorCode={ErrorCode}",
                    result.Error.Code);
                return;
            }

            logger?.LogInformation(
                "Economy reconciliation completed. ChecksRun={ChecksRun} IncidentsCreated={IncidentsCreated} IncidentsUpdated={IncidentsUpdated} AutoFixesApplied={AutoFixesApplied} ManualReviewRequired={ManualReviewRequired}",
                result.Value.ChecksRun,
                result.Value.IncidentsCreated,
                result.Value.IncidentsUpdated,
                result.Value.AutoFixesApplied,
                result.Value.ManualReviewRequired);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            logger?.LogWarning(ex, "Economy reconciliation worker run failed.");
        }
    }
}
