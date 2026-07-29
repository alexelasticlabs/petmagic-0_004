using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalProviderHealthService(
    TemplatesDbContext dbContext,
    ITemplateGenerationRuntimePolicyProvider runtimePolicyProvider,
    IFalProviderRuntimeSnapshotService runtimeSnapshotService,
    TemplatesOptions options) : ITemplateAiProviderHealthService
{
    private static readonly TemplateGenerationProviderAttemptState[] ActiveAttemptStates =
    [
        TemplateGenerationProviderAttemptState.SubmitReserved,
        TemplateGenerationProviderAttemptState.Submitting,
        TemplateGenerationProviderAttemptState.ProviderQueued,
        TemplateGenerationProviderAttemptState.ProviderProcessing,
        TemplateGenerationProviderAttemptState.SubmissionUnknown
    ];

    private static readonly TimeSpan StaleBalanceGracePeriod = TimeSpan.FromMinutes(5);

    public async Task<Result> EnsureCanAcceptGenerationAsync(
        string mediaType,
        string tier,
        CancellationToken cancellationToken)
    {
        var policy = await runtimePolicyProvider.GetRuntimePolicyAsync(cancellationToken);
        if (!policy.AdmissionEnabled)
        {
            return Reject("admission_paused", mediaType, tier);
        }

        if (!IsFalProvider())
        {
            return Result.Success();
        }

        int confirmedConcurrency;
        long inflightRequests;
        if (options.GenerationSchedulerV2Enabled)
        {
            if (policy.EffectiveProfile.GlobalMaxConcurrentGenerations <= 0)
            {
                return Reject("effective_capacity_zero", mediaType, tier);
            }

            confirmedConcurrency = policy.ConfirmedFalConcurrencyLimit;
            inflightRequests = await CountInflightProviderAttemptsAsync(cancellationToken);
        }
        else
        {
            confirmedConcurrency = options.FalProviderConcurrencyLimit;
            inflightRequests = await CountLegacyInflightProviderRequestsAsync(cancellationToken);
            var usableConcurrency = confirmedConcurrency - options.FalProviderReservedConcurrency;
            if (confirmedConcurrency <= 0)
            {
                RecordSnapshot(confirmedConcurrency, balanceUsd: null, inflightRequests);
                return Reject("concurrency_unknown", mediaType, tier);
            }

            if (usableConcurrency <= 0 || inflightRequests >= usableConcurrency)
            {
                RecordSnapshot(confirmedConcurrency, balanceUsd: null, inflightRequests);
                return Reject("concurrency_exhausted", mediaType, tier);
            }
        }

        var snapshot = await runtimeSnapshotService.GetSnapshotAsync(cancellationToken);
        RecordSnapshot(confirmedConcurrency, snapshot.CurrentBalanceUsd, inflightRequests);

        if (snapshot.BalanceState == TemplateProviderBalanceState.Unknown)
        {
            return Reject("balance_unknown", mediaType, tier);
        }

        if (snapshot.BalanceState == TemplateProviderBalanceState.Stale
            && (!snapshot.LastSuccessfulAtUtc.HasValue
                || snapshot.LastSuccessfulAtUtc.Value < DateTime.UtcNow.Subtract(StaleBalanceGracePeriod)))
        {
            return Reject("balance_unknown", mediaType, tier);
        }

        if (snapshot.BalanceState == TemplateProviderBalanceState.Critical
            || snapshot.CurrentBalanceUsd <= options.FalProviderBalanceCriticalThresholdUsd)
        {
            return Reject("balance_critical", mediaType, tier);
        }

        // Provider capacity is enforced atomically when dispatch reserves a durable attempt.
        // A full provider queue must not reject admission: the accepted job remains in PostgreSQL.
        return Result.Success();
    }

    private bool IsFalProvider()
    {
        return string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase);
    }

    private Task<long> CountInflightProviderAttemptsAsync(CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationProviderAttempts
            .AsNoTracking()
            .LongCountAsync(x => ActiveAttemptStates.Contains(x.State), cancellationToken);
    }

    private Task<long> CountLegacyInflightProviderRequestsAsync(CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.Status == TemplateGenerationStatus.ProviderQueued
                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                && x.ProviderCompletedAtUtc == null
                && (x.PreprocessingProviderRequestId != null || x.MotionProviderRequestId != null),
                cancellationToken);
    }

    private void RecordSnapshot(
        int confirmedFalConcurrencyLimit,
        decimal? balanceUsd,
        long inflightRequests)
    {
        TemplateGenerationMetrics.RecordFalProviderCapacitySnapshot(
            confirmedFalConcurrencyLimit,
            inflightRequests,
            balanceUsd,
            options.FalProviderBalanceLowThresholdUsd,
            options.FalProviderBalanceCriticalThresholdUsd);
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
