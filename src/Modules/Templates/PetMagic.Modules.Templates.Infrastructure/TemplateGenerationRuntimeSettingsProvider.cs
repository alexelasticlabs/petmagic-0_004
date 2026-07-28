using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationRuntimeSettingsProvider(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    ILogger<TemplateGenerationRuntimeSettingsProvider> logger)
    : BackgroundService, ITemplateGenerationRuntimeSettingsProvider, ITemplateGenerationDrainController
{
    internal static readonly Guid SettingsId = Guid.Parse("f4d755ca-bf45-4ab7-92bf-b7a7ef6844c1");
    private static readonly TimeSpan RefreshInterval = TimeSpan.FromSeconds(5);

    private TemplateGenerationRuntimeSnapshot current = BuildFallback(options);

    public TemplateGenerationRuntimeSnapshot Current => Volatile.Read(ref current);

    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var row = await dbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == SettingsId, cancellationToken);
        if (row is not null)
        {
            Volatile.Write(ref current, Map(row));
        }
    }

    public async Task<bool> TryPauseNewClaimsAsync(Guid operationId, CancellationToken cancellationToken)
    {
        if (operationId == Guid.Empty)
        {
            return false;
        }

        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var updated = await dbContext.TemplateGenerationRuntimeSettings
            .Where(x => x.Id == SettingsId
                && (!x.NewClaimsPaused || x.DrainOperationId == operationId))
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.NewClaimsPaused, true)
                .SetProperty(x => x.DrainOperationId, operationId)
                .SetProperty(x => x.Version, x => x.Version + 1)
                .SetProperty(x => x.UpdatedAtUtc, DateTime.UtcNow),
                cancellationToken);
        if (updated > 0)
        {
            await RefreshAsync(cancellationToken);
        }

        return updated > 0;
    }

    public async Task<bool> TryResumeNewClaimsAsync(Guid operationId, CancellationToken cancellationToken)
    {
        if (operationId == Guid.Empty)
        {
            return false;
        }

        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var updated = await dbContext.TemplateGenerationRuntimeSettings
            .Where(x => x.Id == SettingsId && x.NewClaimsPaused && x.DrainOperationId == operationId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.NewClaimsPaused, false)
                .SetProperty(x => x.DrainOperationId, (Guid?)null)
                .SetProperty(x => x.Version, x => x.Version + 1)
                .SetProperty(x => x.UpdatedAtUtc, DateTime.UtcNow),
                cancellationToken);
        if (updated > 0)
        {
            await RefreshAsync(cancellationToken);
        }

        return updated > 0;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RefreshInterval);
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
                    "Template generation runtime settings refresh failed. ExceptionType={ExceptionType}",
                    exception.GetType().Name);
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

    internal static TemplateGenerationRuntimeSnapshot Map(TemplateGenerationRuntimeSettings row) => new(
        row.Version,
        row.GlobalMaxConcurrent,
        row.ImageMaxConcurrent,
        row.ImageProtectedConcurrent,
        row.VideoGuaranteedConcurrent,
        row.VideoMaxConcurrent,
        row.VideoBorrowMaxConcurrent,
        row.WorkerLoopsPerInstance,
        row.FalConfiguredConcurrency,
        row.FalReservedConcurrency,
        row.FalBalanceLowThresholdUsd,
        row.FalBalanceCriticalThresholdUsd,
        row.NewClaimsPaused,
        row.DrainOperationId,
        row.UpdatedAtUtc);

    internal static TemplateGenerationRuntimeSnapshot BuildFallback(TemplatesOptions options)
    {
        var imageProtected = options.ImageProtectedConcurrentGenerations > 0
            ? options.ImageProtectedConcurrentGenerations
            : options.ImageReservedConcurrentGenerations > 0
                ? options.ImageReservedConcurrentGenerations
                : options.ImageMaxConcurrentGenerations;
        var videoGuaranteed = options.VideoReservedConcurrentGenerations > 0
            ? options.VideoReservedConcurrentGenerations
            : options.VideoMaxConcurrentGenerations;
        return new TemplateGenerationRuntimeSnapshot(
            0,
            options.GlobalMaxConcurrentGenerations,
            options.ImageMaxConcurrentGenerations,
            imageProtected,
            videoGuaranteed,
            options.VideoMaxConcurrentGenerations,
            options.VideoBorrowMaxConcurrentGenerations,
            Math.Clamp(options.MaxConcurrentJobsPerWorker, 1, 2),
            options.FalProviderConcurrencyLimit,
            options.FalProviderReservedConcurrency,
            options.FalProviderBalanceLowThresholdUsd,
            options.FalProviderBalanceCriticalThresholdUsd,
            false,
            null,
            DateTime.MinValue);
    }
}
