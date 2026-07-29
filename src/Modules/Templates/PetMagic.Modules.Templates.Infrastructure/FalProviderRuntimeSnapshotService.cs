using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface IFalProviderRuntimeSnapshotService
{
    Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken);

    Task<TemplateProviderRuntimeSnapshot> RefreshAsync(bool force, CancellationToken cancellationToken);

    async Task<TemplateProviderRuntimeRefreshResult> RefreshWithOutcomeAsync(
        bool force,
        CancellationToken cancellationToken) => new(
            await RefreshAsync(force, cancellationToken),
            TemplateProviderRuntimeRefreshOutcome.Refreshed,
            ErrorCode: null);
}

internal enum TemplateProviderRuntimeRefreshOutcome
{
    Refreshed,
    Coalesced,
    Failed
}

internal sealed record TemplateProviderRuntimeRefreshResult(
    TemplateProviderRuntimeSnapshot Snapshot,
    TemplateProviderRuntimeRefreshOutcome Outcome,
    string? ErrorCode);

internal sealed class FalProviderRuntimeSnapshotService(
    TemplatesDbContext dbContext,
    IHttpClientFactory httpClientFactory,
    TemplatesOptions options,
    ILogger<FalProviderRuntimeSnapshotService> logger) : IFalProviderRuntimeSnapshotService
{
    internal const string HttpClientName = "FalPlatformRuntime";

    private const string ProviderName = "fal";
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const int BalanceResponseMaxChars = 16 * 1024;
    private static readonly TimeSpan RefreshInterval = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan RefreshLeaseDuration = TimeSpan.FromSeconds(45);
    private static readonly TimeSpan LastKnownGoodTtl = TimeSpan.FromMinutes(5);

    public async Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken)
    {
        var snapshot = await EnsureSnapshotAsync(cancellationToken);
        var now = DateTime.UtcNow;
        if (snapshot.BalanceState != TemplateProviderBalanceState.Unknown
            && (snapshot.LastSuccessfulAtUtc is null
                || snapshot.LastSuccessfulAtUtc < now.Subtract(LastKnownGoodTtl)))
        {
            snapshot.BalanceState = TemplateProviderBalanceState.Unknown;
            snapshot.StatusChangedAtUtc = snapshot.LastSuccessfulAtUtc?.Add(LastKnownGoodTtl) ?? now;
            snapshot.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return snapshot;
    }

    public async Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
        bool force,
        CancellationToken cancellationToken) =>
        (await RefreshWithOutcomeAsync(force, cancellationToken)).Snapshot;

    public async Task<TemplateProviderRuntimeRefreshResult> RefreshWithOutcomeAsync(
        bool force,
        CancellationToken cancellationToken)
    {
        var leaseId = Guid.NewGuid();
        if (!await TryAcquireRefreshLeaseAsync(leaseId, force, cancellationToken))
        {
            return new TemplateProviderRuntimeRefreshResult(
                await GetSnapshotAsync(cancellationToken),
                TemplateProviderRuntimeRefreshOutcome.Coalesced,
                ErrorCode: null);
        }

        BalanceRefreshResult result;
        try
        {
            result = await FetchBalanceAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "fal account billing runtime refresh failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            result = BalanceRefreshResult.Failure("unexpected_error");
        }

        return await CompleteRefreshAsync(leaseId, result, cancellationToken);
    }

    private async Task<bool> TryAcquireRefreshLeaseAsync(
        Guid leaseId,
        bool force,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext('templates:fal-runtime-snapshot'))",
                cancellationToken);
        }

        var snapshot = await EnsureSnapshotAsync(cancellationToken);
        var now = DateTime.UtcNow;
        var recentlyChecked = snapshot.CheckedAtUtc >= now.Subtract(RefreshInterval);
        var activelyLeased = snapshot.RefreshLeaseId is not null
            && snapshot.RefreshLeaseExpiresAtUtc > now;
        if ((!force && recentlyChecked) || activelyLeased)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return false;
        }

        snapshot.RefreshLeaseId = leaseId;
        snapshot.RefreshLeaseExpiresAtUtc = now.Add(RefreshLeaseDuration);
        snapshot.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return true;
    }

    private async Task<TemplateProviderRuntimeRefreshResult> CompleteRefreshAsync(
        Guid leaseId,
        BalanceRefreshResult result,
        CancellationToken cancellationToken)
    {
        var snapshot = await dbContext.TemplateProviderRuntimeSnapshots
            .SingleAsync(x => x.Provider == ProviderName, cancellationToken);
        if (snapshot.RefreshLeaseId != leaseId)
        {
            return new TemplateProviderRuntimeRefreshResult(
                snapshot,
                TemplateProviderRuntimeRefreshOutcome.Coalesced,
                ErrorCode: null);
        }

        var now = DateTime.UtcNow;
        snapshot.CheckedAtUtc = now;
        snapshot.RefreshLeaseId = null;
        snapshot.RefreshLeaseExpiresAtUtc = null;
        snapshot.UpdatedAtUtc = now;
        var previousState = snapshot.BalanceState;
        if (result.IsSuccess)
        {
            snapshot.CurrentBalanceUsd = result.BalanceUsd;
            snapshot.LastSuccessfulAtUtc = now;
            snapshot.ConsecutiveFailures = 0;
            snapshot.LastErrorCode = null;
            snapshot.BalanceState = ResolveFreshBalanceState(result.BalanceUsd!.Value);
        }
        else
        {
            snapshot.ConsecutiveFailures++;
            snapshot.LastErrorCode = result.ErrorCode;
            snapshot.BalanceState = snapshot.LastSuccessfulAtUtc >= now.Subtract(LastKnownGoodTtl)
                ? TemplateProviderBalanceState.Stale
                : TemplateProviderBalanceState.Unknown;
        }

        if (snapshot.BalanceState != previousState)
        {
            snapshot.StatusChangedAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return new TemplateProviderRuntimeRefreshResult(
            snapshot,
            result.IsSuccess
                ? TemplateProviderRuntimeRefreshOutcome.Refreshed
                : TemplateProviderRuntimeRefreshOutcome.Failed,
            result.ErrorCode);
    }

    private async Task<BalanceRefreshResult> FetchBalanceAsync(CancellationToken cancellationToken)
    {
        if (!string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase))
        {
            return BalanceRefreshResult.Failure("provider_not_fal");
        }

        if (string.IsNullOrWhiteSpace(options.Fal.ApiKey))
        {
            return BalanceRefreshResult.Failure("api_key_missing");
        }

        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            "https://api.fal.ai/v1/account/billing?expand=credits");
        request.Headers.Authorization = new AuthenticationHeaderValue("Key", options.Fal.ApiKey);

        using var response = await httpClientFactory
            .CreateClient(HttpClientName)
            .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
        {
            return BalanceRefreshResult.Failure("authentication_failed");
        }

        if (!response.IsSuccessStatusCode)
        {
            return BalanceRefreshResult.Failure($"http_{(int)response.StatusCode}");
        }

        var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
            response.Content,
            cancellationToken,
            BalanceResponseMaxChars);
        try
        {
            using var document = JsonDocument.Parse(body);
            var balance = ReadBalanceUsd(document.RootElement);
            return balance is null
                ? BalanceRefreshResult.Failure("invalid_response")
                : BalanceRefreshResult.Success(balance.Value);
        }
        catch (JsonException)
        {
            return BalanceRefreshResult.Failure("invalid_response");
        }
    }

    private async Task<TemplateProviderRuntimeSnapshot> EnsureSnapshotAsync(CancellationToken cancellationToken)
    {
        var snapshot = await dbContext.TemplateProviderRuntimeSnapshots
            .SingleOrDefaultAsync(x => x.Provider == ProviderName, cancellationToken);
        if (snapshot is not null)
        {
            return snapshot;
        }

        var now = DateTime.UtcNow;
        snapshot = new TemplateProviderRuntimeSnapshot
        {
            Id = TemplateGenerationControlPolicyDefaults.FalSnapshotId,
            Provider = ProviderName,
            BalanceState = TemplateProviderBalanceState.Unknown,
            StatusChangedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateProviderRuntimeSnapshots.Add(snapshot);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return snapshot;
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(snapshot).State = EntityState.Detached;
            return await dbContext.TemplateProviderRuntimeSnapshots
                .SingleAsync(x => x.Provider == ProviderName, cancellationToken);
        }
    }

    private Task<IDbContextTransaction?> BeginTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? BeginNpgsqlTransactionAsync(cancellationToken)
            : Task.FromResult<IDbContextTransaction?>(null);
    }

    private async Task<IDbContextTransaction?> BeginNpgsqlTransactionAsync(CancellationToken cancellationToken) =>
        await dbContext.Database.BeginTransactionAsync(cancellationToken);

    private TemplateProviderBalanceState ResolveFreshBalanceState(decimal balanceUsd)
    {
        if (balanceUsd <= options.FalProviderBalanceCriticalThresholdUsd)
        {
            return TemplateProviderBalanceState.Critical;
        }

        return balanceUsd < options.FalProviderBalanceLowThresholdUsd
            ? TemplateProviderBalanceState.Low
            : TemplateProviderBalanceState.Fresh;
    }

    private static decimal? ReadBalanceUsd(JsonElement root)
    {
        if (!root.TryGetProperty("credits", out var credits)
            || credits.ValueKind != JsonValueKind.Object
            || !credits.TryGetProperty("current_balance", out var balanceElement))
        {
            return null;
        }

        return balanceElement.ValueKind switch
        {
            JsonValueKind.Number when balanceElement.TryGetDecimal(out var numeric) => numeric,
            JsonValueKind.String when decimal.TryParse(
                balanceElement.GetString(),
                System.Globalization.NumberStyles.Number,
                System.Globalization.CultureInfo.InvariantCulture,
                out var parsed) => parsed,
            _ => null
        };
    }

    private sealed record BalanceRefreshResult(bool IsSuccess, decimal? BalanceUsd, string? ErrorCode)
    {
        internal static BalanceRefreshResult Success(decimal balanceUsd) => new(true, balanceUsd, null);

        internal static BalanceRefreshResult Failure(string errorCode) => new(false, null, errorCode);
    }
}

internal sealed class FalProviderRuntimeSnapshotMonitor(
    IServiceScopeFactory scopeFactory,
    ILogger<FalProviderRuntimeSnapshotMonitor> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(60);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await RefreshAsync(stoppingToken);
        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await RefreshAsync(stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
    }

    private async Task RefreshAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<IFalProviderRuntimeSnapshotService>();
            await service.RefreshAsync(force: false, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "fal provider runtime monitor iteration failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
        }
    }
}
