using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public sealed class FalProviderRuntimeHealthCheck(
    TemplatesDbContext dbContext,
    TemplatesOptions options) : IHealthCheck
{
    private const string ProviderName = "fal";

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        if (!string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase))
        {
            return HealthCheckResult.Healthy(
                "fal.ai provider runtime check is not applicable.",
                new Dictionary<string, object>
                {
                    ["provider"] = options.AiProvider,
                    ["state"] = "not_applicable"
                });
        }

        var snapshot = await dbContext.TemplateProviderRuntimeSnapshots
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Provider == ProviderName, cancellationToken);

        if (snapshot is null)
        {
            return HealthCheckResult.Degraded(
                "fal.ai provider runtime snapshot is not initialized.",
                data: new Dictionary<string, object>
                {
                    ["provider"] = ProviderName,
                    ["state"] = "unknown",
                    ["remediation"] = "Verify the backend-only fal.ai ADMIN key and wait for a successful balance refresh."
                });
        }

        var data = new Dictionary<string, object>
        {
            ["provider"] = ProviderName,
            ["state"] = snapshot.BalanceState.ToString().ToLowerInvariant(),
            ["consecutiveFailures"] = snapshot.ConsecutiveFailures
        };
        if (snapshot.CheckedAtUtc.HasValue)
        {
            data["checkedAtUtc"] = snapshot.CheckedAtUtc.Value;
        }

        if (snapshot.LastSuccessfulAtUtc.HasValue)
        {
            data["lastSuccessfulAtUtc"] = snapshot.LastSuccessfulAtUtc.Value;
        }

        if (!string.IsNullOrWhiteSpace(snapshot.LastErrorCode))
        {
            data["lastErrorCode"] = snapshot.LastErrorCode;
        }

        if (snapshot.BalanceState == TemplateProviderBalanceState.Fresh)
        {
            return HealthCheckResult.Healthy(
                "fal.ai provider balance snapshot is fresh.",
                data);
        }

        data["remediation"] = "Verify the backend-only fal.ai ADMIN key, provider balance and refresh freshness before accepting generation traffic.";
        var description = snapshot.BalanceState switch
        {
            TemplateProviderBalanceState.Low => "fal.ai provider balance is low.",
            TemplateProviderBalanceState.Critical => "fal.ai provider balance is critical.",
            TemplateProviderBalanceState.Stale => "fal.ai provider balance snapshot is stale.",
            _ => "fal.ai provider balance is unavailable."
        };

        return HealthCheckResult.Degraded(description, data: data);
    }
}
