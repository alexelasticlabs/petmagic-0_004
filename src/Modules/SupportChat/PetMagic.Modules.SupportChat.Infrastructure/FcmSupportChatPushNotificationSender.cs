using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class FcmSupportChatPushNotificationSender(
    SupportChatDbContext dbContext,
    SupportChatPushOptions options,
    HttpClient httpClient,
    ILogger<FcmSupportChatPushNotificationSender> logger) : ISupportChatPushNotificationSender
{
    private const string FirebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private GoogleCredential? credential;

    public async Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
    {
        if (!options.IsConfigured)
        {
            return;
        }

        var tokens = await dbContext.SupportPushDeviceTokens
            .Where(x => x.UserId == notification.UserId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .Take(10)
            .ToListAsync(cancellationToken);

        if (tokens.Count == 0)
        {
            return;
        }

        var accessToken = await GetAccessTokenAsync(cancellationToken);
        foreach (var token in tokens)
        {
            await SendAsync(notification, token, accessToken, cancellationToken);
        }
    }

    private async Task SendAsync(
        SupportChatPushNotification notification,
        SupportPushDeviceToken token,
        string accessToken,
        CancellationToken cancellationToken)
    {
        var locale = token.Locale;
        var route = "/profile/support";
        var eventId = $"{notification.ConversationId}:{notification.MessageId}";
        var body = BuildBody(notification, locale);
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

        using var response = await httpClient.SendAsync(httpRequest, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            logger.LogInformation(
                "FCM send succeeded for support event. EventId={EventId} TokenId={TokenId} MessageName={MessageName} CorrelationId={CorrelationId}",
                eventId,
                token.Id,
                TryReadFcmMessageName(responseBody),
                CorrelationContext.ResolveOrCreate());
            return;
        }

        logger.LogWarning(
            "FCM send failed for support event. EventId={EventId} TokenId={TokenId} StatusCode={StatusCode} ErrorReason={ErrorReason} CorrelationId={CorrelationId}",
            eventId,
            token.Id,
            response.StatusCode,
            FirebaseMessagingErrorClassifier.ResolveErrorReason(responseBody),
            CorrelationContext.ResolveOrCreate());

        if (FirebaseMessagingErrorClassifier.ShouldDisableToken(response.StatusCode, responseBody))
        {
            token.DisabledAtUtc = DateTime.UtcNow;
            token.UpdatedAtUtc = token.DisabledAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private static string? TryReadFcmMessageName(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.TryGetProperty("name", out var name) && name.ValueKind == JsonValueKind.String
                ? name.GetString()
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
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

    private static string BuildBody(SupportChatPushNotification notification, string? locale)
    {
        var body = notification.Body?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(body))
        {
            body = SupportChatPushNotificationLocalizer.BuildFallbackBody(
                locale,
                notification.HasAttachment);
        }

        if (body.Length <= 120)
        {
            return body;
        }

        return string.Concat(body.AsSpan(0, 117), "...");
    }

    private static GoogleCredential CreateCredentialFromJson(string json)
    {
        return GoogleCredential.FromJson(json);
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
