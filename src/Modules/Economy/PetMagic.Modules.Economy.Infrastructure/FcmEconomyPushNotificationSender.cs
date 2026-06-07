using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class FcmEconomyPushNotificationSender(
    EconomyDbContext dbContext,
    IOptions<EconomyOptions> options,
    IHttpClientFactory httpClientFactory,
    ILogger<FcmEconomyPushNotificationSender> logger) : IEconomyPushNotificationSender
{
    public const string HttpClientName = "EconomyFcm";

    private const string FirebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private GoogleCredential? credential;

    public async Task NotifyWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken)
    {
        if (!options.Value.IsFirebasePushConfigured)
        {
            return;
        }

        var tokens = await ResolveActiveTokensAsync(userId, cancellationToken);
        if (tokens.Count == 0)
        {
            return;
        }

        var accessToken = await GetAccessTokenAsync(cancellationToken);
        foreach (var token in tokens)
        {
            var isRussian = token.Locale?.StartsWith("ru", StringComparison.OrdinalIgnoreCase) == true;
            var title = notification.Title ??
                (isRussian ? "Баланс PawSpark обновлен" : "PawSpark balance updated");
            var body = notification.Body ??
                (notification.SparkDelta.HasValue && notification.SparkDelta.Value > 0
                    ? (isRussian ? $"Начислено +{notification.SparkDelta.Value} PawSpark." : $"Added +{notification.SparkDelta.Value} PawSpark.")
                    : (isRussian ? "Проверьте последние операции в кошельке." : "Open wallet to see your latest transaction."));

            var data = new Dictionary<string, string>
            {
                ["type"] = "wallet",
                ["status"] = notification.Status,
                ["route"] = "/profile/wallet",
                ["dedupe_key"] = notification.OrderId.HasValue
                    ? $"wallet:{notification.Status}:{notification.OrderId.Value:D}"
                    : $"wallet:{notification.Status}:{userId:D}"
            };
            if (notification.OrderId.HasValue)
            {
                data["orderId"] = notification.OrderId.Value.ToString("D");
            }

            await SendAsync(token, title, body, data, accessToken, cancellationToken);
        }
    }

    public async Task NotifyPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken)
    {
        if (!options.Value.IsFirebasePushConfigured)
        {
            return;
        }

        var tokens = await ResolveActiveTokensAsync(userId, cancellationToken);
        if (tokens.Count == 0)
        {
            return;
        }

        var accessToken = await GetAccessTokenAsync(cancellationToken);
        foreach (var token in tokens)
        {
            var isRussian = token.Locale?.StartsWith("ru", StringComparison.OrdinalIgnoreCase) == true;
            var title = notification.Title ??
                (isRussian ? "Статус Premium обновлен" : "Premium status updated");
            var body = notification.Body ??
                BuildPremiumBody(notification.Status, isRussian);

            var data = new Dictionary<string, string>
            {
                ["type"] = "premium",
                ["status"] = notification.Status,
                ["route"] = "/profile",
                ["dedupe_key"] = $"premium:{notification.Status}:{notification.Provider ?? "unknown"}:{notification.PlanCode ?? "unknown"}:{userId:D}"
            };
            if (!string.IsNullOrWhiteSpace(notification.Provider))
            {
                data["provider"] = notification.Provider!;
            }
            if (!string.IsNullOrWhiteSpace(notification.PlanCode))
            {
                data["planCode"] = notification.PlanCode!;
            }

            await SendAsync(token, title, body, data, accessToken, cancellationToken);
        }
    }

    private async Task<List<EconomyPushDeviceToken>> ResolveActiveTokensAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.EconomyPushDeviceTokens
            .Where(x => x.UserId == userId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .Take(10)
            .ToListAsync(cancellationToken);
    }

    private async Task SendAsync(
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
                new FcmAndroidConfig("high"),
                new FcmApnsConfig(new FcmApnsPayload(new FcmAps("default")))));

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.Value.FirebaseProjectId}/messages:send")
        {
            Content = JsonContent.Create(request, options: JsonOptions)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await httpClientFactory.CreateClient(HttpClientName).SendAsync(httpRequest, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        logger.LogWarning(
            "FCM send failed for economy notification. TokenId={TokenId} StatusCode={StatusCode} ErrorReason={ErrorReason} CorrelationId={CorrelationId}",
            token.Id,
            response.StatusCode,
            ResolveFcmErrorReason(responseBody),
            CorrelationContext.ResolveOrCreate());

        if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound
            && (responseBody.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase)
                || responseBody.Contains("INVALID_ARGUMENT", StringComparison.OrdinalIgnoreCase)))
        {
            token.DisabledAtUtc = DateTime.UtcNow;
            token.UpdatedAtUtc = token.DisabledAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private static string ResolveFcmErrorReason(string body)
    {
        if (body.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase))
        {
            return "unregistered";
        }

        if (body.Contains("INVALID_ARGUMENT", StringComparison.OrdinalIgnoreCase))
        {
            return "invalid_argument";
        }

        return "fcm_send_failed";
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

    private static string BuildPremiumBody(string status, bool isRussian)
    {
        return status.ToLowerInvariant() switch
        {
            "active" or "succeeded" or "success" => isRussian
                ? "Premium активирован. Возможности обновлены."
                : "Premium is active. Your access has been updated.",
            "canceled" or "cancelled" => isRussian
                ? "Premium отменен. Проверить статус можно в профиле."
                : "Premium was canceled. You can review status in Profile.",
            "expired" => isRussian
                ? "Срок Premium завершился."
                : "Premium subscription has expired.",
            "failed" or "error" => isRussian
                ? "Не удалось обновить Premium. Попробуйте снова."
                : "Premium update failed. Please try again.",
            _ => isRussian
                ? "Статус Premium обновлен."
                : "Premium status has been updated."
        };
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
