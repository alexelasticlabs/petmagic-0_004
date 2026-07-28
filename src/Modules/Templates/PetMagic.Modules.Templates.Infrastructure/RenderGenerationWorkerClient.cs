using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class RenderGenerationWorkerClient(
    IHttpClientFactory httpClientFactory,
    RenderGenerationWorkerOptions options) : IRenderGenerationWorkerClient
{
    public const string HttpClientName = "TemplatesRenderGenerationWorker";

    private const int MaximumResponseChars = 64 * 1024;

    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    public bool IsConfigured => options.IsConfigured
        && string.Equals(options.ExpectedServiceType, "background_worker", StringComparison.Ordinal)
        && NormalizeRepository(options.ExpectedRepository) is not null;

    public async Task<Result<RenderGenerationWorkerTargetStatus>> GetTargetStatusAsync(
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.NotConfigured);
        }

        try
        {
            using var request = CreateRequest(HttpMethod.Get, TargetServicePath());
            using var response = await SendAsync(request, cancellationToken);
            if (response.StatusCode != HttpStatusCode.OK)
            {
                return Result.Failure<RenderGenerationWorkerTargetStatus>(MapResponseError(response));
            }

            var payload = await DeserializeAsync<RenderServicePayload>(response, cancellationToken);
            if (payload is null)
            {
                return Result.Failure<RenderGenerationWorkerTargetStatus>(
                    RenderGenerationWorkerErrors.UpstreamUnavailable("invalid_response"));
            }

            return ValidateTarget(payload);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("timeout"));
        }
        catch (HttpRequestException)
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("network_error"));
        }
        catch (JsonException)
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("invalid_response"));
        }
    }

    public async Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
        CancellationToken cancellationToken)
    {
        var target = await GetTargetStatusAsync(cancellationToken);
        if (target.IsFailure)
        {
            return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(target.Error);
        }

        try
        {
            using var request = CreateRequest(HttpMethod.Get, $"{TargetServicePath()}/instances");
            using var response = await SendAsync(request, cancellationToken);
            if (response.StatusCode != HttpStatusCode.OK)
            {
                return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(
                    MapResponseError(response));
            }

            var payload = await DeserializeAsync<RenderInstancePayload[]>(response, cancellationToken);
            if (payload is null || payload.Any(instance =>
                    string.IsNullOrWhiteSpace(instance.Id) || instance.CreatedAt is null))
            {
                return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(
                    RenderGenerationWorkerErrors.UpstreamUnavailable("invalid_response"));
            }

            IReadOnlyList<RenderGenerationWorkerInstance> instances = payload
                .Select(instance => new RenderGenerationWorkerInstance(
                    instance.Id!,
                    instance.CreatedAt!.Value.UtcDateTime))
                .ToArray();

            return Result.Success(instances);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("timeout"));
        }
        catch (HttpRequestException)
        {
            return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("network_error"));
        }
        catch (JsonException)
        {
            return Result.Failure<IReadOnlyList<RenderGenerationWorkerInstance>>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("invalid_response"));
        }
    }

    public async Task<Result<RenderScaleAccepted>> ScaleAsync(
        int targetInstances,
        CancellationToken cancellationToken)
    {
        if (targetInstances < options.MinimumInstances || targetInstances > options.MaximumInstances)
        {
            return Result.Failure<RenderScaleAccepted>(
                RenderGenerationWorkerErrors.InvalidTarget(
                    options.MinimumInstances,
                    options.MaximumInstances));
        }

        var target = await GetTargetStatusAsync(cancellationToken);
        if (target.IsFailure)
        {
            return Result.Failure<RenderScaleAccepted>(target.Error);
        }

        if (target.Value.AutoscalingEnabled)
        {
            return Result.Failure<RenderScaleAccepted>(
                RenderGenerationWorkerErrors.AutoscalingEnabled);
        }

        if (target.Value.DesiredInstances == targetInstances)
        {
            return Result.Success(new RenderScaleAccepted(targetInstances, DateTime.UtcNow));
        }

        try
        {
            using var request = CreateRequest(HttpMethod.Post, $"{TargetServicePath()}/scale");
            request.Content = JsonContent.Create(new ScaleRequest(targetInstances), options: SerializerOptions);
            using var response = await SendAsync(request, cancellationToken);
            if (response.StatusCode != HttpStatusCode.Accepted)
            {
                return Result.Failure<RenderScaleAccepted>(MapResponseError(response));
            }

            return Result.Success(new RenderScaleAccepted(targetInstances, DateTime.UtcNow));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Result.Failure<RenderScaleAccepted>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("timeout"));
        }
        catch (HttpRequestException)
        {
            return Result.Failure<RenderScaleAccepted>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("network_error"));
        }
    }

    private Result<RenderGenerationWorkerTargetStatus> ValidateTarget(RenderServicePayload payload)
    {
        if (!string.Equals(payload.Id, options.ServiceId, StringComparison.Ordinal))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.TargetMismatch("service_id"));
        }

        if (!string.Equals(payload.Name, options.ExpectedServiceName, StringComparison.Ordinal))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.TargetMismatch("service_name"));
        }

        if (!string.Equals(payload.Type, options.ExpectedServiceType, StringComparison.Ordinal))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.TargetMismatch("service_type"));
        }

        if (!string.Equals(payload.OwnerId, options.ExpectedOwnerId, StringComparison.Ordinal))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.TargetMismatch("owner_id"));
        }

        var expectedRepository = NormalizeRepository(options.ExpectedRepository);
        var actualRepository = NormalizeRepository(payload.Repo);
        if (expectedRepository is null
            || actualRepository is null
            || !string.Equals(actualRepository, expectedRepository, StringComparison.Ordinal))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.TargetMismatch("repository"));
        }

        if (payload.ServiceDetails is null
            || string.IsNullOrWhiteSpace(payload.ServiceDetails.Plan)
            || string.IsNullOrWhiteSpace(payload.ServiceDetails.Region))
        {
            return Result.Failure<RenderGenerationWorkerTargetStatus>(
                RenderGenerationWorkerErrors.UpstreamUnavailable("invalid_response"));
        }

        var autoscalingEnabled = payload.ServiceDetails.NumInstances is null
            || payload.ServiceDetails.Autoscaling is { ValueKind: not JsonValueKind.Null and not JsonValueKind.Undefined };

        return Result.Success(new RenderGenerationWorkerTargetStatus(
            payload.Id!,
            payload.Name!,
            payload.Type!,
            payload.OwnerId!,
            actualRepository,
            payload.ServiceDetails.Plan,
            payload.ServiceDetails.Region,
            payload.ServiceDetails.NumInstances,
            autoscalingEnabled));
    }

    private async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken) =>
        await httpClientFactory
            .CreateClient(HttpClientName)
            .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

    private HttpRequestMessage CreateRequest(HttpMethod method, string relativePath)
    {
        var request = new HttpRequestMessage(method, relativePath);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.ApiKey);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        return request;
    }

    private string TargetServicePath() =>
        $"services/{Uri.EscapeDataString(options.ServiceId)}";

    private static async Task<T?> DeserializeAsync<T>(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
            response.Content,
            cancellationToken,
            MaximumResponseChars);
        return string.IsNullOrWhiteSpace(body)
            ? default
            : JsonSerializer.Deserialize<T>(body, SerializerOptions);
    }

    private static Error MapResponseError(HttpResponseMessage response) => response.StatusCode switch
    {
        HttpStatusCode.Unauthorized => RenderGenerationWorkerErrors.AuthenticationFailed,
        HttpStatusCode.Forbidden => RenderGenerationWorkerErrors.PermissionDenied,
        HttpStatusCode.NotFound => RenderGenerationWorkerErrors.TargetMismatch("service_id"),
        HttpStatusCode.TooManyRequests => RenderGenerationWorkerErrors.RateLimited(
            ResolveRetryAfterSeconds(response)),
        _ => RenderGenerationWorkerErrors.UpstreamUnavailable(
            "unexpected_status",
            (int)response.StatusCode)
    };

    private static int? ResolveRetryAfterSeconds(HttpResponseMessage response)
    {
        var retryAfter = response.Headers.RetryAfter;
        if (retryAfter?.Delta is { } delta)
        {
            return Math.Max(0, (int)Math.Ceiling(delta.TotalSeconds));
        }

        if (retryAfter?.Date is { } date)
        {
            return Math.Max(0, (int)Math.Ceiling((date - DateTimeOffset.UtcNow).TotalSeconds));
        }

        return null;
    }

    private static string? NormalizeRepository(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || !Uri.TryCreate(value.Trim(), UriKind.Absolute, out var repositoryUri)
            || !string.Equals(repositoryUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            || !repositoryUri.IsDefaultPort
            || !string.IsNullOrEmpty(repositoryUri.UserInfo)
            || !string.IsNullOrEmpty(repositoryUri.Query)
            || !string.IsNullOrEmpty(repositoryUri.Fragment))
        {
            return null;
        }

        var path = repositoryUri.AbsolutePath.Trim('/');
        if (path.EndsWith(".git", StringComparison.OrdinalIgnoreCase))
        {
            path = path[..^4];
        }

        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        return $"https://{repositoryUri.IdnHost.ToLowerInvariant()}/{path}";
    }

    private sealed record ScaleRequest(
        [property: JsonPropertyName("numInstances")] int NumInstances);

    private sealed record RenderServicePayload(
        [property: JsonPropertyName("id")] string? Id,
        [property: JsonPropertyName("name")] string? Name,
        [property: JsonPropertyName("type")] string? Type,
        [property: JsonPropertyName("ownerId")] string? OwnerId,
        [property: JsonPropertyName("repo")] string? Repo,
        [property: JsonPropertyName("serviceDetails")] RenderServiceDetailsPayload? ServiceDetails);

    private sealed record RenderServiceDetailsPayload(
        [property: JsonPropertyName("plan")] string? Plan,
        [property: JsonPropertyName("region")] string? Region,
        [property: JsonPropertyName("numInstances")] int? NumInstances,
        [property: JsonPropertyName("autoscaling")] JsonElement? Autoscaling);

    private sealed record RenderInstancePayload(
        [property: JsonPropertyName("id")] string? Id,
        [property: JsonPropertyName("createdAt")] DateTimeOffset? CreatedAt);
}
