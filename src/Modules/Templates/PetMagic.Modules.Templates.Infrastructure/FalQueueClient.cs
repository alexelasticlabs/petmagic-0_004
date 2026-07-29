using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
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

    private const int QueueMetadataMaxChars = 16 * 1024;
    private const int QueueResponseMaxChars = 128 * 1024;
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<Result<FalQueueSubmitResult>> SubmitAsync(
        string model,
        object input,
        FalQueueStageKind stageKind,
        CancellationToken cancellationToken) =>
        await SubmitAsync(model, input, stageKind, callbackToken: null, cancellationToken);

    public async Task<Result<FalQueueSubmitResult>> SubmitAsync(
        string model,
        object input,
        FalQueueStageKind stageKind,
        string? callbackToken,
        CancellationToken cancellationToken)
    {
        if (!options.Fal.IsConfigured)
        {
            return ProviderFailure<FalQueueSubmitResult>("configuration", model, TemplatesErrors.AiProviderUnavailable);
        }

        var requestMayHaveBeenDispatched = false;
        try
        {
            var queueBaseUri = BuildQueueBaseUri();
            var submitUri = BuildSubmitUri(model, callbackToken);
            if (submitUri is null)
            {
                logger.LogWarning(
                    "Rejected invalid fal model route. Stage={Stage} ModelHash={ModelHash}",
                    stageKind.Stage,
                    SafeLogValues.StableHash(model));
                return ProviderFailure<FalQueueSubmitResult>("model.invalid", model, TemplatesErrors.AiProviderFailed);
            }

            using var submitRequest = new HttpRequestMessage(HttpMethod.Post, submitUri);
            ApplyAuth(submitRequest);
            if (options.Fal.StartTimeoutSeconds > 0)
            {
                submitRequest.Headers.TryAddWithoutValidation(
                    "X-Fal-Request-Timeout",
                    options.Fal.StartTimeoutSeconds.ToString(CultureInfo.InvariantCulture));
            }

            submitRequest.Content = new StringContent(JsonSerializer.Serialize(input, JsonOptions), Encoding.UTF8, "application/json");

            await rateLimiter.WaitForPermitAsync("fal", cancellationToken);
            requestMayHaveBeenDispatched = true;
            using var submitResponse = await CreateClient().SendAsync(
                submitRequest,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
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
                    submitResponse.StatusCode == System.Net.HttpStatusCode.TooManyRequests
                        ? TemplatesErrors.AiProviderRateLimited
                        : IsTransientStatusCode(submitResponse.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var submitBody = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                submitResponse.Content,
                cancellationToken,
                QueueMetadataMaxChars);
            using var submitDocument = JsonDocument.Parse(submitBody);
            var requestId = ReadRequiredString(submitDocument.RootElement, "request_id");
            var statusUrl = ResolveQueueCallbackUri(
                ReadRequiredString(submitDocument.RootElement, "status_url"),
                queueBaseUri,
                model,
                requestId,
                "status");
            var responseUrl = ResolveQueueCallbackUri(
                ReadRequiredString(submitDocument.RootElement, "response_url"),
                queueBaseUri,
                model,
                requestId,
                "response");
            var cancelUrl = ResolveQueueCallbackUri(
                ReadRequiredString(submitDocument.RootElement, "cancel_url"),
                queueBaseUri,
                model,
                requestId,
                "cancel");
            if (string.IsNullOrWhiteSpace(requestId)
                || statusUrl is null
                || responseUrl is null
                || cancelUrl is null)
            {
                logger.LogWarning(
                    "fal queue returned an invalid submit payload. MediaType={MediaType} Stage={Stage} Model={Model} ProviderRequestIdHash={ProviderRequestIdHash} QueueBaseUrl={QueueBaseUrl}",
                    stageKind.MediaType,
                    stageKind.Stage,
                    model,
                    SafeLogValues.StableHash(requestId),
                    SafeLogValues.SanitizeText(queueBaseUri.ToString()));
                return ProviderFailure<FalQueueSubmitResult>("submit.parse", model, TemplatesErrors.AiProviderSubmissionUnknown);
            }

            return Result.Success(new FalQueueSubmitResult(requestId, statusUrl, responseUrl, cancelUrl));
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
        catch (JsonException)
        {
            TemplateGenerationMetrics.RecordFalProviderSubmitFailure(stageKind.Stage, model, "response.parse");
            return ProviderFailure<FalQueueSubmitResult>("submit.parse", model, TemplatesErrors.AiProviderSubmissionUnknown);
        }
        catch
        {
            TemplateGenerationMetrics.RecordFalProviderSubmitFailure(stageKind.Stage, model, "exception");
            return ProviderFailure<FalQueueSubmitResult>(
                "request.exception",
                model,
                requestMayHaveBeenDispatched
                    ? TemplatesErrors.AiProviderSubmissionUnknown
                    : TemplatesErrors.AiProviderFailed);
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

    public async Task<FalQueueCancellationResult> CancelAsync(
        string model,
        string requestId,
        Uri cancelUrl,
        CancellationToken cancellationToken)
    {
        if (!options.Fal.IsConfigured)
        {
            return new FalQueueCancellationResult(
                FalQueueCancellationOutcome.TransientFailure,
                "templates.fal_cancel_configuration");
        }

        var validatedUrl = ResolveQueueCallbackUri(
            cancelUrl.ToString(),
            BuildQueueBaseUri(),
            model,
            requestId,
            "cancel");
        if (validatedUrl is null)
        {
            return new FalQueueCancellationResult(
                FalQueueCancellationOutcome.PermanentFailure,
                "templates.fal_cancel_url_invalid");
        }

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Put, validatedUrl);
            ApplyAuth(request);
            using var response = await CreateClient().SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                QueueMetadataMaxChars);
            var providerStatus = TryReadCancellationStatus(body);

            return response.StatusCode switch
            {
                System.Net.HttpStatusCode.Accepted when string.Equals(
                    providerStatus,
                    "CANCELLATION_REQUESTED",
                    StringComparison.Ordinal) => new FalQueueCancellationResult(
                        FalQueueCancellationOutcome.Accepted,
                        null),
                System.Net.HttpStatusCode.BadRequest when string.Equals(
                    providerStatus,
                    "ALREADY_COMPLETED",
                    StringComparison.Ordinal) => new FalQueueCancellationResult(
                        FalQueueCancellationOutcome.AlreadyCompleted,
                        "templates.fal_cancel_already_completed"),
                System.Net.HttpStatusCode.NotFound when string.Equals(
                    providerStatus,
                    "NOT_FOUND",
                    StringComparison.Ordinal) => new FalQueueCancellationResult(
                        FalQueueCancellationOutcome.NotFound,
                        "templates.fal_cancel_not_found"),
                _ when IsTransientStatusCode(response.StatusCode) => new FalQueueCancellationResult(
                    FalQueueCancellationOutcome.TransientFailure,
                    $"templates.fal_cancel_http_{(int)response.StatusCode}"),
                _ => new FalQueueCancellationResult(
                    FalQueueCancellationOutcome.PermanentFailure,
                    $"templates.fal_cancel_http_{(int)response.StatusCode}"),
            };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return new FalQueueCancellationResult(
                FalQueueCancellationOutcome.TransientFailure,
                "templates.fal_cancel_timeout");
        }
        catch (HttpRequestException)
        {
            return new FalQueueCancellationResult(
                FalQueueCancellationOutcome.TransientFailure,
                "templates.fal_cancel_network");
        }
        catch
        {
            return new FalQueueCancellationResult(
                FalQueueCancellationOutcome.PermanentFailure,
                "templates.fal_cancel_failed");
        }
    }

    public Uri? ResolveCancellationUri(
        string model,
        string requestId,
        string? cancelUrl,
        string? statusUrl)
    {
        var queueBaseUri = BuildQueueBaseUri();
        var explicitCancelUri = ResolveQueueCallbackUri(
            cancelUrl,
            queueBaseUri,
            model,
            requestId,
            "cancel");
        if (explicitCancelUri is not null)
        {
            return explicitCancelUri;
        }

        var validatedStatusUri = ResolveQueueCallbackUri(
            statusUrl,
            queueBaseUri,
            model,
            requestId,
            "status");
        if (validatedStatusUri is null)
        {
            return null;
        }

        var cancelPath = validatedStatusUri.AbsolutePath[..^"status".Length] + "cancel";
        var derived = new UriBuilder(validatedStatusUri)
        {
            Path = cancelPath,
            Query = string.Empty,
            Fragment = string.Empty,
        }.Uri;
        return ResolveQueueCallbackUri(
            derived.ToString(),
            queueBaseUri,
            model,
            requestId,
            "cancel");
    }

    public Uri? ResolveStatusUri(string model, string requestId, string? statusUrl)
    {
        return ResolveQueueCallbackUri(
            statusUrl,
            BuildQueueBaseUri(),
            model,
            requestId,
            "status");
    }

    internal static ProviderQueueSubmission? ValidateProviderSubmissionCorrelation(
        FalAiOptions falOptions,
        string model,
        string requestId,
        string? statusUrl,
        string? responseUrl,
        string? cancelUrl)
    {
        if (string.IsNullOrWhiteSpace(falOptions.QueueBaseUrl)
            || !Uri.TryCreate(falOptions.QueueBaseUrl.TrimEnd('/') + "/", UriKind.Absolute, out var queueBaseUri))
        {
            return null;
        }

        var validatedStatus = ResolveQueueCallbackUri(
            statusUrl,
            queueBaseUri,
            model,
            requestId,
            "status");
        var validatedResponse = ResolveQueueCallbackUri(
            responseUrl,
            queueBaseUri,
            model,
            requestId,
            "response");
        var validatedCancel = ResolveQueueCallbackUri(
            cancelUrl,
            queueBaseUri,
            model,
            requestId,
            "cancel");
        return validatedStatus is null || validatedResponse is null || validatedCancel is null
            ? null
            : new ProviderQueueSubmission(
                requestId,
                validatedStatus.ToString(),
                validatedResponse.ToString(),
                validatedCancel.ToString());
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
                "fal queue polling timed out. MediaType={MediaType} Stage={Stage} Model={Model} ProviderRequestIdHash={ProviderRequestIdHash} PollingAttempts={PollingAttempts} PollIntervalMilliseconds={PollIntervalMilliseconds}",
                stageKind.MediaType,
                stageKind.Stage,
                model,
                SafeLogValues.StableHash(requestId),
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

            using var response = await CreateClient().SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return ProviderFailure<JsonDocument>(
                    "status",
                    model,
                    response.StatusCode == System.Net.HttpStatusCode.NotFound
                        ? TemplatesErrors.AiProviderRequestNotFound
                        : IsTransientStatusCode(response.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                QueueMetadataMaxChars);
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
        catch (JsonException)
        {
            return ProviderFailure<JsonDocument>("status.parse", model, TemplatesErrors.AiProviderFailed);
        }
    }

    private async Task<Result<JsonDocument>> FetchResponseAsync(Uri responseUrl, string model, CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, responseUrl);
            ApplyAuth(request);

            using var response = await CreateClient().SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return ProviderFailure<JsonDocument>(
                    "response",
                    model,
                    IsTransientStatusCode(response.StatusCode)
                        ? TemplatesErrors.AiProviderTransientFailure
                        : TemplatesErrors.AiProviderFailed);
            }

            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                QueueResponseMaxChars);
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
        catch (JsonException)
        {
            return ProviderFailure<JsonDocument>("response.parse", model, TemplatesErrors.AiProviderFailed);
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

    private Uri? BuildModelUri(string model)
    {
        if (string.IsNullOrWhiteSpace(model))
        {
            return null;
        }

        var queueBaseUri = BuildQueueBaseUri();
        var normalizedModel = model.Trim();
        if (Uri.TryCreate(normalizedModel, UriKind.Absolute, out _)
            || normalizedModel.StartsWith("/", StringComparison.Ordinal)
            || normalizedModel.Contains('\\')
            || normalizedModel.Contains('?')
            || normalizedModel.Contains('#'))
        {
            return null;
        }

        var modelSegments = normalizedModel
            .Trim('/')
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (modelSegments.Length == 0
            || modelSegments.Any(segment =>
                string.Equals(Uri.UnescapeDataString(segment), ".", StringComparison.Ordinal)
                || string.Equals(Uri.UnescapeDataString(segment), "..", StringComparison.Ordinal)))
        {
            return null;
        }

        var modelUri = new Uri(queueBaseUri, string.Join('/', modelSegments));
        var expectedPathPrefix = queueBaseUri.AbsolutePath.TrimEnd('/') + "/";
        return string.Equals(modelUri.Scheme, queueBaseUri.Scheme, StringComparison.OrdinalIgnoreCase)
            && string.Equals(modelUri.Host, queueBaseUri.Host, StringComparison.OrdinalIgnoreCase)
            && modelUri.Port == queueBaseUri.Port
            && string.IsNullOrEmpty(modelUri.UserInfo)
            && string.IsNullOrEmpty(modelUri.Query)
            && string.IsNullOrEmpty(modelUri.Fragment)
            && modelUri.AbsolutePath.StartsWith(expectedPathPrefix, StringComparison.Ordinal)
                ? modelUri
                : null;
    }

    private Uri? BuildSubmitUri(string model, string? callbackToken = null)
    {
        var modelUri = BuildModelUri(model);
        if (modelUri is null)
        {
            return null;
        }

        if (!Uri.TryCreate(options.Fal.WebhookUrl, UriKind.Absolute, out var webhookUri))
        {
            return modelUri;
        }

        if (!string.IsNullOrWhiteSpace(callbackToken))
        {
            var normalizedToken = callbackToken.Trim();
            if (normalizedToken.Length != 64 || normalizedToken.Any(character => !Uri.IsHexDigit(character)))
            {
                return null;
            }

            webhookUri = new Uri(QueryHelpers.AddQueryString(
                webhookUri.ToString(),
                "attempt_token",
                normalizedToken));
        }

        var submitUrl = QueryHelpers.AddQueryString(modelUri.ToString(), "fal_webhook", webhookUri.ToString());
        return new Uri(submitUrl);
    }

    private static Uri? ResolveQueueCallbackUri(
        string? callbackUrl,
        Uri queueBaseUri,
        string model,
        string? requestId,
        string terminalSuffix)
    {
        if (string.IsNullOrWhiteSpace(requestId)
            || requestId.Length > 128
            || requestId.Any(character => !char.IsAsciiLetterOrDigit(character) && character is not '-' and not '_')
            || !Uri.TryCreate(callbackUrl, UriKind.Absolute, out var callbackUri))
        {
            return null;
        }

        if (!string.Equals(callbackUri.Scheme, queueBaseUri.Scheme, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(callbackUri.Host, queueBaseUri.Host, StringComparison.OrdinalIgnoreCase)
            || callbackUri.Port != queueBaseUri.Port
            || !string.IsNullOrEmpty(callbackUri.UserInfo)
            || !string.IsNullOrEmpty(callbackUri.Query)
            || !string.IsNullOrEmpty(callbackUri.Fragment))
        {
            return null;
        }

        var expectedPath = $"{queueBaseUri.AbsolutePath.TrimEnd('/')}/{model.Trim('/')}/requests/{requestId}/{terminalSuffix}";
        return string.Equals(callbackUri.AbsolutePath, expectedPath, StringComparison.Ordinal)
            ? callbackUri
            : null;
    }

    private static string? TryReadCancellationStatus(string body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            return ReadRequiredString(document.RootElement, "status");
        }
        catch (JsonException)
        {
            return null;
        }
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
    Uri ResponseUrl,
    Uri CancelUrl);

internal sealed record FalQueueCancellationResult(
    FalQueueCancellationOutcome Outcome,
    string? ErrorCode);

internal enum FalQueueCancellationOutcome
{
    Accepted,
    AlreadyCompleted,
    NotFound,
    TransientFailure,
    PermanentFailure,
}

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
