using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

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
        var isRussian = token.Locale?.StartsWith("ru", StringComparison.OrdinalIgnoreCase) == true;
        var route = "/profile/support";
        var body = BuildBody(notification, isRussian);
        var request = new FcmSendRequest(
            new FcmMessage(
                token.Token,
                new FcmNotification(
                    isRussian ? "Поддержка PetMagic ответила" : "PetMagic Support replied",
                    body),
                new Dictionary<string, string>
                {
                    ["type"] = "support_chat",
                    ["conversationId"] = notification.ConversationId.ToString(),
                    ["messageId"] = notification.MessageId.ToString(),
                    ["route"] = route
                },
                new FcmAndroidConfig("high"),
                new FcmApnsConfig(new FcmApnsPayload(new FcmAps("default")))));

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.ProjectId}/messages:send")
        {
            Content = JsonContent.Create(request, options: JsonOptions)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await httpClient.SendAsync(httpRequest, cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        logger.LogWarning(
            "FCM send failed for support conversation {ConversationId} token {TokenId}: {StatusCode} {Body}",
            notification.ConversationId,
            token.Id,
            response.StatusCode,
            responseBody);

        if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound
            && (responseBody.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase)
                || responseBody.Contains("INVALID_ARGUMENT", StringComparison.OrdinalIgnoreCase)))
        {
            token.DisabledAtUtc = DateTime.UtcNow;
            token.UpdatedAtUtc = token.DisabledAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);
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

    private static string BuildBody(SupportChatPushNotification notification, bool isRussian)
    {
        var body = notification.Body.Trim();
        if (string.IsNullOrWhiteSpace(body) && notification.HasAttachment)
        {
            body = isRussian ? "Новое вложение в диалоге поддержки." : "New attachment in your support conversation.";
        }

        if (body.Length <= 120)
        {
            return body;
        }

        return string.Concat(body.AsSpan(0, 117), "...");
    }

    private static GoogleCredential CreateCredentialFromJson(string json)
    {
        var parameters = JsonSerializer.Deserialize<JsonCredentialParameters>(json)
            ?? throw new InvalidOperationException("Firebase service account JSON is invalid.");
#pragma warning disable CS0618
        return GoogleCredential.FromJsonParameters(parameters);
#pragma warning restore CS0618
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

    private sealed record FcmAndroidConfig(string Priority);

    private sealed record FcmApnsConfig(FcmApnsPayload Payload);

    private sealed record FcmApnsPayload(FcmAps Aps);

    private sealed record FcmAps(string Sound);
}
