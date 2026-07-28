using Microsoft.EntityFrameworkCore;
using Npgsql;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class GenerationOperationalAlertService(
    TemplatesDbContext dbContext,
    ITemplateGenerationRuntimeSettingsProvider runtimeSettings,
    IRenderGenerationWorkerClient? renderClient = null)
{
    internal static readonly TimeSpan ProviderStaleAfter = TimeSpan.FromSeconds(180);
    internal static readonly TimeSpan WorkerStaleAfter = TimeSpan.FromMinutes(2);
    private const int EvaluationPersistenceAttempts = 2;

    public async Task EvaluateAsync(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < EvaluationPersistenceAttempts; attempt++)
        {
            await EvaluateCoreAsync(cancellationToken);
            var addedCodes = dbContext.ChangeTracker
                .Entries<TemplateGenerationOperationalAlert>()
                .Where(entry => entry.State == EntityState.Added)
                .Select(entry => entry.Entity.Code)
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return;
            }
            catch (Exception exception) when (
                attempt + 1 < EvaluationPersistenceAttempts
                && IsRetryablePersistenceRace(exception))
            {
                dbContext.ChangeTracker.Clear();
                if (addedCodes.Length == 0
                    || (!ContainsPostgresSqlState(exception, PostgresErrorCodes.DeadlockDetected)
                        && !await dbContext.TemplateGenerationOperationalAlerts
                            .AsNoTracking()
                            .AnyAsync(alert => addedCodes.Contains(alert.Code), cancellationToken)))
                {
                    throw;
                }
            }
        }
    }

    private static bool IsRetryablePersistenceRace(Exception exception) =>
        exception is DbUpdateException
        || ContainsPostgresSqlState(exception, PostgresErrorCodes.DeadlockDetected);

    private static bool ContainsPostgresSqlState(Exception exception, string sqlState)
    {
        for (Exception? current = exception; current is not null; current = current.InnerException)
        {
            if (current is PostgresException postgresException
                && postgresException.SqlState == sqlState)
            {
                return true;
            }
        }

        return false;
    }

    private async Task EvaluateCoreAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var settings = runtimeSettings.Current;
        var provider = await dbContext.TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var providerStale = !FalProviderHealthPolicy.IsSnapshotCurrent(provider?.LastSuccessAtUtc, now);
        var balance = provider?.BalanceUsd;

        await SetStateAsync(
            "fal_balance_critical",
            balance is not null && !providerStale && balance <= settings.FalBalanceCriticalThresholdUsd,
            "critical",
            "fal.ai balance is critical",
            balance is null ? "fal.ai balance is unavailable." : $"fal.ai balance is ${balance.Value:0.00}.",
            now,
            cancellationToken);
        await SetStateAsync(
            "fal_balance_low",
            balance is not null
                && !providerStale
                && balance > settings.FalBalanceCriticalThresholdUsd
                && balance <= settings.FalBalanceLowThresholdUsd,
            "warning",
            "fal.ai balance is low",
            balance is null ? "fal.ai balance is unavailable." : $"fal.ai balance is ${balance.Value:0.00}.",
            now,
            cancellationToken);
        await SetStateAsync(
            "fal_balance_unknown",
            providerStale || balance is null,
            "critical",
            "fal.ai balance is unknown",
            "No recent successful fal.ai billing snapshot is available. New provider submissions are blocked.",
            now,
            cancellationToken);

        var inflight = await CountInflightProviderRequestsAsync(cancellationToken);
        var usableConcurrency = settings.FalUsableConcurrency;
        await SetStateAsync(
            "fal_capacity_near_usable_limit",
            usableConcurrency > 0 && inflight >= Math.Max(1, usableConcurrency - 1),
            "warning",
            "fal.ai usable capacity is nearly exhausted",
            $"{inflight} of {usableConcurrency} usable provider slots are occupied.",
            now,
            cancellationToken);

        var freshWorkers = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(x => x.Component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            .Where(x => x.LastSeenAtUtc >= now.Subtract(WorkerStaleAfter))
            .ToArrayAsync(cancellationToken);
        var observedLoops = freshWorkers.Sum(x => x.ConfiguredLoops);
        if (renderClient is { IsConfigured: true })
        {
            var instances = await renderClient.ListInstancesAsync(cancellationToken);
            if (instances.IsSuccess)
            {
                observedLoops = Math.Min(
                    observedLoops,
                    instances.Value.Count * settings.WorkerLoopsPerInstance);
            }
        }
        await SetStateAsync(
            "worker_capacity_insufficient",
            observedLoops < settings.GlobalMaxConcurrent,
            "warning",
            "Generation worker capacity is below the global limit",
            $"Fresh workers expose {observedLoops} loops for a global limit of {settings.GlobalMaxConcurrent}.",
            now,
            cancellationToken);
        await SetStateAsync(
            "runtime_config_not_applied",
            freshWorkers.Any(x => x.AppliedSettingsVersion != settings.Version
                || x.NewClaimsPaused != settings.NewClaimsPaused),
            "warning",
            "Runtime generation configuration has not reached every worker",
            "At least one fresh worker reports a different settings revision or drain state.",
            now,
            cancellationToken);

    }

    private Task<long> CountInflightProviderRequestsAsync(CancellationToken cancellationToken) =>
        dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.Status == TemplateGenerationStatus.ProviderQueued
                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                && x.ProviderCompletedAtUtc == null
                && (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.PreprocessingProviderRequestId != null
                    || x.MotionProviderRequestId != null),
                cancellationToken);

    private async Task SetStateAsync(
        string code,
        bool active,
        string severity,
        string title,
        string message,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var alert = await dbContext.TemplateGenerationOperationalAlerts
            .SingleOrDefaultAsync(x => x.Code == code, cancellationToken);
        if (!active)
        {
            if (alert is not null && alert.ResolvedAtUtc is null)
            {
                alert.ResolvedAtUtc = now;
                alert.UpdatedAtUtc = now;
            }

            return;
        }

        if (alert is null)
        {
            dbContext.TemplateGenerationOperationalAlerts.Add(new TemplateGenerationOperationalAlert
            {
                Id = Guid.NewGuid(),
                Code = code,
                Severity = severity,
                Title = title,
                Message = message,
                ActivatedAtUtc = now,
                LastObservedAtUtc = now,
                UpdatedAtUtc = now
            });
            return;
        }

        if (alert.ResolvedAtUtc is not null)
        {
            alert.ActivatedAtUtc = now;
            alert.ResolvedAtUtc = null;
            dbContext.TemplateGenerationOperationalAlertAcknowledgements.RemoveRange(
                await dbContext.TemplateGenerationOperationalAlertAcknowledgements
                    .Where(x => x.AlertId == alert.Id)
                    .ToArrayAsync(cancellationToken));
        }

        alert.Severity = severity;
        alert.Title = title;
        alert.Message = message;
        alert.LastObservedAtUtc = now;
        alert.UpdatedAtUtc = now;
    }
}
