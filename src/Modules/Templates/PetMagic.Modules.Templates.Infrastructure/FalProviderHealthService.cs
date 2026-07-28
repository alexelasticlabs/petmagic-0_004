using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalProviderHealthService(
    TemplatesDbContext dbContext,
    FalAccountBillingClient billingClient,
    TemplatesOptions options,
    ITemplateGenerationRuntimeSettingsProvider? runtimeSettings = null) : ITemplateAiProviderHealthService
{
    public const string HttpClientName = FalAccountBillingClient.HttpClientName;

    public async Task<Result> EnsureCanAcceptGenerationAsync(
        string mediaType,
        string tier,
        CancellationToken cancellationToken)
    {
        if (!IsFalProvider())
        {
            return Result.Success();
        }

        var settings = runtimeSettings?.Current
            ?? TemplateGenerationRuntimeSettingsProvider.BuildFallback(options);
        var configuredConcurrency = settings.FalConfiguredConcurrency;
        var inflightRequests = await CountInflightProviderRequestsAsync(cancellationToken);
        if (configuredConcurrency <= 0)
        {
            RecordSnapshot(settings, inflightRequests, balanceUsd: null);
            return Reject("concurrency_unknown", mediaType, tier);
        }

        var usableConcurrency = settings.FalUsableConcurrency;
        if (usableConcurrency <= 0 || inflightRequests >= usableConcurrency)
        {
            RecordSnapshot(settings, inflightRequests, balanceUsd: null);
            return Reject("concurrency_exhausted", mediaType, tier);
        }

        var balance = runtimeSettings is null
            ? await GetCurrentBalanceUsdAsync(cancellationToken)
            : await GetPersistedCurrentBalanceUsdAsync(cancellationToken);
        RecordSnapshot(settings, inflightRequests, balance);
        if (balance is null)
        {
            return Reject("balance_unknown", mediaType, tier);
        }

        if (balance.Value <= settings.FalBalanceCriticalThresholdUsd)
        {
            return Reject("balance_critical", mediaType, tier);
        }

        return Result.Success();
    }

    private async Task<decimal?> GetPersistedCurrentBalanceUsdAsync(CancellationToken cancellationToken)
    {
        var snapshot = await dbContext.TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        return snapshot is not null
            && FalProviderHealthPolicy.IsSnapshotCurrent(snapshot.LastSuccessAtUtc, DateTime.UtcNow)
            && snapshot.BalanceUsd is not null
                ? snapshot.BalanceUsd
                : null;
    }

    private bool IsFalProvider()
    {
        return string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase);
    }

    private Task<long> CountInflightProviderRequestsAsync(CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.Status == TemplateGenerationStatus.ProviderQueued
                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                && x.ProviderCompletedAtUtc == null
                && (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.PreprocessingProviderRequestId != null
                    || x.MotionProviderRequestId != null),
                cancellationToken);
    }

    private async Task<decimal?> GetCurrentBalanceUsdAsync(CancellationToken cancellationToken)
    {
        var result = await billingClient.GetCurrentBalanceAsync(cancellationToken);
        return result.IsSuccess ? result.BalanceUsd : null;
    }

    private void RecordSnapshot(
        TemplateGenerationRuntimeSnapshot settings,
        long inflightRequests,
        decimal? balanceUsd)
    {
        TemplateGenerationMetrics.RecordFalProviderCapacitySnapshot(
            settings.FalConfiguredConcurrency,
            inflightRequests,
            balanceUsd,
            settings.FalBalanceLowThresholdUsd,
            settings.FalBalanceCriticalThresholdUsd);
    }

    private static Result Reject(string reason, string mediaType, string tier)
    {
        TemplateGenerationMetrics.RecordFalProviderRejectedDueToCapacity(reason, mediaType, tier);
        TemplateGenerationMetrics.RecordJobRejected(reason, mediaType, tier);
        return Result.Failure(new Error(
            TemplatesErrors.ProviderCapacityUnavailable.Code,
            TemplatesErrors.ProviderCapacityUnavailable.Message,
            new Dictionary<string, object?>
            {
                ["reason"] = reason,
                ["mediaType"] = mediaType,
                ["tier"] = tier,
                ["canRetry"] = true
            }));
    }
}
