using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalProviderHealthMonitor(
    IServiceScopeFactory scopeFactory,
    FalAccountBillingClient billingClient,
    ILogger<FalProviderHealthMonitor> logger) : BackgroundService
{
    internal static readonly Guid SnapshotId = Guid.Parse("bf67cfcf-4d33-4f04-b57c-f09bb7fcb4f8");
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(60);
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const int SnapshotAdvisoryLockKey = 0x506D4641;
    private const int SnapshotAdvisoryLockSlot = 0;
    private static readonly SemaphoreSlim LocalSnapshotPersistenceGate = new(1, 1);

    public async Task RefreshNowAsync(CancellationToken cancellationToken)
    {
        var refreshStartedAtUtc = DateTime.UtcNow;
        var result = await billingClient.GetCurrentBalanceAsync(cancellationToken);
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        await PersistSnapshotAsync(dbContext, result, refreshStartedAtUtc, cancellationToken);
        await scope.ServiceProvider.GetRequiredService<GenerationOperationalAlertService>()
            .EvaluateAsync(cancellationToken);
    }

    private static async Task PersistSnapshotAsync(
        TemplatesDbContext dbContext,
        FalAccountBillingResult result,
        DateTime checkedAtUtc,
        CancellationToken cancellationToken)
    {
        await LocalSnapshotPersistenceGate.WaitAsync(cancellationToken);
        IDbContextTransaction? transaction = null;
        try
        {
            if (string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
            {
                transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
                await dbContext.Database.ExecuteSqlInterpolatedAsync(
                    $"SELECT pg_advisory_xact_lock({SnapshotAdvisoryLockKey}, {SnapshotAdvisoryLockSlot})",
                    cancellationToken);
            }

            var row = await dbContext.TemplateFalProviderHealthSnapshots
                .SingleOrDefaultAsync(x => x.Id == SnapshotId, cancellationToken);
            if (row is null)
            {
                row = new TemplateFalProviderHealthSnapshot { Id = SnapshotId };
                dbContext.TemplateFalProviderHealthSnapshots.Add(row);
            }
            else if (row.CheckedAtUtc >= checkedAtUtc)
            {
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return;
            }

            ApplySnapshot(row, result, checkedAtUtc);
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        finally
        {
            if (transaction is not null)
            {
                await transaction.DisposeAsync();
            }

            LocalSnapshotPersistenceGate.Release();
        }
    }

    private static void ApplySnapshot(
        TemplateFalProviderHealthSnapshot row,
        FalAccountBillingResult result,
        DateTime checkedAtUtc)
    {
        row.CheckedAtUtc = checkedAtUtc;
        row.UpdatedAtUtc = checkedAtUtc;
        if (result.IsSuccess)
        {
            row.BalanceUsd = result.BalanceUsd;
            row.Status = "healthy";
            row.LastErrorCode = null;
            row.ConsecutiveFailures = 0;
            row.LastSuccessAtUtc = checkedAtUtc;
            return;
        }

        row.Status = "unknown";
        row.LastErrorCode = result.ErrorCode;
        row.ConsecutiveFailures++;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(PollInterval);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RefreshNowAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogWarning(
                    "Periodic fal provider health refresh failed. ExceptionType={ExceptionType}",
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
}
