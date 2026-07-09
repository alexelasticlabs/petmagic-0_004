using System.Text.Json;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StoreSubscriptionVerifier : IStoreSubscriptionVerifier
{
    public const string HttpClientName = "StoreSubscriptionVerifier";

    private const int ProviderJsonResponseMaxChars = 64 * 1024;
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IHttpClientFactory httpClientFactory;
    private readonly IOptions<EconomyOptions> options;
    private readonly IStoreWebhookSecurityValidator appStoreSignedPayloadValidator;
    private readonly ILogger<StoreSubscriptionVerifier>? logger;
    private readonly SemaphoreSlim googleAccessTokenRefreshLock = new(1, 1);
    private string? cachedGoogleAccessToken;
    private DateTimeOffset cachedGoogleAccessTokenExpiresAtUtc;

    public StoreSubscriptionVerifier(
        IHttpClientFactory httpClientFactory,
        IOptions<EconomyOptions> options,
        IStoreWebhookSecurityValidator appStoreSignedPayloadValidator,
        ILogger<StoreSubscriptionVerifier>? logger = null)
    {
        this.httpClientFactory = httpClientFactory;
        this.options = options;
        this.appStoreSignedPayloadValidator = appStoreSignedPayloadValidator;
        this.logger = logger;
    }

    public async Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken)
    {
        return request.PaymentProvider switch
        {
            "google_play" => await VerifyGooglePlayAsync(request, cancellationToken),
            "app_store" => await VerifyAppStoreAsync(request, cancellationToken),
            _ => Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.UnsupportedPaymentProvider)
        };
    }

    public async Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken)
    {
        return request.PaymentProvider switch
        {
            "google_play" => await VerifyGooglePlayProductAsync(request, cancellationToken),
            "app_store" => await VerifyAppStoreProductAsync(request, cancellationToken),
            _ => Result.Failure<StoreProductVerificationResponse>(EconomyErrors.UnsupportedPaymentProvider)
        };
    }

    private HttpClient CreateClient() => httpClientFactory.CreateClient(HttpClientName);

    private bool TryGetCachedGoogleAccessToken(out string? accessToken)
    {
        if (!string.IsNullOrWhiteSpace(cachedGoogleAccessToken)
            && cachedGoogleAccessTokenExpiresAtUtc > DateTimeOffset.UtcNow)
        {
            accessToken = cachedGoogleAccessToken;
            return true;
        }

        accessToken = null;
        return false;
    }

    private void CacheGoogleAccessToken(string accessToken, int expiresInSeconds)
    {
        var now = DateTimeOffset.UtcNow;
        var safeLifetimeSeconds = expiresInSeconds > 120
            ? expiresInSeconds - 60
            : Math.Max(1, expiresInSeconds / 2);
        cachedGoogleAccessToken = accessToken;
        cachedGoogleAccessTokenExpiresAtUtc = now.AddSeconds(Math.Max(1, safeLifetimeSeconds));
    }

    private static StoreAccountBindingState ResolveAccountBindingState(string? providerAccountId, Guid userId)
    {
        if (string.IsNullOrWhiteSpace(providerAccountId))
        {
            return StoreAccountBindingState.Missing;
        }

        return Guid.TryParse(providerAccountId.Trim(), out var boundUserId)
            && boundUserId == userId
                ? StoreAccountBindingState.Matched
                : StoreAccountBindingState.Mismatched;
    }

    private static string DescribeGooglePlayVerificationData(string? verificationData)
    {
        return string.IsNullOrWhiteSpace(verificationData) ? "missing" : "token";
    }

    private static string DescribeAppStoreVerificationData(string? verificationData)
    {
        if (string.IsNullOrWhiteSpace(verificationData))
        {
            return "missing";
        }

        return IsLikelyJws(verificationData) ? "signed_payload" : "receipt";
    }
}
