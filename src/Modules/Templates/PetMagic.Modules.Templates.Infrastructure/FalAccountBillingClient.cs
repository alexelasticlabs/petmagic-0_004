using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalAccountBillingClient(
    IHttpClientFactory httpClientFactory,
    TemplatesOptions options,
    ILogger<FalAccountBillingClient> logger)
{
    public const string HttpClientName = "FalPlatformApi";
    private const int BalanceResponseMaxChars = 16 * 1024;

    public async Task<FalAccountBillingResult> GetCurrentBalanceAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Fal.ApiKey))
        {
            return FalAccountBillingResult.Failure("api_key_missing");
        }

        try
        {
            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                "https://api.fal.ai/v1/account/billing?expand=credits");
            request.Headers.Authorization = new AuthenticationHeaderValue("Key", options.Fal.ApiKey);

            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            {
                return FalAccountBillingResult.Failure("authentication_failed");
            }

            if (!response.IsSuccessStatusCode)
            {
                return FalAccountBillingResult.Failure($"http_{(int)response.StatusCode}");
            }

            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                BalanceResponseMaxChars);
            using var document = JsonDocument.Parse(body);
            var balance = ReadBalanceUsd(document.RootElement);
            return balance is null
                ? FalAccountBillingResult.Failure("invalid_response")
                : FalAccountBillingResult.Success(balance.Value);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "fal account billing API check failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            return FalAccountBillingResult.Failure("request_failed");
        }
    }

    internal static decimal? ReadBalanceUsd(JsonElement root)
    {
        if (!root.TryGetProperty("credits", out var credits)
            || credits.ValueKind != JsonValueKind.Object
            || !credits.TryGetProperty("current_balance", out var balanceElement))
        {
            return null;
        }

        return balanceElement.ValueKind switch
        {
            JsonValueKind.Number when balanceElement.TryGetDecimal(out var numeric) => numeric,
            JsonValueKind.String when decimal.TryParse(
                balanceElement.GetString(),
                NumberStyles.Number,
                CultureInfo.InvariantCulture,
                out var parsed) => parsed,
            _ => null
        };
    }
}
internal sealed record FalAccountBillingResult(bool IsSuccess, decimal? BalanceUsd, string? ErrorCode)
{
    public static FalAccountBillingResult Success(decimal balanceUsd) => new(true, balanceUsd, null);

    public static FalAccountBillingResult Failure(string errorCode) => new(false, null, errorCode);
}
