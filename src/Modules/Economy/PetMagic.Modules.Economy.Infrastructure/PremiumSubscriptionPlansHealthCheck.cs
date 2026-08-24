using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class PremiumSubscriptionPlansHealthCheck(
    EconomyDbContext dbContext,
    IOptions<EconomyOptions> options,
    ILogger<PremiumSubscriptionPlansHealthCheck>? logger = null) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var expectedPlans = PremiumPlanCatalog.Create(options.Value);
            var expectedPlanCodes = expectedPlans
                .Select(plan => plan.PlanCode)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            var configuredPlans = await dbContext.SubscriptionPlans
                .AsNoTracking()
                .Where(plan => expectedPlanCodes.Contains(plan.Id))
                .Select(plan => new
                {
                    plan.Id,
                    plan.IsActive,
                    plan.MonthlyTokenLimit,
                    plan.AppleProductId,
                    plan.GoogleProductId
                })
                .ToListAsync(cancellationToken);

            var configuredPlanCodes = configuredPlans
                .Select(plan => plan.Id)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            var missingPlanCodes = expectedPlanCodes
                .Where(planCode => !configuredPlanCodes.Contains(planCode))
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            var inactivePlanCodes = configuredPlans
                .Where(plan => !plan.IsActive)
                .Select(plan => plan.Id)
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            var productIdMismatches = configuredPlans
                .Join(
                    expectedPlans,
                    configured => configured.Id,
                    expected => expected.PlanCode,
                    (configured, expected) => new { configured, expected },
                    StringComparer.OrdinalIgnoreCase)
                .Where(pair =>
                    !string.Equals(
                        pair.configured.AppleProductId,
                        pair.expected.AppStoreProductId,
                        StringComparison.Ordinal)
                    || !string.Equals(
                        pair.configured.GoogleProductId,
                        pair.expected.GooglePlayProductId,
                        StringComparison.Ordinal))
                .Select(pair => pair.configured.Id)
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            var allowanceMismatches = configuredPlans
                .Join(
                    expectedPlans,
                    configured => configured.Id,
                    expected => expected.PlanCode,
                    (configured, expected) => new { configured, expected },
                    StringComparer.OrdinalIgnoreCase)
                .Where(pair => pair.configured.MonthlyTokenLimit != pair.expected.TokenAllowance)
                .Select(pair => pair.configured.Id)
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            if (missingPlanCodes.Length == 0
                && inactivePlanCodes.Length == 0
                && productIdMismatches.Length == 0
                && allowanceMismatches.Length == 0)
            {
                return HealthCheckResult.Healthy("Premium subscription plans are configured in SubscriptionPlans.");
            }

            logger?.LogWarning(
                "Premium subscription plan health check found configuration drift. MissingPlanCodes={MissingPlanCodes} InactivePlanCodes={InactivePlanCodes} ProductIdMismatches={ProductIdMismatches} AllowanceMismatches={AllowanceMismatches}",
                missingPlanCodes,
                inactivePlanCodes,
                productIdMismatches,
                allowanceMismatches);

            IReadOnlyDictionary<string, object> diagnosticData = new Dictionary<string, object>
            {
                ["missingPlanCodes"] = missingPlanCodes,
                ["inactivePlanCodes"] = inactivePlanCodes,
                ["productIdMismatches"] = productIdMismatches,
                ["allowanceMismatches"] = allowanceMismatches
            };

            return HealthCheckResult.Unhealthy(
                "Premium subscription plans are missing, inactive, or do not match the expected provider catalog and allowance.",
                data: diagnosticData);
        }
        catch (Exception exception)
        {
            logger?.LogError(
                "Premium subscription plan health check failed while querying SubscriptionPlans. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            return HealthCheckResult.Unhealthy(
                "Failed to verify SubscriptionPlans premium catalog coverage.");
        }
    }
}
