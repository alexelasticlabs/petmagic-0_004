using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task<Result<QueueEstimate>> EnsureQueueCanAcceptAsync(
        TemplateItem template,
        string queueTier,
        CancellationToken cancellationToken)
    {
        var estimate = await CalculateQueueEstimateForNewJobAsync(template.TemplateType, queueTier, cancellationToken);
        var maxWaitSeconds = ResolveMaxEstimatedWaitSeconds(estimate.MediaType, estimate.PriorityClass);
        if (estimate.EstimatedWaitSeconds <= maxWaitSeconds)
        {
            if (aiProviderHealthService is not null)
            {
                var providerHealth = await aiProviderHealthService.EnsureCanAcceptGenerationAsync(
                    estimate.MediaType,
                    estimate.PriorityClass,
                    cancellationToken);
                if (providerHealth.IsFailure)
                {
                    return Result.Failure<QueueEstimate>(providerHealth.Error);
                }
            }

            return Result.Success(estimate);
        }

        TemplateGenerationMetrics.RecordJobRejected(
            "estimated_wait_too_long",
            estimate.MediaType,
            estimate.PriorityClass);
        return Result.Failure<QueueEstimate>(new Error(
            TemplatesErrors.GenerationWaitTooLong.Code,
            $"Estimated wait is {estimate.EstimatedWaitSeconds} seconds for {estimate.MediaType}/{estimate.PriorityClass}; retry after about {estimate.RetryAfterSeconds} seconds.",
            new Dictionary<string, object?>
            {
                ["mediaType"] = estimate.MediaType,
                ["tier"] = estimate.PriorityClass,
                ["estimatedWaitSeconds"] = estimate.EstimatedWaitSeconds,
                ["maxAllowedWaitSeconds"] = maxWaitSeconds,
                ["retryAfterSeconds"] = estimate.RetryAfterSeconds,
                ["canRetry"] = true,
                ["canUpgradeForPriority"] = estimate.PriorityClass == TemplateGenerationQueue.TierFree
            }));
    }
}
