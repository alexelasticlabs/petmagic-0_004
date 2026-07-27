using System.Diagnostics.CodeAnalysis;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private const string AdminPremiumRevokeEventType = "AdminImmediateCancelRequested";
    private const string AdminPremiumRevokeOperationPrefix = "admin-premium-revoke:";
    private const string AdminPremiumRevokePending = "Pending";
    private const string AdminPremiumRevokeGatewayFailed = "GatewayFailed";
    private const string AdminPremiumRevokeEconomyApplied = "EconomyApplied";
    private const string AdminPremiumRevokeCompleted = "Completed";

    public async Task<Result<SubscriptionSummaryResponse>> CancelPremiumSubscriptionAsync(
        CancelPremiumSubscriptionCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var subscription = await dbContext.UserSubscriptions
            .Where(x => x.UserId == command.UserId && x.Provider == "stripe")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (subscription is null || string.IsNullOrWhiteSpace(subscription.ExternalSubscriptionId))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var stripeClient = CreateStripeClient(stripeApiKey);

        try
        {
            await CancelStripeSubscriptionAsync(
                stripeClient,
                subscription.ExternalSubscriptionId,
                cancellationToken);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Failed to request cancel_at_period_end for Stripe subscription. SubscriptionIdSafe={SubscriptionIdSafe} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId),
                SafeLogValues.ExceptionType(ex),
                CurrentCorrelationIdHash);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        subscription.CancelAtPeriodEnd = true;
        if (string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(subscription.Status, "GracePeriod", StringComparison.OrdinalIgnoreCase))
        {
            subscription.Status = "Canceled";
        }

        subscription.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        await AppendSubscriptionEventAsync(
            command.UserId,
            subscription.Id,
            "stripe",
            "CancelAtPeriodEndRequested",
            subscription.Status,
            null,
            subscription.ExternalSubscriptionId,
            null,
            cancellationToken);

        return await GetSubscriptionSummaryAsync(command.UserId, cancellationToken);
    }

    public async Task<Result<SubscriptionSummaryResponse>> AdminRevokePremiumSubscriptionAsync(
        AdminRevokePremiumSubscriptionCommand command,
        CancellationToken cancellationToken)
    {
        var reason = command.Reason?.Trim();
        if (string.IsNullOrWhiteSpace(reason) || reason.Length > 500)
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.AdminPremiumRevokeReasonRequired);
        }

        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var userSubscriptions = await dbContext.UserSubscriptions
            .Where(x => x.UserId == command.UserId)
            .ToListAsync(cancellationToken);
        var latestSubscription = SelectLatestUserSubscription(userSubscriptions);
        var existingOperations = await dbContext.SubscriptionEventLogs
            .Where(x => x.UserId == command.UserId
                && x.EventType == AdminPremiumRevokeEventType
                && x.ExternalEventId != null
                && x.ExternalEventId.StartsWith(AdminPremiumRevokeOperationPrefix))
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var latestSubscriptionIsCancellable =
            IsAdminCancellableStripeSubscription(latestSubscription);
        var latestSubscriptionId = latestSubscription?.Id;
        var resumableOperations = existingOperations
            .Where(x => !string.Equals(
                x.Status,
                AdminPremiumRevokeCompleted,
                StringComparison.Ordinal))
            .ToList();
        var operation = latestSubscriptionIsCancellable
            ? resumableOperations.FirstOrDefault(
                x => x.UserSubscriptionId == latestSubscriptionId)
            : resumableOperations.FirstOrDefault();
        if (!latestSubscriptionIsCancellable
            && operation is null
            && string.Equals(latestSubscription?.Status, "Expired", StringComparison.OrdinalIgnoreCase))
        {
            operation = existingOperations.FirstOrDefault(
                x => x.UserSubscriptionId == latestSubscriptionId
                    && string.Equals(
                        x.Status,
                        AdminPremiumRevokeCompleted,
                        StringComparison.Ordinal));
        }

        var subscription = latestSubscriptionIsCancellable
            ? latestSubscription
            : operation?.UserSubscriptionId is { } operationSubscriptionId
                ? userSubscriptions.FirstOrDefault(x => x.Id == operationSubscriptionId)
                : null;

        if (subscription is null
            || (!IsAdminCancellableStripeSubscription(subscription) && operation is null))
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.PremiumSubscriptionNotCancellable);
        }

        if (operation is null)
        {
            var attemptNumber = existingOperations.Count(
                x => x.UserSubscriptionId == subscription.Id) + 1;
            operation = await GetOrCreateAdminPremiumRevokeOperationAsync(
                subscription,
                reason,
                attemptNumber,
                cancellationToken);
        }

        if (operation is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.AdminPremiumRevokeFinalizationFailed);
        }

        return await ResumeAdminPremiumRevokeAsync(subscription, operation, cancellationToken);
    }

    private async Task<Result<SubscriptionSummaryResponse>> ResumeAdminPremiumRevokeAsync(
        UserSubscription subscription,
        SubscriptionEventLog operation,
        CancellationToken cancellationToken)
    {
        if (identityService is null || adminAuditLog is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var canonicalReason = GetAdminPremiumRevokePayloadValue(operation.PayloadJson, "reason")
            ?? "Administrative Premium revocation recovery.";
        var previousSubscriptionStatus = GetAdminPremiumRevokePayloadValue(
                operation.PayloadJson,
            "previousStatus")
            ?? subscription.Status;

        if (string.Equals(operation.Status, AdminPremiumRevokeCompleted, StringComparison.Ordinal)
            && string.Equals(subscription.Status, "Expired", StringComparison.OrdinalIgnoreCase))
        {
            return await GetSubscriptionSummaryAsync(subscription.UserId, cancellationToken);
        }

        var requestAuditWritten = await TryWriteAdminPremiumRevokeAuditAsync(
            operation,
            subscription,
            canonicalReason,
            previousSubscriptionStatus,
            "admin.subscription.revoke_requested",
            "requested",
            cancellationToken);
        if (!requestAuditWritten)
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.AdminPremiumRevokeFinalizationFailed);
        }

        var economyAlreadyApplied =
            string.Equals(operation.Status, AdminPremiumRevokeEconomyApplied, StringComparison.Ordinal)
            || string.Equals(operation.Status, AdminPremiumRevokeCompleted, StringComparison.Ordinal)
            || string.Equals(subscription.Status, "Expired", StringComparison.OrdinalIgnoreCase);
        if (!economyAlreadyApplied && !string.IsNullOrWhiteSpace(subscription.ExternalSubscriptionId))
        {
            var stripeApiKey = ResolveStripeApiKey();
            if (string.IsNullOrWhiteSpace(stripeApiKey))
            {
                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
            }

            var stripeClient = CreateStripeClient(stripeApiKey);

            try
            {
                if (!await CancelStripeSubscriptionWithReconciliationAsync(
                    stripeClient,
                    subscription.ExternalSubscriptionId,
                    cancellationToken))
                {
                    throw new InvalidOperationException(
                        "Stripe subscription did not reach a terminal state after cancellation.");
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                logger?.LogWarning(
                    "Failed to immediately cancel Stripe subscription for admin premium revoke. SubscriptionIdSafe={SubscriptionIdSafe} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                    EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId),
                    SafeLogValues.ExceptionType(ex),
                    CurrentCorrelationIdHash);

                await TryAdvanceAdminPremiumRevokeOperationAsync(
                    operation.Id,
                    AdminPremiumRevokeGatewayFailed,
                    canonicalReason,
                    previousSubscriptionStatus,
                    processed: false,
                    cancellationToken);
                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }

        if (!await ApplyAdminPremiumRevokeEconomyStateAsync(
                subscription.Id,
                operation.Id,
                canonicalReason,
                previousSubscriptionStatus,
                cancellationToken))
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.AdminPremiumRevokeFinalizationFailed);
        }

        var entitlementSubscription = await GetLatestUserSubscriptionAsync(
            subscription.UserId,
            cancellationToken);
        var desiredPremium = IsActivePremiumSubscription(entitlementSubscription);
        var premiumSyncResult = await SynchronizePremiumEntitlementAsync(
            subscription.UserId,
            desiredPremium,
            entitlementSubscription?.Provider ?? "stripe",
            AdminPremiumRevokeEventType,
            entitlementSubscription?.Id ?? subscription.Id,
            entitlementSubscription?.ExternalSubscriptionId,
            cancellationToken);
        if (premiumSyncResult.IsFailure)
        {
            return Result.Failure<SubscriptionSummaryResponse>(premiumSyncResult.Error);
        }

        dbContext.ChangeTracker.Clear();
        operation = await dbContext.SubscriptionEventLogs
            .FirstAsync(x => x.Id == operation.Id, cancellationToken);
        subscription = await dbContext.UserSubscriptions
            .FirstAsync(x => x.Id == subscription.Id, cancellationToken);

        var completionAuditWritten = await TryWriteAdminPremiumRevokeAuditAsync(
            operation,
            subscription,
            canonicalReason,
            previousSubscriptionStatus,
            "admin.subscription.canceled",
            "completed",
            cancellationToken);
        if (!completionAuditWritten
            || !await TryAdvanceAdminPremiumRevokeOperationAsync(
                operation.Id,
                AdminPremiumRevokeCompleted,
                canonicalReason,
                previousSubscriptionStatus,
                processed: true,
                cancellationToken))
        {
            return Result.Failure<SubscriptionSummaryResponse>(
                EconomyErrors.AdminPremiumRevokeFinalizationFailed);
        }

        return await GetSubscriptionSummaryAsync(subscription.UserId, cancellationToken);
    }

    private async Task<SubscriptionEventLog?> GetOrCreateAdminPremiumRevokeOperationAsync(
        UserSubscription subscription,
        string reason,
        int attemptNumber,
        CancellationToken cancellationToken)
    {
        var operationId = CreateAdminPremiumRevokeOperationId(
            subscription.Id,
            attemptNumber);
        var existing = await dbContext.SubscriptionEventLogs
            .FirstOrDefaultAsync(x => x.Id == operationId, cancellationToken);
        if (existing is not null)
        {
            return IsAdminPremiumRevokeOperation(existing, subscription.Id) ? existing : null;
        }

        var now = DateTime.UtcNow;
        var operation = new SubscriptionEventLog
        {
            Id = operationId,
            UserId = subscription.UserId,
            UserSubscriptionId = subscription.Id,
            Provider = "stripe",
            EventType = AdminPremiumRevokeEventType,
            Status = AdminPremiumRevokePending,
            ExternalEventId = GetAdminPremiumRevokeOperationKey(
                subscription.Id,
                attemptNumber),
            ExternalSubscriptionId = subscription.ExternalSubscriptionId,
            PayloadJson = BuildAdminPremiumRevokePayload(
                reason,
                subscription.Status,
                AdminPremiumRevokePending),
            CreatedAtUtc = now
        };
        dbContext.SubscriptionEventLogs.Add(operation);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return operation;
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(operation).State = EntityState.Detached;
            existing = await dbContext.SubscriptionEventLogs
                .FirstOrDefaultAsync(x => x.Id == operationId, cancellationToken);
            return existing is not null && IsAdminPremiumRevokeOperation(existing, subscription.Id)
                ? existing
                : null;
        }
    }

    private async Task<bool> ApplyAdminPremiumRevokeEconomyStateAsync(
        Guid subscriptionId,
        Guid operationId,
        string reason,
        string previousStatus,
        CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 3; attempt++)
        {
            var subscription = await dbContext.UserSubscriptions
                .FirstOrDefaultAsync(x => x.Id == subscriptionId, cancellationToken);
            var operationStatus = await dbContext.SubscriptionEventLogs
                .AsNoTracking()
                .Where(x => x.Id == operationId)
                .Select(x => x.Status)
                .FirstOrDefaultAsync(cancellationToken);
            if (subscription is null || operationStatus is null)
            {
                return false;
            }

            if (string.Equals(
                    operationStatus,
                    AdminPremiumRevokeCompleted,
                    StringComparison.Ordinal)
                && string.Equals(subscription.Status, "Expired", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            var now = DateTime.UtcNow;
            subscription.CancelAtPeriodEnd = false;
            subscription.CancelledAtUtc ??= now;
            subscription.ExpiredAtUtc ??= now;
            subscription.Status = "Expired";
            if (subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc > now)
            {
                subscription.CurrentPeriodEndUtc = now;
            }

            subscription.UpdatedAtUtc = now;

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return await TryAdvanceAdminPremiumRevokeOperationAsync(
                    operationId,
                    AdminPremiumRevokeEconomyApplied,
                    reason,
                    previousStatus,
                    processed: false,
                    cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                dbContext.ChangeTracker.Clear();
            }
        }

        return false;
    }

    private async Task<bool> TryAdvanceAdminPremiumRevokeOperationAsync(
        Guid operationId,
        string status,
        string reason,
        string previousStatus,
        bool processed,
        CancellationToken cancellationToken)
    {
        var targetRank = GetAdminPremiumRevokeStatusRank(status);
        if (targetRank < 0)
        {
            return false;
        }

        for (var attempt = 0; attempt < 3; attempt++)
        {
            dbContext.ChangeTracker.Clear();
            var operation = await dbContext.SubscriptionEventLogs
                .FirstOrDefaultAsync(x => x.Id == operationId, cancellationToken);
            if (operation is null)
            {
                return false;
            }

            var currentRank = GetAdminPremiumRevokeStatusRank(operation.Status);
            if (currentRank < 0)
            {
                return false;
            }

            if (currentRank >= targetRank)
            {
                return true;
            }

            if (!IsAllowedAdminPremiumRevokeTransition(operation.Status, status))
            {
                return false;
            }

            operation.Status = status;
            operation.PayloadJson = BuildAdminPremiumRevokePayload(reason, previousStatus, status);
            if (processed)
            {
                operation.ProcessedAtUtc ??= DateTime.UtcNow;
            }

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return true;
            }
            catch (DbUpdateConcurrencyException)
            {
                dbContext.ChangeTracker.Clear();
            }
            catch (DbUpdateException ex)
            {
                logger?.LogWarning(
                    "Failed to persist admin Premium revoke operation state. OperationIdHash={OperationIdHash} Status={Status} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                    SafeLogValues.StableHash(operationId.ToString("D")),
                    status,
                    SafeLogValues.ExceptionType(ex),
                    CurrentCorrelationIdHash);
                dbContext.ChangeTracker.Clear();
                return false;
            }
        }

        return false;
    }

    private async Task<bool> TryWriteAdminPremiumRevokeAuditAsync(
        SubscriptionEventLog operation,
        UserSubscription subscription,
        string reason,
        string previousStatus,
        string action,
        string stage,
        CancellationToken cancellationToken)
    {
        try
        {
            await adminAuditLog!.WriteAsync(
                new AdminAuditEntry(
                    action,
                    "subscription",
                    subscription.Id.ToString("D"),
                    previousStatus,
                    stage == "completed" ? "Expired" : subscription.Status,
                    Details: BuildAdminPremiumRevokeAuditDetails(
                        reason,
                        operation.ExternalEventId),
                    SubjectUserId: subscription.UserId,
                    EventId: CreateAdminPremiumRevokeAuditEventId(operation.Id, stage)),
                cancellationToken);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Failed to persist admin Premium revoke audit. OperationIdHash={OperationIdHash} Stage={Stage} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                SafeLogValues.StableHash(operation.Id.ToString("D")),
                stage,
                SafeLogValues.ExceptionType(ex),
                CurrentCorrelationIdHash);
            return false;
        }
    }

    private static bool IsAdminPremiumRevokeOperation(
        SubscriptionEventLog operation,
        Guid subscriptionId)
    {
        return operation.UserSubscriptionId == subscriptionId
            && string.Equals(operation.Provider, "stripe", StringComparison.Ordinal)
            && string.Equals(operation.EventType, AdminPremiumRevokeEventType, StringComparison.Ordinal)
            && operation.ExternalEventId?.StartsWith(
                $"{AdminPremiumRevokeOperationPrefix}{subscriptionId:D}",
                StringComparison.Ordinal) == true;
    }

    private static string BuildAdminPremiumRevokePayload(
        string reason,
        string previousStatus,
        string stage)
    {
        return JsonSerializer.Serialize(new
        {
            reason = SafeLogValues.SanitizeText(reason, 500),
            previousStatus = SafeLogValues.SanitizeText(previousStatus, 32),
            stage = SafeLogValues.SanitizeText(stage, 32)
        });
    }

    private static string BuildAdminPremiumRevokeAuditDetails(
        string reason,
        string? operationKey)
    {
        return JsonSerializer.Serialize(new
        {
            reason = SafeLogValues.SanitizeText(reason, 500),
            provider = "stripe",
            operation = SafeLogValues.SanitizeText(operationKey, 160)
        });
    }

    private static string? GetAdminPremiumRevokePayloadValue(string? payloadJson, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(payloadJson))
        {
            return null;
        }

        try
        {
            using var payload = JsonDocument.Parse(payloadJson);
            return payload.RootElement.TryGetProperty(propertyName, out var value)
                && value.ValueKind == JsonValueKind.String
                ? value.GetString()
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string GetAdminPremiumRevokeOperationKey(
        Guid subscriptionId,
        int attemptNumber)
    {
        return $"{AdminPremiumRevokeOperationPrefix}{subscriptionId:D}:attempt:{attemptNumber}";
    }

    private static Guid CreateAdminPremiumRevokeOperationId(
        Guid subscriptionId,
        int attemptNumber)
    {
        return CreateAdminPremiumRevokeDeterministicId(
            GetAdminPremiumRevokeOperationKey(subscriptionId, attemptNumber));
    }

    private static Guid CreateAdminPremiumRevokeAuditEventId(Guid operationId, string stage)
    {
        return CreateAdminPremiumRevokeDeterministicId(
            $"{AdminPremiumRevokeOperationPrefix}{operationId:D}:audit:{stage}");
    }

    private static Guid CreateAdminPremiumRevokeDeterministicId(string value)
    {
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(value)).AsSpan(0, 16));
    }

    private static int GetAdminPremiumRevokeStatusRank(string status)
    {
        return status switch
        {
            AdminPremiumRevokePending => 0,
            AdminPremiumRevokeGatewayFailed => 1,
            AdminPremiumRevokeEconomyApplied => 2,
            AdminPremiumRevokeCompleted => 3,
            _ => -1
        };
    }

    private static bool IsAllowedAdminPremiumRevokeTransition(
        string currentStatus,
        string targetStatus)
    {
        return targetStatus switch
        {
            AdminPremiumRevokeGatewayFailed =>
                string.Equals(currentStatus, AdminPremiumRevokePending, StringComparison.Ordinal),
            AdminPremiumRevokeEconomyApplied =>
                string.Equals(currentStatus, AdminPremiumRevokePending, StringComparison.Ordinal)
                || string.Equals(
                    currentStatus,
                    AdminPremiumRevokeGatewayFailed,
                    StringComparison.Ordinal),
            AdminPremiumRevokeCompleted =>
                string.Equals(
                    currentStatus,
                    AdminPremiumRevokeEconomyApplied,
                    StringComparison.Ordinal),
            _ => false
        };
    }

    private static bool IsAdminCancellableStripeSubscription([NotNullWhen(true)] UserSubscription? subscription)
    {
        if (subscription is null
            || subscription.CancelAtPeriodEnd
            || !string.Equals(subscription.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return (string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
                || string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase))
            && IsActivePremiumSubscription(subscription);
    }

    private static Task<Subscription> CancelStripeSubscriptionAsync(
        IStripeClient stripeClient,
        string externalSubscriptionId,
        CancellationToken cancellationToken)
    {
        var subscriptionService = new SubscriptionService(stripeClient);
        return subscriptionService.UpdateAsync(
            externalSubscriptionId,
            new SubscriptionUpdateOptions
            {
                CancelAtPeriodEnd = true
            },
            cancellationToken: cancellationToken);
    }

    private static async Task<bool> CancelStripeSubscriptionWithReconciliationAsync(
        IStripeClient stripeClient,
        string externalSubscriptionId,
        CancellationToken cancellationToken)
    {
        var subscriptionService = new SubscriptionService(stripeClient);
        var current = await subscriptionService.GetAsync(
            externalSubscriptionId,
            cancellationToken: cancellationToken);
        if (IsStripeSubscriptionTerminated(current))
        {
            return true;
        }

        try
        {
            var canceled = await subscriptionService.CancelAsync(
                externalSubscriptionId,
                options: null,
                requestOptions: null,
                cancellationToken: cancellationToken);
            if (IsStripeSubscriptionTerminated(canceled))
            {
                return true;
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            try
            {
                var reconciledAfterFailure = await subscriptionService.GetAsync(
                    externalSubscriptionId,
                    cancellationToken: cancellationToken);
                if (IsStripeSubscriptionTerminated(reconciledAfterFailure))
                {
                    return true;
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception)
            {
                // Preserve the cancellation failure so the durable operation remains retryable.
            }

            throw;
        }

        var reconciled = await subscriptionService.GetAsync(
            externalSubscriptionId,
            cancellationToken: cancellationToken);
        return IsStripeSubscriptionTerminated(reconciled);
    }

    internal static bool IsStripeSubscriptionTerminated(Subscription subscription)
    {
        return string.Equals(subscription.Status, "canceled", StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                subscription.Status,
                "incomplete_expired",
                StringComparison.OrdinalIgnoreCase);
    }
}
