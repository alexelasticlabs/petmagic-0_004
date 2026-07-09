using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class FcmSupportChatPushNotificationSender(
    SupportChatDbContext dbContext,
    SupportChatPushOptions options,
    HttpClient httpClient,
    ILogger<FcmSupportChatPushNotificationSender> logger) : ISupportChatPushDeliverySender
{
    private const string FirebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private GoogleCredential? credential;

    public async Task<PushDeliveryResult> DeliverUserAsync(
        SupportChatPushNotification notification,
        CancellationToken cancellationToken)
    {
        if (!options.IsConfigured)
        {
            return PushDeliveryResult.Delivered;
        }

        var tokens = await dbContext.SupportPushDeviceTokens
            .Where(x => x.UserId == notification.UserId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .Take(10)
            .ToListAsync(cancellationToken);

        if (tokens.Count == 0)
        {
            return PushDeliveryResult.Delivered;
        }

        var accessToken = await GetAccessTokenAsync(cancellationToken);
        var results = new List<PushDeliveryResult>(tokens.Count);
        foreach (var token in tokens)
        {
            results.Add(await SendAsync(notification, token, accessToken, cancellationToken));
        }

        return Aggregate(results);
    }

    private async Task<PushDeliveryResult> SendAsync(
        SupportChatPushNotification notification,
        SupportPushDeviceToken token,
        string accessToken,
        CancellationToken cancellationToken)
    {
        var locale = token.Locale;
        var route = "/profile/support";
        var eventId = $"{notification.ConversationId}:{notification.MessageId}";
        var body = BuildBody(notification.HasAttachment, locale);
        var data = new Dictionary<string, string>
        {
            ["type"] = "support_chat",
            ["conversationId"] = notification.ConversationId.ToString(),
            ["messageId"] = notification.MessageId.ToString(),
            ["route"] = route,
            ["dedupe_key"] = $"support_chat:{notification.ConversationId}:{notification.MessageId}"
        };
        var request = new FcmSendRequest(
            new FcmMessage(
                token.Token,
                new FcmNotification(
                    SupportChatPushNotificationLocalizer.BuildTitle(locale),
                    body),
                data,
                new FcmAndroidConfig("high", new FcmAndroidNotification("petmagic_updates")),
                new FcmApnsConfig(new FcmApnsPayload(new FcmAps("default", notification.UserUnreadCount)))));

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.ProjectId}/messages:send")
        {
            Content = JsonContent.Create(request, options: JsonOptions)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await httpClient.SendAsync(
            httpRequest,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        var eventIdHash = SafeLogValues.StableHash(eventId);
        var tokenIdHash = SafeLogValues.StableHash(token.Id.ToString("D"));
        if (response.IsSuccessStatusCode)
        {
            logger.LogInformation(
                "FCM send succeeded for support event. EventIdHash={EventIdHash} TokenIdHash={TokenIdHash} CorrelationIdHash={CorrelationIdHash}",
                eventIdHash,
                tokenIdHash,
                SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));
            return PushDeliveryResult.Delivered;
        }

        var responseBody = await SafeHttpContentReader.ReadStringPrefixAsync(response.Content, cancellationToken);
        logger.LogWarning(
            "FCM send failed for support event. EventIdHash={EventIdHash} TokenIdHash={TokenIdHash} StatusCode={StatusCode} ErrorReason={ErrorReason} CorrelationIdHash={CorrelationIdHash}",
            eventIdHash,
            tokenIdHash,
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

        return results.FirstOrDefault() ?? PushDeliveryResult.Delivered;
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        credential ??= LoadCredential().CreateScoped(FirebaseMessagingScope);
        return await credential.UnderlyingCredential.GetAccessTokenForRequestAsync(cancellationToken: cancellationToken);
    }

    private GoogleCredential LoadCredential()
    {
        if (!string.IsNullOrWhiteSpace(options.ServiceAccountJson))
        {
            return CreateCredentialFromJson(NormalizeJson(options.ServiceAccountJson));
        }

        return CreateCredentialFromJson(File.ReadAllText(options.ServiceAccountJsonPath));
    }

    private static string BuildBody(bool hasAttachment, string? locale)
    {
        return SupportChatPushNotificationLocalizer.BuildFallbackBody(
            locale,
            hasAttachment);
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

    private sealed record FcmAps(string Sound, int Badge);
}
