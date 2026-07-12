using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class StoreAccountBindingModeHealthCheck(
    IOptions<EconomyOptions> options,
    IHostEnvironment environment) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var mode = options.Value.StoreAccountBindingMode.Trim().ToLowerInvariant();
        if (!environment.IsProduction() || mode == "enforce")
        {
            return Task.FromResult(HealthCheckResult.Healthy(
                "Store account binding is enforced or the host is not production.",
                new Dictionary<string, object> { ["mode"] = mode }));
        }

        return Task.FromResult(HealthCheckResult.Degraded(
            "Production accepts unbound legacy store purchases while store account binding compatibility mode remains enabled.",
            data: new Dictionary<string, object>
            {
                ["mode"] = mode,
                ["remediation"] = "Attach Google Play and App Store binding evidence, then set STORE_ACCOUNT_BINDING_MODE=enforce."
            }));
    }
}
