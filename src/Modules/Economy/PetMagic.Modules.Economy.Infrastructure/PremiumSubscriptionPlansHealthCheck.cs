using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Economy.Infrastructure.Data;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class PremiumSubscriptionPlansHealthCheck(
    EconomyDbContext dbContext,
    ILogger<PremiumSubscriptionPlansHealthCheck>? logger = null) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var expectedPlanCodes = PremiumPlanCatalog.All
                .Select(plan => plan.PlanCode)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            var configuredPlans = await dbContext.SubscriptionPlans
                .AsNoTracking()
                .Where(plan => expectedPlanCodes.Contains(plan.Id))
                .Select(plan => new { plan.Id, plan.IsActive })
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

            if (missingPlanCodes.Length == 0 && inactivePlanCodes.Length == 0)
            {
                return HealthCheckResult.Healthy("Premium subscription plans are configured in SubscriptionPlans.");
            }

            logger?.LogWarning(
                "Premium subscription plan health check found configuration drift. MissingPlanCodes={MissingPlanCodes} InactivePlanCodes={InactivePlanCodes}",
                missingPlanCodes,
                inactivePlanCodes);

            IReadOnlyDictionary<string, object> diagnosticData = new Dictionary<string, object>
            {
                ["missingPlanCodes"] = missingPlanCodes,
                ["inactivePlanCodes"] = inactivePlanCodes
            };

            return HealthCheckResult.Unhealthy(
                "Premium subscription plans are missing or inactive in SubscriptionPlans; runtime may fall back to hardcoded catalog pricing.",
                data: diagnosticData);
        }
        catch (Exception exception)
        {
            logger?.LogError(
                exception,
                "Premium subscription plan health check failed while querying SubscriptionPlans.");
            return HealthCheckResult.Unhealthy(
                "Failed to verify SubscriptionPlans premium catalog coverage.",
                exception);
        }
    }
}
