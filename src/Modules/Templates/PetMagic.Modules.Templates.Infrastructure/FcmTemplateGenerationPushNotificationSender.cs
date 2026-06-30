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
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FcmTemplateGenerationPushNotificationSender(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    HttpClient httpClient,
    ILogger<FcmTemplateGenerationPushNotificationSender> logger) : ITemplateGenerationPushNotificationSender
{
    private const string FirebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private GoogleCredential? credential;

    public async Task NotifyGenerationTerminalAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken)
    {
        if (!options.FirebasePush.IsConfigured || generation.UserId == TemplateGenerationService.AdminTestUserId)
        {
            return;
        }

        var tokens = await dbContext.TemplatePushDeviceTokens
            .Where(x => x.UserId == generation.UserId && x.DisabledAtUtc == null)
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
            await SendAsync(generation, token, accessToken, cancellationToken);
        }
    }

    private async Task SendAsync(
        TemplateGenerationResponse generation,
        TemplatePushDeviceToken token,
        string accessToken,
        CancellationToken cancellationToken)
    {
        var isFailed = generation.Status.Equals("Failed", StringComparison.OrdinalIgnoreCase);
        var locale = token.Locale;
        var route = $"/generations/{generation.GenerationId}";
        var eventId = generation.GenerationId.ToString();
        var data = new Dictionary<string, string>
        {
            ["type"] = "template_generation",
            ["generationId"] = eventId,
            ["route"] = route,
            ["status"] = generation.Status,
            ["dedupe_key"] = $"template_generation:{eventId}:{generation.Status}"
        };
        var request = new FcmSendRequest(
            new FcmMessage(
                token.Token,
                new FcmNotification(
                    TemplateGenerationPushNotificationLocalizer.BuildTitle(locale, isFailed),
                    TemplateGenerationPushNotificationLocalizer.BuildBody(locale, isFailed)),
                data,
                new FcmAndroidConfig("high", new FcmAndroidNotification("petmagic_updates")),
                new FcmApnsConfig(new FcmApnsPayload(new FcmAps("default")))));

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.FirebasePush.ProjectId}/messages:send")
        {
            Content = JsonContent.Create(request, options: JsonOptions)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await httpClient.SendAsync(httpRequest, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            logger.LogInformation(
                "FCM send succeeded for template generation event. EventId={EventId} TokenId={TokenId} MessageName={MessageName} CorrelationId={CorrelationId}",
                eventId,
                token.Id,
                TryReadFcmMessageName(body),
                CorrelationContext.ResolveOrCreate());
            return;
        }

        logger.LogWarning(
            "FCM send failed for template generation event. EventId={EventId} TokenId={TokenId} StatusCode={StatusCode} ErrorReason={ErrorReason} CorrelationId={CorrelationId}",
            eventId,
            token.Id,
            response.StatusCode,
            ResolveFcmErrorReason(body),
            CorrelationContext.ResolveOrCreate());

        if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound
            && (body.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase)
                || body.Contains("INVALID_ARGUMENT", StringComparison.OrdinalIgnoreCase)))
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
        var json = options.FirebasePush.ServiceAccountJson;
        if (!string.IsNullOrWhiteSpace(json))
        {
            return CreateCredentialFromJson(NormalizeJson(json));
        }

        return CreateCredentialFromJson(File.ReadAllText(options.FirebasePush.ServiceAccountJsonPath));
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

    private sealed record FcmAps(string Sound);
}
