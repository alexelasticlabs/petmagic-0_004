using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.BuildingBlocks.Security;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public sealed class TemplateContentHealthCheck(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IHttpClientFactory httpClientFactory) : IHealthCheck
{
    public const string HttpClientName = "petmagic.template-content-health";

    private const int MaxTemplatesToProbe = 100;
    private const int MaxConcurrentMediaProbes = 8;
    private const int MaxProblemsToReport = 25;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(template => template.Assets)
            // TemplateVisibilityPolicy direct-check allowlist: operational content health probes active,
            // non-deleted production templates and must not depend on request/user visibility context.
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Where(template => !template.IsQaOnly)
            .OrderByDescending(template => template.UpdatedAtUtc)
            .Take(MaxTemplatesToProbe)
            .ToArrayAsync(cancellationToken);

        var client = httpClientFactory.CreateClient(HttpClientName);
        var problems = new List<string>();
        var probeTasks = new List<Task>();
        using var probeGate = new SemaphoreSlim(MaxConcurrentMediaProbes);
        foreach (var template in templates)
        {
            var preview = template.Assets.FirstOrDefault(asset => asset.AssetKind == TemplateAssetKind.Preview);
            if (preview is null || string.IsNullOrWhiteSpace(preview.Url))
            {
                AddProblem(problems, template, "missing_preview");
                continue;
            }

            probeTasks.Add(CheckReachableThrottledAsync(client, probeGate, problems, template, "preview", preview.Url, cancellationToken));
            if (IsVideoPreview(preview))
            {
                if (preview.DurationSeconds is null or <= 0)
                {
                    AddProblem(problems, template, "broken_video_preview_duration");
                }
            }

            if (template.TemplateType == TemplateType.Video)
            {
                var reference = template.Assets.FirstOrDefault(asset => asset.AssetKind == TemplateAssetKind.ReferenceMotion);
                if (reference is null || string.IsNullOrWhiteSpace(reference.Url))
                {
                    AddProblem(problems, template, "missing_reference_motion");
                    continue;
                }

                probeTasks.Add(CheckReachableThrottledAsync(client, probeGate, problems, template, "reference_motion", reference.Url, cancellationToken));
            }
        }

        await Task.WhenAll(probeTasks);

        var data = new Dictionary<string, object>
        {
            ["checkedTemplates"] = templates.Length,
            ["problemCount"] = problems.Count,
            ["problems"] = problems.Take(MaxProblemsToReport).ToArray(),
            ["truncated"] = problems.Count > MaxProblemsToReport
        };

        return problems.Count == 0
            ? HealthCheckResult.Healthy("Production-visible template content is reachable.", data)
            : HealthCheckResult.Unhealthy("Production-visible template content has broken preview/reference media.", data: data);
    }

    private async Task CheckReachableThrottledAsync(
        HttpClient client,
        SemaphoreSlim probeGate,
        List<string> problems,
        Entities.TemplateItem template,
        string role,
        string rawUrl,
        CancellationToken cancellationToken)
    {
        await probeGate.WaitAsync(cancellationToken);
        try
        {
            await CheckReachableAsync(client, problems, template, role, rawUrl, cancellationToken);
        }
        finally
        {
            probeGate.Release();
        }
    }

    private async Task CheckReachableAsync(
        HttpClient client,
        List<string> problems,
        Entities.TemplateItem template,
        string role,
        string rawUrl,
        CancellationToken cancellationToken)
    {
        if (!TryResolveProbeUri(rawUrl, out var uri)
            || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            AddProblem(problems, template, $"{role}_url_invalid");
            return;
        }

        if (SafeNetworkTargetPolicy.IsPrivateNetworkTarget(uri) && !IsConfiguredPublicOrigin(uri))
        {
            AddProblem(problems, template, $"{role}_url_private_network");
            return;
        }

        using var request = new HttpRequestMessage(HttpMethod.Head, uri);
        using var response = await SendWithGetFallbackAsync(client, request, uri, cancellationToken);
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            TemplateGenerationMetrics.RecordPreviewNotFound(role);
        }

        if (!response.IsSuccessStatusCode)
        {
            AddProblem(problems, template, $"{role}_http_{(int)response.StatusCode}");
        }
    }

    private static async Task<HttpResponseMessage> SendWithGetFallbackAsync(
        HttpClient client,
        HttpRequestMessage headRequest,
        Uri uri,
        CancellationToken cancellationToken)
    {
        var response = await client.SendAsync(headRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (response.StatusCode != System.Net.HttpStatusCode.MethodNotAllowed)
        {
            return response;
        }

        response.Dispose();
        using var getRequest = new HttpRequestMessage(HttpMethod.Get, uri);
        return await client.SendAsync(getRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
    }

    private bool TryResolveProbeUri(string rawUrl, out Uri uri)
    {
        uri = null!;
        var trimmed = rawUrl.Trim();
        if (Uri.TryCreate(trimmed, UriKind.Absolute, out var absoluteUri))
        {
            uri = absoluteUri;
            return true;
        }

        var resolvedUrl = $"{options.PublicBaseUrl.TrimEnd('/')}/{trimmed.TrimStart('/')}";
        if (!Uri.TryCreate(resolvedUrl, UriKind.Absolute, out var resolvedUri))
        {
            return false;
        }

        uri = resolvedUri;
        return true;
    }

    private bool IsConfiguredPublicOrigin(Uri uri)
    {
        return IsSameOrigin(uri, options.PublicBaseUrl)
            || IsSameOrigin(uri, options.R2.PublicBaseUrl);
    }

    private static bool IsSameOrigin(Uri uri, string configuredBaseUrl)
    {
        return Uri.TryCreate(configuredBaseUrl, UriKind.Absolute, out var configuredUri)
            && string.Equals(uri.Scheme, configuredUri.Scheme, StringComparison.OrdinalIgnoreCase)
            && string.Equals(uri.IdnHost, configuredUri.IdnHost, StringComparison.OrdinalIgnoreCase)
            && uri.Port == configuredUri.Port;
    }

    private static bool IsVideoPreview(Entities.TemplateAsset asset)
    {
        var contentType = asset.ContentType?.Trim().ToLowerInvariant() ?? string.Empty;
        return contentType.StartsWith("video/", StringComparison.Ordinal)
            || asset.Url.EndsWith(".mp4", StringComparison.OrdinalIgnoreCase)
            || asset.Url.EndsWith(".webm", StringComparison.OrdinalIgnoreCase)
            || asset.Url.EndsWith(".mov", StringComparison.OrdinalIgnoreCase)
            || asset.Url.EndsWith(".m4v", StringComparison.OrdinalIgnoreCase);
    }

    private static void AddProblem(List<string> problems, Entities.TemplateItem template, string code)
    {
        lock (problems)
        {
            problems.Add($"{template.Id:N}:{template.Title}:{code}");
        }
    }
}
