using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using Npgsql;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private static bool IsUniqueWebhookEventConflict(DbUpdateException exception)
    {
        return exception.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation };
    }

    private Result<StripeWebhookResultResponse> StripeWebhookFailure(Error error, string stage, string? eventType = null)
    {
        EconomyMetrics.RecordStripeWebhookFailure(error.Code, stage, eventType);
        LogPaymentWebhookFailed(error, stage, eventType);
        return Result.Failure<StripeWebhookResultResponse>(error);
    }

    private static string BuildSafeAppStoreWebhookPayloadMetadata(
        (bool Success, string? EventId, string? NotificationType, string? Subtype, string? ProductId, string? ExternalSubscriptionId, string? ExternalPurchaseId, DateTime? ExpiresAtUtc, bool CancelAtPeriodEnd) parsed)
    {
        return JsonSerializer.Serialize(new
        {
            parsed.NotificationType,
            parsed.Subtype,
            parsed.ProductId,
            parsed.ExpiresAtUtc,
            parsed.CancelAtPeriodEnd,
            HasExternalSubscriptionId = !string.IsNullOrWhiteSpace(parsed.ExternalSubscriptionId),
            HasExternalPurchaseId = !string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId)
        });
    }

    private static string BuildSafeGooglePlayWebhookPayloadMetadata(
        (bool Success, string? EventId, int NotificationType, string? ProductId, string? PurchaseToken, bool IsSubscriptionNotification, bool IsOneTimeProductNotification) parsed)
    {
        return JsonSerializer.Serialize(new
        {
            parsed.NotificationType,
            parsed.ProductId,
            parsed.IsSubscriptionNotification,
            parsed.IsOneTimeProductNotification
        });
    }
}
