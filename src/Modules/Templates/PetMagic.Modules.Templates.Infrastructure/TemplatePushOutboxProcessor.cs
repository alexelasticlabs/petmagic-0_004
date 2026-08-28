using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePushOutboxProcessor(
    TemplatesDbContext dbContext,
    ITemplateGenerationPushDeliverySender deliverySender,
    ILogger<TemplatePushOutboxProcessor> logger,
    TemplatesOptions? options = null,
    IHttpClientFactory? httpClientFactory = null,
    ITemplateFeedRealtimeService? templateFeedRealtimeService = null)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var message = await ClaimNextAsync(cancellationToken);
        if (message is null)
        {
            return await CleanupNextSentAsync(cancellationToken);
        }

        PushOutboxMetrics.RecordAttempt("templates");

        PushDeliveryResult result;
        var catalogChanged = false;
        if (message.AttemptCount > PushOutboxPolicy.MaxAttempts)
        {
            result = PushDeliveryResult.PermanentFailure("push.attempts_exhausted");
        }
        else try
        {
            if (message.Kind == TemplateGenerationPushNotificationOutbox.GenerationTerminalKind)
            {
                result = await deliverySender.DeliverGenerationTerminalAsync(
                    Deserialize<TemplateGenerationResponse>(message.PayloadJson),
                    cancellationToken);
            }
            else if (message.Kind == TemplateLocalizationOutbox.Kind)
            {
                var localizationResult = await DeliverTemplateLocalizationAsync(message, cancellationToken);
                result = localizationResult.Result;
                catalogChanged = localizationResult.CatalogChanged;
            }
            else
            {
                result = PushDeliveryResult.PermanentFailure("push.kind_unknown");
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template push outbox delivery failed. MessageIdHash={MessageIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(message.Id.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            result = PushDeliveryResult.Retry(
                message.Kind == TemplateLocalizationOutbox.Kind
                    ? "template_localization.transport_error"
                    : "fcm.transport_error");
        }

        ApplyResult(message, result);
        PushOutboxMetrics.RecordResult("templates", message);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            if (catalogChanged && templateFeedRealtimeService is not null)
            {
                await templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(cancellationToken);
            }
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            logger.LogInformation(
                "Template outbox completion ignored because the processing lease was reclaimed. MessageIdHash={MessageIdHash}",
                SafeLogValues.StableHash(message.Id.ToString("D")));
        }
        return true;
    }

    private async Task<PushOutboxMessage?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational())
        {
            return await ClaimNextTrackedAsync(cancellationToken);
        }

        var now = DateTime.UtcNow;
        var ids = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE templates_push_outbox
            SET "Status" = {1}, "AttemptCount" = "AttemptCount" + 1,
                "LockId" = {4}, "LockExpiresAtUtc" = {5}, "UpdatedAtUtc" = {2}
            WHERE "Id" = (
                SELECT "Id" FROM templates_push_outbox
                WHERE (("Status" = {0} AND "NextAttemptAtUtc" <= {2} AND "AttemptCount" < {3})
                       OR ("Status" = {1} AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
                    AND "Kind" IN ({6}, {7})
                ORDER BY "NextAttemptAtUtc", "CreatedAtUtc"
                FOR UPDATE SKIP LOCKED LIMIT 1)
            RETURNING "Id" AS "Value";
            """,
            (int)PushOutboxStatus.Queued,
            (int)PushOutboxStatus.Processing,
            now,
            PushOutboxPolicy.MaxAttempts,
            Guid.NewGuid(),
            now.Add(PushOutboxPolicy.LeaseDuration),
            TemplateGenerationPushNotificationOutbox.GenerationTerminalKind,
            TemplateLocalizationOutbox.Kind).ToListAsync(cancellationToken);

        var id = ids.FirstOrDefault();
        return id == Guid.Empty
            ? null
            : await dbContext.PushOutboxMessages.SingleAsync(x => x.Id == id, cancellationToken);
    }

    private async Task<PushOutboxMessage?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var message = await dbContext.PushOutboxMessages
            .Where(x => x.Kind == TemplateGenerationPushNotificationOutbox.GenerationTerminalKind
                        || x.Kind == TemplateLocalizationOutbox.Kind)
            .Where(x => (x.Status == PushOutboxStatus.Queued
                        && x.NextAttemptAtUtc <= now
                        && x.AttemptCount < PushOutboxPolicy.MaxAttempts)
                    || (x.Status == PushOutboxStatus.Processing
                        && (x.LockExpiresAtUtc == null || x.LockExpiresAtUtc <= now)))
            .OrderBy(x => x.NextAttemptAtUtc)
            .ThenBy(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (message is null)
        {
            return null;
        }

        message.Status = PushOutboxStatus.Processing;
        message.AttemptCount++;
        message.LockId = Guid.NewGuid();
        message.LockExpiresAtUtc = now.Add(PushOutboxPolicy.LeaseDuration);
        message.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return message;
    }

    private static T Deserialize<T>(string json) =>
        JsonSerializer.Deserialize<T>(json, JsonOptions)
        ?? throw new JsonException("Push outbox payload is empty.");

    private async Task<TemplateLocalizationDeliveryResult> DeliverTemplateLocalizationAsync(
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        if (options is null || httpClientFactory is null)
        {
            return TemplateLocalizationDeliveryResult.Retry("template_localization.dispatcher_unavailable");
        }

        TemplateLocalizationOutbox.TemplateLocalizationPayload payload;
        try
        {
            payload = Deserialize<TemplateLocalizationOutbox.TemplateLocalizationPayload>(message.PayloadJson);
        }
        catch (JsonException)
        {
            return TemplateLocalizationDeliveryResult.PermanentFailure("template_localization.payload_invalid");
        }

        if (payload.TemplateId == Guid.Empty
            || string.IsNullOrWhiteSpace(payload.SourceFingerprint)
            || string.IsNullOrWhiteSpace(payload.Title)
            || string.IsNullOrWhiteSpace(payload.ShortDescription)
            || !TemplateLocalizationOutbox.IsTargetLocaleSupported(payload, options))
        {
            return TemplateLocalizationDeliveryResult.PermanentFailure("template_localization.payload_invalid");
        }

        var localizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
            payload.Title,
            payload.ShortDescription,
            payload.PetPhotoRequirements,
            payload.ImagePrompt,
            payload.PreprocessingPrompt,
            payload.KlingPrompt,
            [payload.TargetLocale],
            payload.SourceLocale,
            httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
            cancellationToken,
            payload.MusicDescription);
        if (string.IsNullOrWhiteSpace(localizedTextsJson)
            || !TemplateLocalizationOutbox.TryReadTranslation(localizedTextsJson, payload.TargetLocale, out var translation))
        {
            return TemplateLocalizationDeliveryResult.Retry("template_localization.translation_unavailable");
        }

        var template = await dbContext.TemplateItems.SingleOrDefaultAsync(
            item => item.Id == payload.TemplateId,
            cancellationToken);
        if (template is null || template.DeletedAtUtc is not null)
        {
            return TemplateLocalizationDeliveryResult.Delivered;
        }

        if (!string.Equals(
                TemplateLocalizationOutbox.CreateSourceFingerprint(template, options.SourceLocalizationLocale),
                payload.SourceFingerprint,
                StringComparison.Ordinal))
        {
            return TemplateLocalizationDeliveryResult.Delivered;
        }

        template.LocalizedTextsJson = TemplateLocalizationOutbox.MergeTranslation(
            template.LocalizedTextsJson,
            payload.TargetLocale,
            translation);
        await StampCatalogUpsertAsync(template, cancellationToken);
        return TemplateLocalizationDeliveryResult.DeliveredWithCatalogChange;
    }

    private async Task StampCatalogUpsertAsync(TemplateItem template, CancellationToken cancellationToken)
    {
        var currentVersion = await dbContext.TemplateCatalogChanges
            .AsNoTracking()
            .OrderByDescending(change => change.Version)
            .Select(change => (long?)change.Version)
            .FirstOrDefaultAsync(cancellationToken) ?? 0L;
        var now = DateTime.UtcNow;
        var nextVersion = currentVersion + 1L;

        template.Version = nextVersion;
        template.UpdatedAtUtc = now;
        dbContext.TemplateCatalogChanges.Add(new TemplateCatalogChange
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            Version = nextVersion,
            ChangeType = TemplateCatalogChangeType.Upsert,
            UpdatedAtUtc = now
        });
    }

    private static void ApplyResult(PushOutboxMessage message, PushDeliveryResult result)
    {
        var now = DateTime.UtcNow;
        message.LockId = null;
        message.LockExpiresAtUtc = null;
        message.UpdatedAtUtc = now;
        message.LastErrorCode = result.ErrorCode;
        if (result.Disposition == PushDeliveryDisposition.Delivered)
        {
            message.Status = PushOutboxStatus.Sent;
            message.SentAtUtc = now;
        }
        else if (result.Disposition == PushDeliveryDisposition.PermanentFailure
                 || message.AttemptCount >= PushOutboxPolicy.MaxAttempts)
        {
            message.Status = PushOutboxStatus.DeadLetter;
        }
        else
        {
            message.Status = PushOutboxStatus.Queued;
            message.NextAttemptAtUtc = now.Add(PushOutboxPolicy.RetryDelay(message.AttemptCount));
        }
    }

    private async Task<bool> CleanupNextSentAsync(CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow.Subtract(PushOutboxPolicy.SentRetention);
        var message = await dbContext.PushOutboxMessages
            .Where(x => (x.Kind == TemplateGenerationPushNotificationOutbox.GenerationTerminalKind
                         || x.Kind == TemplateLocalizationOutbox.Kind)
                && x.Status == PushOutboxStatus.Sent
                && x.SentAtUtc <= cutoff)
            .OrderBy(x => x.SentAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (message is null)
        {
            return false;
        }

        dbContext.PushOutboxMessages.Remove(message);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private readonly record struct TemplateLocalizationDeliveryResult(
        PushDeliveryResult Result,
        bool CatalogChanged)
    {
        public static TemplateLocalizationDeliveryResult Delivered => new(PushDeliveryResult.Delivered, false);

        public static TemplateLocalizationDeliveryResult DeliveredWithCatalogChange => new(PushDeliveryResult.Delivered, true);

        public static TemplateLocalizationDeliveryResult Retry(string errorCode) => new(PushDeliveryResult.Retry(errorCode), false);

        public static TemplateLocalizationDeliveryResult PermanentFailure(string errorCode) => new(PushDeliveryResult.PermanentFailure(errorCode), false);
    }
}
