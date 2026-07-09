using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class FcmEconomyPushNotificationSender(
    EconomyDbContext dbContext,
    IOptions<EconomyOptions> options,
    IHttpClientFactory httpClientFactory,
    ILogger<FcmEconomyPushNotificationSender> logger) : IEconomyPushDeliverySender
{
    public const string HttpClientName = "EconomyFcm";

    private const string FirebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private GoogleCredential? credential;

    public async Task<PushDeliveryResult> DeliverWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken)
    {
        if (!options.Value.IsFirebasePushConfigured)
        {
            return PushDeliveryResult.Delivered;
        }

        var tokens = await ResolveActiveTokensAsync(userId, cancellationToken);
        if (tokens.Count == 0)
        {
            return PushDeliveryResult.Delivered;
        }
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        var userIdHash = SafeLogValues.StableHash(userId.ToString("D"));
        var results = new List<PushDeliveryResult>(tokens.Count);
        foreach (var token in tokens)
        {
            var locale = token.Locale;
            var title = EconomyPushNotificationLocalizer.BuildWalletTitle(locale);
            var body = EconomyPushNotificationLocalizer.BuildWalletBody(
                locale,
                notification.SparkDelta);

            var data = new Dictionary<string, string>
            {
                ["type"] = "wallet",
                ["status"] = notification.Status,
                ["route"] = "/profile/wallet",
                ["dedupe_key"] = notification.OrderId.HasValue
                    ? $"wallet:{notification.Status}:{notification.OrderId.Value:D}"
                    : $"wallet:{notification.Status}:{userIdHash}"
            };
            if (notification.OrderId.HasValue)
            {
                data["orderId"] = notification.OrderId.Value.ToString("D");
            }

            results.Add(await SendAsync(token, title, body, data, accessToken, cancellationToken));
        }

        return Aggregate(results);
    }

    public async Task<PushDeliveryResult> DeliverPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken)
    {
        if (!options.Value.IsFirebasePushConfigured)
        {
            return PushDeliveryResult.Delivered;
        }

        var tokens = await ResolveActiveTokensAsync(userId, cancellationToken);
        if (tokens.Count == 0)
        {
            return PushDeliveryResult.Delivered;
        }
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        var userIdHash = SafeLogValues.StableHash(userId.ToString("D"));
        var results = new List<PushDeliveryResult>(tokens.Count);
        foreach (var token in tokens)
        {
            var locale = token.Locale;
            var title = EconomyPushNotificationLocalizer.BuildPremiumTitle(locale);
            var body = EconomyPushNotificationLocalizer.BuildPremiumBody(
                locale,
                notification.Status);

            var data = new Dictionary<string, string>
            {
                ["type"] = "premium",
                ["status"] = notification.Status,
                ["route"] = "/profile",
                ["dedupe_key"] = $"premium:{notification.Status}:{notification.Provider ?? "unknown"}:{notification.PlanCode ?? "unknown"}:{userIdHash}"
            };
            if (!string.IsNullOrWhiteSpace(notification.Provider))
            {
                data["provider"] = notification.Provider!;
            }
            if (!string.IsNullOrWhiteSpace(notification.PlanCode))
            {
                data["planCode"] = notification.PlanCode!;
            }

            results.Add(await SendAsync(token, title, body, data, accessToken, cancellationToken));
        }

        return Aggregate(results);
    }

    private async Task<List<EconomyPushDeviceToken>> ResolveActiveTokensAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.EconomyPushDeviceTokens
            .Where(x => x.UserId == userId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .Take(10)
            .ToListAsync(cancellationToken);
    }

    private async Task<PushDeliveryResult> SendAsync(
        EconomyPushDeviceToken token,
        string title,
        string body,
        IReadOnlyDictionary<string, string> data,
        string accessToken,
        CancellationToken cancellationToken)
    {
        var request = new FcmSendRequest(
            new FcmMessage(
                token.Token,
                new FcmNotification(title, body),
                data,
                new FcmAndroidConfig("high", new FcmAndroidNotification("petmagic_updates")),
                new FcmApnsConfig(new FcmApnsPayload(new FcmAps("default")))));

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.Value.FirebaseProjectId}/messages:send")
        {
            Content = JsonContent.Create(request, options: JsonOptions)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await httpClientFactory.CreateClient(HttpClientName).SendAsync(
            httpRequest,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return PushDeliveryResult.Delivered;
        }

        var responseBody = await SafeHttpContentReader.ReadStringPrefixAsync(response.Content, cancellationToken);
        logger.LogWarning(
            "FCM send failed for economy notification. TokenIdHash={TokenIdHash} StatusCode={StatusCode} ErrorReason={ErrorReason} CorrelationIdHash={CorrelationIdHash}",
            SafeLogValues.StableHash(token.Id.ToString("D")),
            response.StatusCode,
            FirebaseMessagingErrorClassifier.ResolveErrorReason(responseBody),
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

        if (FirebaseMessagingErrorClassifier.ShouldDisableToken(response.StatusCode, responseBody))
        {
            token.DisabledAtUtc = DateTime.UtcNow;
            token.UpdatedAtUtc = token.DisabledAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);
            return PushDeliveryResult.Delivered;
        }

        return response.StatusCode == HttpStatusCode.TooManyRequests
            || (int)response.StatusCode >= 500
                ? PushDeliveryResult.Retry("fcm.transient_error")
                : PushDeliveryResult.PermanentFailure("fcm.request_rejected");
    }

    private static PushDeliveryResult Aggregate(IReadOnlyList<PushDeliveryResult> results)
    {
        var retry = results.FirstOrDefault(x => x.Disposition == PushDeliveryDisposition.Retry);
        if (retry is not null)
        {
            return retry;
        }

        if (results.Any(x => x.Disposition == PushDeliveryDisposition.Delivered))
        {
            return PushDeliveryResult.Delivered;
        }

        return results.FirstOrDefault()
            ?? PushDeliveryResult.Delivered;
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        credential ??= LoadCredential().CreateScoped(FirebaseMessagingScope);
        return await credential.UnderlyingCredential.GetAccessTokenForRequestAsync(cancellationToken: cancellationToken);
    }

    private GoogleCredential LoadCredential()
    {
        var json = options.Value.FirebaseServiceAccountJson;
        if (!string.IsNullOrWhiteSpace(json))
        {
            return CreateCredentialFromJson(NormalizeJson(json));
        }

        return CreateCredentialFromJson(File.ReadAllText(options.Value.FirebaseServiceAccountJsonPath));
    }

    private static GoogleCredential CreateCredentialFromJson(string json)
    {
        return CredentialFactory.FromJson(json, credentialType: null);
    }

    private static string NormalizeJson(string value)
    {
        var trimmed = value.Trim();
        if (trimmed.StartsWith('{'))
        {
            return trimmed;
        }

        return Encoding.UTF8.GetString(Convert.FromBase64String(trimmed));
    }

    private sealed record FcmSendRequest(FcmMessage Message);

    private sealed record FcmMessage(
        string Token,
        FcmNotification Notification,
        IReadOnlyDictionary<string, string> Data,
        FcmAndroidConfig Android,
        FcmApnsConfig Apns);

    private sealed record FcmNotification(string Title, string Body);

    private sealed record FcmAndroidConfig(string Priority, FcmAndroidNotification Notification);

    private sealed record FcmAndroidNotification([property: JsonPropertyName("channel_id")] string ChannelId);

    private sealed record FcmApnsConfig(FcmApnsPayload Payload);

    private sealed record FcmApnsPayload(FcmAps Aps);

    private sealed record FcmAps(string Sound);
}
