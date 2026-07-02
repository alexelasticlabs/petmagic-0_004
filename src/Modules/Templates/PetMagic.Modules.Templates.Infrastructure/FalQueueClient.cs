using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.WebUtilities;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalQueueClient(
    IHttpClientFactory httpClientFactory,
    TemplatesOptions options,
    TemplateAiProviderRateLimiter rateLimiter,
    ILogger<FalQueueClient> logger)
{
    public const string HttpClientName = "FalQueue";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<Result<FalQueueSubmitResult>> SubmitAsync(
        string model,
        object input,
        FalQueueStageKind stageKind,
        CancellationToken cancellationToken)
    {
        if (!options.Fal.IsConfigured)
        {
            return ProviderFailure<FalQueueSubmitResult>("configuration", model, TemplatesErrors.AiProviderUnavailable);
        }

        try
        {
            var queueBaseUri = BuildQueueBaseUri();
            using var submitRequest = new HttpRequestMessage(HttpMethod.Post, BuildSubmitUri(model));
            ApplyAuth(submitRequest);
            if (options.Fal.StartTimeoutSeconds > 0)
            {
                submitRequest.Headers.TryAddWithoutValidation(
                    "X-Fal-Request-Timeout",
                    options.Fal.StartTimeoutSeconds.ToString(CultureInfo.InvariantCulture));
            }

            submitRequest.Content = new StringContent(JsonSerializer.Serialize(input, JsonOptions), Encoding.UTF8, "application/json");

            await rateLimiter.WaitForPermitAsync("fal", cancellationToken);
            using var submitResponse = await CreateClient().SendAsync(submitRequest, cancellationToken);
            if (!submitResponse.IsSuccessStatusCode)
            {
                TemplateGenerationMetrics.RecordFalProviderSubmitFailure(
                    stageKind.Stage,
                    model,
                    ((int)submitResponse.StatusCode).ToString(CultureInfo.InvariantCulture));
                if (submitResponse.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                {
                    TemplateGenerationMetrics.RecordFalProviderRateLimitError(stageKind.Stage, model);
                }

                return ProviderFailure<FalQueueSubmitResult>(
                    "submit",
                    model,
                    IsTransientStatusCode(submitResponse.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var submitBody = await submitResponse.Content.ReadAsStringAsync(cancellationToken);
            using var submitDocument = JsonDocument.Parse(submitBody);
            var requestId = ReadRequiredString(submitDocument.RootElement, "request_id");
            var statusUrl = ResolveQueueCallbackUri(
                ReadRequiredString(submitDocument.RootElement, "status_url"),
                queueBaseUri,
                "/status/");
            var responseUrl = ResolveQueueCallbackUri(
                ReadRequiredString(submitDocument.RootElement, "response_url"),
                queueBaseUri,
                "/response/");
            if (string.IsNullOrWhiteSpace(requestId) || statusUrl is null || responseUrl is null)
            {
                logger.LogWarning(
                    "fal queue returned an invalid submit payload. MediaType={MediaType} Stage={Stage} Model={Model} ProviderRequestId={ProviderRequestId} QueueBaseUrl={QueueBaseUrl}",
                    stageKind.MediaType,
                    stageKind.Stage,
                    model,
                    requestId,
                    queueBaseUri);
                return ProviderFailure<FalQueueSubmitResult>("submit.parse", model, TemplatesErrors.AiProviderFailed);
            }

            return Result.Success(new FalQueueSubmitResult(requestId, statusUrl, responseUrl));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            // HttpClient timeout (not an external shutdown request): the provider is slow or
            // unreachable, which is a transient condition worth requeueing instead of failing.
            TemplateGenerationMetrics.RecordFalProviderSubmitFailure(stageKind.Stage, model, "timeout");
            return ProviderFailure<FalQueueSubmitResult>("request.timeout", model, TemplatesErrors.AiProviderTransientFailure);
        }
        catch (HttpRequestException)
        {
            TemplateGenerationMetrics.RecordFalProviderSubmitFailure(stageKind.Stage, model, "network");
            return ProviderFailure<FalQueueSubmitResult>("request.network", model, TemplatesErrors.AiProviderTransientFailure);
        }
        catch
        {
            TemplateGenerationMetrics.RecordFalProviderSubmitFailure(stageKind.Stage, model, "exception");
            return ProviderFailure<FalQueueSubmitResult>("request.exception", model, TemplatesErrors.AiProviderFailed);
        }
    }

    private static bool IsTransientStatusCode(System.Net.HttpStatusCode statusCode)
    {
        return statusCode is System.Net.HttpStatusCode.RequestTimeout
            or System.Net.HttpStatusCode.TooManyRequests
            or System.Net.HttpStatusCode.InternalServerError
            or System.Net.HttpStatusCode.BadGateway
            or System.Net.HttpStatusCode.ServiceUnavailable
            or System.Net.HttpStatusCode.GatewayTimeout;
    }

    public async Task<Result<FalQueueStatusResult>> GetStatusAsync(
        Uri statusUrl,
        string model,
        CancellationToken cancellationToken)
    {
        var statusResult = await FetchStatusAsync(statusUrl, model, cancellationToken);
        if (statusResult.IsFailure)
        {
            return Result.Failure<FalQueueStatusResult>(statusResult.Error);
        }

        using var statusDocument = statusResult.Value;
        var root = statusDocument.RootElement;
        var status = ReadRequiredString(root, "status");
        if (string.IsNullOrWhiteSpace(status))
        {
            return ProviderFailure<FalQueueStatusResult>("status.parse", model, TemplatesErrors.AiProviderFailed);
        }

        return Result.Success(new FalQueueStatusResult(
            status,
            ReadRequiredString(root, "request_id"),
            ReadRequiredString(root, "error"),
            ReadInferenceTimeSeconds(root)));
    }

    public Task<Result<JsonDocument>> GetResponseAsync(
        Uri responseUrl,
        string model,
        CancellationToken cancellationToken)
    {
        return FetchResponseAsync(responseUrl, model, cancellationToken);
    }

    public async Task<Result<FalQueueRunResult>> RunAsync(
        string model,
        object input,
        FalQueueStageKind stageKind,
        CancellationToken cancellationToken)
    {
        var submitResult = await SubmitAsync(model, input, stageKind, cancellationToken);
        if (submitResult.IsFailure)
        {
            return Result.Failure<FalQueueRunResult>(submitResult.Error);
        }

        var requestId = submitResult.Value.RequestId;
        var statusUrl = submitResult.Value.StatusUrl;
        var responseUrl = submitResult.Value.ResponseUrl;
        try
        {
            var maxPollingAttempts = ResolveMaxPollingAttempts(stageKind);
            for (var attempt = 0; attempt < maxPollingAttempts; attempt++)
            {
                var statusResult = await GetStatusAsync(statusUrl, model, cancellationToken);
                if (statusResult.IsFailure)
                {
                    return Result.Failure<FalQueueRunResult>(statusResult.Error);
                }

                var status = statusResult.Value.Status;
                if (string.Equals(status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
                {
                    if (!string.IsNullOrWhiteSpace(statusResult.Value.Error))
                    {
                        return ProviderFailure<FalQueueRunResult>("status.error", model, TemplatesErrors.AiProviderFailed);
                    }

                    var responseResult = await GetResponseAsync(responseUrl, model, cancellationToken);
                    if (responseResult.IsFailure)
                    {
                        return Result.Failure<FalQueueRunResult>(responseResult.Error);
                    }

                    return Result.Success(new FalQueueRunResult(
                        responseResult.Value,
                        requestId ?? statusResult.Value.RequestId,
                        statusResult.Value.InferenceTimeSeconds));
                }

                if (!string.Equals(status, "IN_QUEUE", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase))
                {
                    return ProviderFailure<FalQueueRunResult>("status", model, TemplatesErrors.AiProviderFailed);
                }

                await Task.Delay(Math.Max(options.Fal.PollIntervalMilliseconds, 250), cancellationToken);
            }

            logger.LogWarning(
                "fal queue polling timed out. MediaType={MediaType} Stage={Stage} Model={Model} ProviderRequestId={ProviderRequestId} PollingAttempts={PollingAttempts} PollIntervalMilliseconds={PollIntervalMilliseconds}",
                stageKind.MediaType,
                stageKind.Stage,
                model,
                requestId,
                maxPollingAttempts,
                options.Fal.PollIntervalMilliseconds);
            TemplateGenerationMetrics.RecordFalTimeout(stageKind.MediaType, stageKind.Stage, model);
            return ProviderFailure<FalQueueRunResult>("poll.timeout", model, TemplatesErrors.AiProviderTimedOut);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return ProviderFailure<FalQueueRunResult>("request.exception", model, TemplatesErrors.AiProviderFailed);
        }
    }

    private async Task<Result<JsonDocument>> FetchStatusAsync(Uri statusUrl, string model, CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, statusUrl);
            ApplyAuth(request);

            using var response = await CreateClient().SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return ProviderFailure<JsonDocument>(
                    "status",
                    model,
                    IsTransientStatusCode(response.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            return Result.Success(JsonDocument.Parse(body));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return ProviderFailure<JsonDocument>("status.timeout", model, TemplatesErrors.AiProviderTransientFailure);
        }
        catch (HttpRequestException)
        {
            return ProviderFailure<JsonDocument>("status.network", model, TemplatesErrors.AiProviderTransientFailure);
        }
    }

    private async Task<Result<JsonDocument>> FetchResponseAsync(Uri responseUrl, string model, CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, responseUrl);
            ApplyAuth(request);

            using var response = await CreateClient().SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return ProviderFailure<JsonDocument>(
                    "response",
                    model,
                    IsTransientStatusCode(response.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            return Result.Success(JsonDocument.Parse(body));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return ProviderFailure<JsonDocument>("response.timeout", model, TemplatesErrors.AiProviderTransientFailure);
        }
        catch (HttpRequestException)
        {
            return ProviderFailure<JsonDocument>("response.network", model, TemplatesErrors.AiProviderTransientFailure);
        }
    }

    private HttpClient CreateClient() => httpClientFactory.CreateClient(HttpClientName);

    private int ResolveMaxPollingAttempts(FalQueueStageKind stageKind)
    {
        var configured = stageKind.Stage switch
        {
            FalQueueStages.ImageGeneration => options.Fal.ImageMaxPollingAttempts,
            FalQueueStages.ImagePreprocessing => options.Fal.ImagePreprocessingMaxPollingAttempts,
            FalQueueStages.VideoGeneration => options.Fal.VideoMaxPollingAttempts,
            _ => options.Fal.MaxPollingAttempts
        };

        return Math.Max(1, configured > 0 ? configured : options.Fal.MaxPollingAttempts);
    }

    private Uri BuildQueueBaseUri()
    {
        return new Uri(options.Fal.QueueBaseUrl.TrimEnd('/') + "/");
    }

    private Uri BuildModelUri(string model)
    {
        return new Uri(BuildQueueBaseUri(), model.TrimStart('/'));
    }

    private Uri BuildSubmitUri(string model)
    {
        var modelUri = BuildModelUri(model);
        if (!Uri.TryCreate(options.Fal.WebhookUrl, UriKind.Absolute, out var webhookUri))
        {
            return modelUri;
        }

        var submitUrl = QueryHelpers.AddQueryString(modelUri.ToString(), "fal_webhook", webhookUri.ToString());
        return new Uri(submitUrl);
    }

    private static Uri? ResolveQueueCallbackUri(string? callbackUrl, Uri queueBaseUri, string requiredPathPrefix)
    {
        if (!Uri.TryCreate(callbackUrl, UriKind.Absolute, out var callbackUri))
        {
            return null;
        }

        if (!string.Equals(callbackUri.Scheme, queueBaseUri.Scheme, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(callbackUri.Host, queueBaseUri.Host, StringComparison.OrdinalIgnoreCase)
            || callbackUri.Port != queueBaseUri.Port)
        {
            return null;
        }

        var allowedBasePath = queueBaseUri.AbsolutePath;
        if (!allowedBasePath.EndsWith("/", StringComparison.Ordinal))
        {
            allowedBasePath += "/";
        }

        if (!callbackUri.AbsolutePath.StartsWith(allowedBasePath, StringComparison.Ordinal))
        {
            return null;
        }

        var callbackRelativePath = callbackUri.AbsolutePath[allowedBasePath.Length..];
        if (!callbackRelativePath.StartsWith(requiredPathPrefix.TrimStart('/'), StringComparison.Ordinal))
        {
            return null;
        }

        return callbackUri;
    }

    private void ApplyAuth(HttpRequestMessage request)
    {
        request.Headers.Authorization = new AuthenticationHeaderValue("Key", options.Fal.ApiKey);
    }

    private static string? ReadRequiredString(JsonElement element, string propertyName)
    {
        return element.TryGetProperty(propertyName, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : null;
    }

    private static double? ReadInferenceTimeSeconds(JsonElement element)
    {
        if (!element.TryGetProperty("metrics", out var metrics) || metrics.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (!metrics.TryGetProperty("inference_time", out var inferenceTime))
        {
            return null;
        }

        if (inferenceTime.ValueKind == JsonValueKind.Number && inferenceTime.TryGetDouble(out var numericValue))
        {
            return numericValue;
        }

        if (inferenceTime.ValueKind == JsonValueKind.String
            && double.TryParse(inferenceTime.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedValue))
        {
            return parsedValue;
        }

        return null;
    }

    private static Result<T> ProviderFailure<T>(string stage, string model, Error error)
    {
        TemplateGenerationMetrics.RecordAiProviderError("fal", stage, error.Code, model);
        return Result.Failure<T>(error);
    }
}

internal sealed record FalQueueRunResult(
    JsonDocument Response,
    string? RequestId,
    double? InferenceTimeSeconds);

internal sealed record FalQueueSubmitResult(
    string RequestId,
    Uri StatusUrl,
    Uri ResponseUrl);

internal sealed record FalQueueStatusResult(
    string Status,
    string? RequestId,
    string? Error,
    double? InferenceTimeSeconds);

internal readonly record struct FalQueueStageKind(string MediaType, string Stage);

internal static class FalQueueStages
{
    public const string ImageGeneration = "image_generation";
    public const string ImagePreprocessing = "image_preprocessing";
    public const string VideoGeneration = "video_generation";
}
