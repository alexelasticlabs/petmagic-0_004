using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record RenderGenerationWorkerTargetStatus(
    string ServiceId,
    string Name,
    string Type,
    string OwnerId,
    string Repository,
    string Plan,
    string Region,
    int? DesiredInstances,
    bool AutoscalingEnabled);

public sealed record RenderGenerationWorkerInstance(
    string Id,
    DateTime CreatedAtUtc);

public sealed record RenderScaleAccepted(
    int TargetInstances,
    DateTime AcceptedAtUtc);

public static class RenderGenerationWorkerErrors
{
    public static readonly Error NotConfigured = new(
        "templates.render.not_configured",
        "Render generation worker control is not configured.");

    public static readonly Error AutoscalingEnabled = new(
        "templates.render.autoscaling_enabled",
        "Manual scaling is disabled while Render autoscaling is enabled.");

    public static readonly Error AuthenticationFailed = new(
        "templates.render.auth_failed",
        "Render API authentication failed.");

    public static readonly Error PermissionDenied = new(
        "templates.render.permission_denied",
        "Render API permission was denied.");

    public static Error TargetMismatch(string field) => new(
        "templates.render.target_mismatch",
        "The Render service does not match the configured generation worker target.",
        new Dictionary<string, object?>
        {
            ["field"] = field
        });

    public static Error InvalidTarget(int minimumInstances, int maximumInstances) => new(
        "templates.render.invalid_target",
        "The requested Render instance count is outside the allowed range.",
        new Dictionary<string, object?>
        {
            ["minimumInstances"] = minimumInstances,
            ["maximumInstances"] = maximumInstances
        });

    public static Error RateLimited(int? retryAfterSeconds = null) => new(
        "templates.render.rate_limited",
        "Render API rate limit was exceeded.",
        retryAfterSeconds.HasValue
            ? new Dictionary<string, object?> { ["retryAfterSeconds"] = retryAfterSeconds.Value }
            : null);

    public static Error UpstreamUnavailable(string reason, int? statusCode = null) => new(
        "templates.render.upstream_unavailable",
        "Render API is temporarily unavailable or returned an invalid response.",
        new Dictionary<string, object?>
        {
            ["reason"] = reason,
            ["statusCode"] = statusCode
        });
}
