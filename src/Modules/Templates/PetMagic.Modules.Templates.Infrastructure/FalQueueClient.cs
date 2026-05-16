using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalQueueClient(IHttpClientFactory httpClientFactory, TemplatesOptions options)
{
    public const string HttpClientName = "FalQueue";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<Result<JsonDocument>> RunAsync(string model, object input, CancellationToken cancellationToken)
    {
        if (!options.Fal.IsConfigured)
        {
            return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderUnavailable);
        }

        try
        {
            using var submitRequest = new HttpRequestMessage(HttpMethod.Post, BuildModelUri(model));
            ApplyAuth(submitRequest);
            if (options.Fal.StartTimeoutSeconds > 0)
            {
                submitRequest.Headers.TryAddWithoutValidation(
                    "X-Fal-Request-Timeout",
                    options.Fal.StartTimeoutSeconds.ToString(CultureInfo.InvariantCulture));
            }

            submitRequest.Content = new StringContent(JsonSerializer.Serialize(input, JsonOptions), Encoding.UTF8, "application/json");

            using var submitResponse = await CreateClient().SendAsync(submitRequest, cancellationToken);
            if (!submitResponse.IsSuccessStatusCode)
            {
                return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
            }

            var submitBody = await submitResponse.Content.ReadAsStringAsync(cancellationToken);
            using var submitDocument = JsonDocument.Parse(submitBody);
            var statusUrl = ReadRequiredString(submitDocument.RootElement, "status_url");
            var responseUrl = ReadRequiredString(submitDocument.RootElement, "response_url");
            if (statusUrl is null || responseUrl is null)
            {
                return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
            }

            for (var attempt = 0; attempt < options.Fal.MaxPollingAttempts; attempt++)
            {
                var statusResult = await FetchStatusAsync(statusUrl, cancellationToken);
                if (statusResult.IsFailure)
                {
                    return Result.Failure<JsonDocument>(statusResult.Error);
                }

                using var statusDocument = statusResult.Value;
                var status = ReadRequiredString(statusDocument.RootElement, "status");
                if (string.Equals(status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
                {
                    if (!string.IsNullOrWhiteSpace(ReadRequiredString(statusDocument.RootElement, "error")))
                    {
                        return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
                    }

                    return await FetchResponseAsync(responseUrl, cancellationToken);
                }

                if (!string.Equals(status, "IN_QUEUE", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase))
                {
                    return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
                }

                await Task.Delay(Math.Max(options.Fal.PollIntervalMilliseconds, 250), cancellationToken);
            }

            return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderTimedOut);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
        }
    }

    private async Task<Result<JsonDocument>> FetchStatusAsync(string statusUrl, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, statusUrl);
        ApplyAuth(request);

        using var response = await CreateClient().SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        return Result.Success(JsonDocument.Parse(body));
    }

    private async Task<Result<JsonDocument>> FetchResponseAsync(string responseUrl, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, responseUrl);
        ApplyAuth(request);

        using var response = await CreateClient().SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return Result.Failure<JsonDocument>(TemplatesErrors.AiProviderFailed);
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        return Result.Success(JsonDocument.Parse(body));
    }

    private HttpClient CreateClient() => httpClientFactory.CreateClient(HttpClientName);

    private Uri BuildModelUri(string model)
    {
        var baseUrl = options.Fal.QueueBaseUrl.TrimEnd('/') + "/";
        return new Uri(new Uri(baseUrl), model.TrimStart('/'));
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
}
