using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class RenderGenerationWorkerMonitor(
    IServiceScopeFactory scopeFactory,
    IRenderGenerationWorkerClient renderClient,
    ILogger<RenderGenerationWorkerMonitor> logger) : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(60);
    private static readonly string[] ActiveOperationStatuses =
    [
        "requested",
        "draining",
        "scaling",
        "verifying"
    ];

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(PollInterval);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RefreshAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogWarning(
                    "Render generation worker topology refresh failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
            }

            try
            {
                if (!await timer.WaitForNextTickAsync(stoppingToken))
                {
                    return;
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
        }
    }

    internal async Task RefreshAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var hasActiveScaleOperation = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .AnyAsync(x => ActiveOperationStatuses.Contains(x.Status), cancellationToken);

        if (!renderClient.IsConfigured || hasActiveScaleOperation)
        {
            // Missing configuration and an in-flight scale operation are not proof that an
            // existing topology drift recovered. Preserve the last known alert state until a
            // complete desired/observed topology check succeeds.
            return;
        }

        var targetResult = await renderClient.GetTargetStatusAsync(cancellationToken);
        if (targetResult.IsFailure || targetResult.Value.DesiredInstances is not int desiredInstances)
        {
            logger.LogWarning(
                "Render generation worker topology could not be verified. ErrorCode={ErrorCode}",
                targetResult.IsFailure ? targetResult.Error.Code : "templates.render.desired_instances_unknown");
            return;
        }

        var instancesResult = await renderClient.ListInstancesAsync(cancellationToken);
        if (instancesResult.IsFailure)
        {
            logger.LogWarning(
                "Render generation worker instances could not be verified. ErrorCode={ErrorCode}",
                instancesResult.Error.Code);
            return;
        }

        var observedInstances = instancesResult.Value.Count;
        await SetDriftAlertAsync(
            dbContext,
            observedInstances != desiredInstances,
            desiredInstances,
            observedInstances,
            cancellationToken);
    }

    private static async Task SetDriftAlertAsync(
        TemplatesDbContext dbContext,
        bool active,
        int? desiredInstances,
        int? observedInstances,
        CancellationToken cancellationToken)
    {
        const string code = "render_instance_drift";
        var now = DateTime.UtcNow;
        var alert = await dbContext.TemplateGenerationOperationalAlerts
            .SingleOrDefaultAsync(x => x.Code == code, cancellationToken);

        if (!active)
        {
            if (alert is not null && alert.ResolvedAtUtc is null)
            {
                alert.ResolvedAtUtc = now;
                alert.UpdatedAtUtc = now;
                await dbContext.SaveChangesAsync(cancellationToken);
            }

            return;
        }

        var message = $"Render reports {observedInstances ?? 0} active generation-worker instances while {desiredInstances ?? 0} are desired.";
        if (alert is null)
        {
            dbContext.TemplateGenerationOperationalAlerts.Add(new TemplateGenerationOperationalAlert
            {
                Id = Guid.NewGuid(),
                Code = code,
                Severity = "warning",
                Title = "Render generation worker topology differs from the desired state",
                Message = message,
                ActivatedAtUtc = now,
                LastObservedAtUtc = now,
                UpdatedAtUtc = now
            });
        }
        else
        {
            if (alert.ResolvedAtUtc is not null)
            {
                alert.ActivatedAtUtc = now;
                alert.ResolvedAtUtc = null;
                dbContext.TemplateGenerationOperationalAlertAcknowledgements.RemoveRange(
                    await dbContext.TemplateGenerationOperationalAlertAcknowledgements
                        .Where(x => x.AlertId == alert.Id)
                        .ToArrayAsync(cancellationToken));
            }

            alert.Severity = "warning";
            alert.Message = message;
            alert.LastObservedAtUtc = now;
            alert.UpdatedAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
