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
    internal const string AdminApiKeyMissingErrorCode = "admin_api_key_missing";
    internal const string AuthenticationFailedErrorCode = "authentication_failed";
    internal const string AdminScopeRequiredErrorCode = "admin_scope_required";
    internal const string RateLimitedErrorCode = "rate_limited";
    internal const string ProviderUnavailableErrorCode = "provider_unavailable";
    internal const string AccountMismatchErrorCode = "account_mismatch";
    internal const string UnsupportedCurrencyErrorCode = "unsupported_currency";
    internal const string InvalidResponseErrorCode = "invalid_response";
    internal const string RequestTimeoutErrorCode = "request_timeout";
    internal const string RequestFailedErrorCode = "request_failed";

    private const int BalanceResponseMaxChars = 16 * 1024;
    private static readonly HashSet<string> SafeErrorCodes = new(StringComparer.Ordinal)
    {
        AdminApiKeyMissingErrorCode,
        AuthenticationFailedErrorCode,
        AdminScopeRequiredErrorCode,
        RateLimitedErrorCode,
        ProviderUnavailableErrorCode,
        AccountMismatchErrorCode,
        UnsupportedCurrencyErrorCode,
        InvalidResponseErrorCode,
        RequestTimeoutErrorCode,
        RequestFailedErrorCode
    };

    public async Task<FalAccountBillingResult> GetCurrentBalanceAsync(CancellationToken cancellationToken)
    {
        if (!options.Fal.IsBillingAdminKeyConfigured)
        {
            return FalAccountBillingResult.Failure(AdminApiKeyMissingErrorCode);
        }

        try
        {
            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                "https://api.fal.ai/v1/account/billing?expand=credits");
            request.Headers.Authorization = new AuthenticationHeaderValue("Key", options.Fal.AdminApiKey.Trim());

            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                return FalAccountBillingResult.Failure(AuthenticationFailedErrorCode);
            }

            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                return FalAccountBillingResult.Failure(AdminScopeRequiredErrorCode);
            }

            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                return FalAccountBillingResult.Failure(RateLimitedErrorCode);
            }

            if ((int)response.StatusCode >= 500)
            {
                return FalAccountBillingResult.Failure(ProviderUnavailableErrorCode);
            }

            if (!response.IsSuccessStatusCode)
            {
                return FalAccountBillingResult.Failure(RequestFailedErrorCode);
            }

            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                BalanceResponseMaxChars);
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            var balance = ReadBalanceUsd(root);
            var currency = ReadCurrency(root);
            if (balance is null || string.IsNullOrWhiteSpace(currency))
            {
                return FalAccountBillingResult.Failure(InvalidResponseErrorCode);
            }

            if (!string.Equals(currency, "USD", StringComparison.OrdinalIgnoreCase))
            {
                return FalAccountBillingResult.Failure(UnsupportedCurrencyErrorCode);
            }

            var expectedAccountUsername = options.Fal.ExpectedAccountUsername.Trim();
            if (!string.IsNullOrEmpty(expectedAccountUsername))
            {
                var actualAccountUsername = ReadUsername(root);
                if (string.IsNullOrWhiteSpace(actualAccountUsername))
                {
                    return FalAccountBillingResult.Failure(InvalidResponseErrorCode);
                }

                if (!string.Equals(
                        actualAccountUsername.Trim(),
                        expectedAccountUsername,
                        StringComparison.OrdinalIgnoreCase))
                {
                    return FalAccountBillingResult.Failure(AccountMismatchErrorCode);
                }
            }

            return FalAccountBillingResult.Success(balance.Value);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException exception)
        {
            logger.LogWarning(
                "fal account billing API check timed out. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            return FalAccountBillingResult.Failure(RequestTimeoutErrorCode);
        }
        catch (JsonException exception)
        {
            logger.LogWarning(
                "fal account billing API returned an invalid response. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            return FalAccountBillingResult.Failure(InvalidResponseErrorCode);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "fal account billing API check failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
            return FalAccountBillingResult.Failure(RequestFailedErrorCode);
        }
    }

    internal static string? NormalizeErrorCode(string? errorCode)
    {
        return string.IsNullOrWhiteSpace(errorCode)
            ? null
            : SafeErrorCodes.Contains(errorCode)
                ? errorCode
                : RequestFailedErrorCode;
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

    private static string? ReadCurrency(JsonElement root)
    {
        return root.TryGetProperty("credits", out var credits)
            && credits.ValueKind == JsonValueKind.Object
            && credits.TryGetProperty("currency", out var currency)
            && currency.ValueKind == JsonValueKind.String
                ? currency.GetString()
                : null;
    }

    private static string? ReadUsername(JsonElement root)
    {
        return root.TryGetProperty("username", out var username)
            && username.ValueKind == JsonValueKind.String
                ? username.GetString()
                : null;
    }
}
internal sealed record FalAccountBillingResult(bool IsSuccess, decimal? BalanceUsd, string? ErrorCode)
{
    public static FalAccountBillingResult Success(decimal balanceUsd) => new(true, balanceUsd, null);

    public static FalAccountBillingResult Failure(string errorCode) => new(false, null, errorCode);
}
