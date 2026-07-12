using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

public sealed class GamificationLegacyDeliveryHealthCheck(TemplatesDbContext dbContext) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var legacyDeliveries = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job => job.Status == TemplateGenerationStatus.Completed
                && job.GamificationProcessedAtUtc != null
                && job.GamificationAttemptCount < 0);

        var count = await legacyDeliveries.LongCountAsync(cancellationToken);
        if (count == 0)
        {
            return HealthCheckResult.Healthy("No legacy Gamification deliveries require reconciliation.");
        }

        var oldestCompletedAtUtc = await legacyDeliveries
            .MinAsync(job => (DateTime?)job.CompletedAtUtc, cancellationToken);

        return HealthCheckResult.Degraded(
            "Legacy Gamification deliveries require an audited reconciliation decision; automatic replay is suppressed.",
            data: new Dictionary<string, object>
            {
                ["count"] = count,
                ["oldestCompletedAtUtc"] = oldestCompletedAtUtc?.ToString("O") ?? string.Empty,
                ["resolutionEndpoint"] = "/api/admin/templates/generations/{generationId}/resolve-legacy-gamification"
            });
    }
}
