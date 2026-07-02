using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Host.Api.Observability;

public static class HealthResponseBuilder
{
    public static HealthResponsePayload Build(
        HttpContext context,
        HealthReport report,
        object buildInfo)
    {
        var includeDetailedDiagnostics = CanViewDetailedDiagnostics(context);
        var schedulerState = context.RequestServices
            .GetService<TemplateSchedulerConfigRuntimeState>()
            ?.Snapshot;

        return new HealthResponsePayload(
            report.Status.ToString(),
            buildInfo,
            BuildSchedulerConfigPayload(schedulerState, includeDetailedDiagnostics),
            report.Entries.Select(entry => BuildCheckPayload(entry, includeDetailedDiagnostics)).ToArray(),
            report.TotalDuration);
    }

    public static object? BuildSchedulerConfigPayload(
        TemplateSchedulerConfigRuntimeSnapshot? snapshot,
        bool includeDetailedDiagnostics)
    {
        if (snapshot is null)
        {
            return null;
        }

        return includeDetailedDiagnostics
            ? new DetailedSchedulerConfigPayload(
                snapshot.Initialized,
                snapshot.Component,
                snapshot.ProfileName,
                snapshot.Checksum,
                snapshot.IsMismatchDetected,
                snapshot.MismatchDetails)
            : new PublicSchedulerConfigPayload(
                snapshot.Initialized,
                snapshot.IsMismatchDetected);
    }

    public static IReadOnlyDictionary<string, object?>? BuildCheckDataPayload(
        IReadOnlyDictionary<string, object> data,
        bool includeDetailedDiagnostics)
    {
        if (data.Count == 0)
        {
            return null;
        }

        if (includeDetailedDiagnostics)
        {
            return data.ToDictionary(
                pair => pair.Key,
                pair => (object?)pair.Value,
                StringComparer.Ordinal);
        }

        var sanitized = new Dictionary<string, object?>(StringComparer.Ordinal);
        foreach (var pair in data)
        {
            if (IsSensitiveHealthKey(pair.Key))
            {
                continue;
            }

            sanitized[pair.Key] = pair.Value;
        }

        return sanitized.Count == 0 ? null : sanitized;
    }

    private static HealthCheckPayload BuildCheckPayload(
        KeyValuePair<string, HealthReportEntry> entry,
        bool includeDetailedDiagnostics)
    {
        return new HealthCheckPayload(
            entry.Key,
            entry.Value.Status.ToString(),
            entry.Value.Duration,
            BuildCheckDataPayload(entry.Value.Data, includeDetailedDiagnostics));
    }

    private static bool CanViewDetailedDiagnostics(HttpContext context)
    {
        return context.User.Identity?.IsAuthenticated == true
            && context.User.IsInRole("Admin");
    }

    private static bool IsSensitiveHealthKey(string key)
    {
        var normalized = key.Trim().ToLowerInvariant();
        return normalized is "problems"
            or "checksum"
            or "component"
            or "profilename"
            or "mismatchdetails";
    }
}

public sealed record HealthResponsePayload(
    string Status,
    object Build,
    object? SchedulerConfig,
    IReadOnlyList<HealthCheckPayload> Checks,
    TimeSpan TotalDuration);

public sealed record HealthCheckPayload(
    string Name,
    string Status,
    TimeSpan Duration,
    IReadOnlyDictionary<string, object?>? Data);

public sealed record PublicSchedulerConfigPayload(
    bool Initialized,
    bool IsMismatchDetected);

public sealed record DetailedSchedulerConfigPayload(
    bool Initialized,
    string Component,
    string ProfileName,
    string Checksum,
    bool IsMismatchDetected,
    string? MismatchDetails);
