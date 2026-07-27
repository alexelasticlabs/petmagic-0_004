using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace PetMagic.Host.Api.Observability;

public interface IAdminSystemStatusService
{
    Task<AdminSystemStatusResponse> GetAsync(CancellationToken cancellationToken = default);
}

public sealed class AdminSystemStatusService(
    HealthCheckService healthCheckService,
    ILogger<AdminSystemStatusService> logger) : IAdminSystemStatusService
{
    public const int StaleAfterSeconds = 60;

    private static readonly TimeSpan ExecutionTimeout = TimeSpan.FromSeconds(3);

    private static readonly IReadOnlyList<CuratedHealthCheck> CuratedChecks =
    [
        new("self", "api", "API"),
        new("economy_subscription_plans", "subscriptionCatalog", "Premium subscription catalog"),
        new("store_account_binding", "storeAccountBinding", "Store account binding"),
        new("templates_scheduler_config", "generationScheduler", "Generation scheduler configuration")
    ];

    private static readonly HashSet<string> CuratedRegistrationNames = CuratedChecks
        .Select(check => check.RegistrationName)
        .ToHashSet(StringComparer.Ordinal);

    public async Task<AdminSystemStatusResponse> GetAsync(CancellationToken cancellationToken = default)
    {
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(ExecutionTimeout);

        try
        {
            var report = await healthCheckService.CheckHealthAsync(
                registration => CuratedRegistrationNames.Contains(registration.Name),
                timeoutSource.Token);

            return BuildResponse(report, DateTimeOffset.UtcNow);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                "Admin system status checks exceeded the bounded execution window. TimeoutMilliseconds={TimeoutMilliseconds}",
                ExecutionTimeout.TotalMilliseconds);

            return BuildFallbackResponse(
                "degraded",
                "The bounded status check did not complete in time.",
                DateTimeOffset.UtcNow);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Admin system status checks failed. ExceptionType={ExceptionType}",
                exception.GetType().Name);

            return BuildFallbackResponse(
                "unhealthy",
                "The status check could not be completed.",
                DateTimeOffset.UtcNow);
        }
    }

    public static AdminSystemStatusResponse BuildResponse(HealthReport report, DateTimeOffset generatedAtUtc)
    {
        ArgumentNullException.ThrowIfNull(report);

        var checks = CuratedChecks
            .Select(check => BuildCheckResponse(check, report, generatedAtUtc))
            .ToArray();

        return new AdminSystemStatusResponse(
            CalculateOverallStatus(checks),
            generatedAtUtc,
            StaleAfterSeconds,
            checks);
    }

    private static AdminSystemStatusCheckResponse BuildCheckResponse(
        CuratedHealthCheck check,
        HealthReport report,
        DateTimeOffset checkedAtUtc)
    {
        if (!report.Entries.TryGetValue(check.RegistrationName, out var entry))
        {
            return new AdminSystemStatusCheckResponse(
                check.PublicKey,
                "unhealthy",
                $"{check.DisplayName} check is not registered.",
                checkedAtUtc);
        }

        var status = ToContractStatus(entry.Status);
        var summary = status switch
        {
            "healthy" => $"{check.DisplayName} is operational.",
            "degraded" => $"{check.DisplayName} requires attention.",
            _ => $"{check.DisplayName} is unavailable or misconfigured."
        };

        return new AdminSystemStatusCheckResponse(
            check.PublicKey,
            status,
            summary,
            checkedAtUtc);
    }

    private static AdminSystemStatusResponse BuildFallbackResponse(
        string status,
        string summary,
        DateTimeOffset generatedAtUtc)
    {
        var checks = CuratedChecks
            .Select(check => new AdminSystemStatusCheckResponse(
                check.PublicKey,
                status,
                summary,
                generatedAtUtc))
            .ToArray();

        return new AdminSystemStatusResponse(
            status,
            generatedAtUtc,
            StaleAfterSeconds,
            checks);
    }

    private static string CalculateOverallStatus(IReadOnlyList<AdminSystemStatusCheckResponse> checks)
    {
        if (checks.Any(check => check.Status == "unhealthy"))
        {
            return "unhealthy";
        }

        return checks.Any(check => check.Status == "degraded") ? "degraded" : "healthy";
    }

    private static string ToContractStatus(HealthStatus status) => status switch
    {
        HealthStatus.Healthy => "healthy",
        HealthStatus.Degraded => "degraded",
        _ => "unhealthy"
    };

    private sealed record CuratedHealthCheck(
        string RegistrationName,
        string PublicKey,
        string DisplayName);
}
