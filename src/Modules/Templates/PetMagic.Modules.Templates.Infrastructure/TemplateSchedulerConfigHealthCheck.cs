using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace PetMagic.Modules.Templates.Infrastructure;

public sealed class TemplateSchedulerConfigHealthCheck(
    TemplateSchedulerConfigRuntimeState state) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var snapshot = state.Snapshot;
        var data = new Dictionary<string, object>
        {
            ["initialized"] = snapshot.Initialized,
            ["component"] = snapshot.Component,
            ["profileName"] = snapshot.ProfileName,
            ["checksum"] = snapshot.Checksum
        };

        if (!snapshot.Initialized)
        {
            return Task.FromResult(HealthCheckResult.Degraded(
                "Template scheduler config fingerprint has not been initialized.",
                data: data));
        }

        if (snapshot.IsMismatchDetected)
        {
            data["mismatchDetails"] = snapshot.MismatchDetails ?? string.Empty;
            return Task.FromResult(HealthCheckResult.Unhealthy(
                "Template scheduler config fingerprint mismatch detected.",
                data: data));
        }

        return Task.FromResult(HealthCheckResult.Healthy(
            "Template scheduler config fingerprint is initialized.",
            data));
    }
}
