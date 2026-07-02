using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<Result> SynchronizePremiumEntitlementAsync(
        Guid userId,
        bool desiredPremium,
        string provider,
        string reason,
        Guid? subscriptionId,
        string? externalSubscriptionId,
        CancellationToken cancellationToken)
    {
        if (identityService is null)
        {
            await AppendPremiumEntitlementEventAsync(
                userId,
                subscriptionId,
                provider,
                "PremiumIdentitySyncFailed",
                desiredPremium ? "Active" : "Inactive",
                null,
                externalSubscriptionId,
                new
                {
                    reason,
                    desiredPremium,
                    errorCode = EconomyErrors.PremiumBillingUnavailable.Code
                },
                cancellationToken);

            return Result.Failure(EconomyErrors.PremiumBillingUnavailable);
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(userId, desiredPremium),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            await AppendPremiumEntitlementEventAsync(
                userId,
                subscriptionId,
                provider,
                "PremiumIdentitySyncFailed",
                desiredPremium ? "Active" : "Inactive",
                null,
                externalSubscriptionId,
                new
                {
                    reason,
                    desiredPremium,
                    errorCode = premiumResult.Error.Code
                },
                cancellationToken);

            return Result.Failure(premiumResult.Error);
        }

        logger?.LogInformation(
            "Premium entitlement synchronized from Economy to Identity. Provider={Provider} UserId={UserId} Reason={Reason} IsPremium={IsPremium} CorrelationId={CorrelationId}",
            provider,
            userId,
            reason,
            desiredPremium,
            CurrentCorrelationId);

        return Result.Success();
    }

    private async Task ReconcilePremiumEntitlementAsync(
        Guid userId,
        string reason,
        CancellationToken cancellationToken)
    {
        if (identityService is null)
        {
            return;
        }

        var subscription = await GetLatestUserSubscriptionAsync(userId, cancellationToken);
        var desiredPremium = IsActivePremiumSubscription(subscription);
        var identityProfile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        if (identityProfile.IsFailure)
        {
            await AppendPremiumEntitlementEventAsync(
                userId,
                subscription?.Id,
                subscription?.Provider ?? "economy",
                "PremiumReconciliationIncident",
                desiredPremium ? "Active" : "Inactive",
                null,
                subscription?.ExternalSubscriptionId,
                new
                {
                    reason,
                    desiredPremium,
                    errorCode = identityProfile.Error.Code
                },
                cancellationToken);
            return;
        }

        var identityPremium = identityProfile.Value.IsPremium;
        if (identityPremium == desiredPremium)
        {
            return;
        }

        var syncResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(userId, desiredPremium),
            cancellationToken);
        if (syncResult.IsFailure)
        {
            await AppendPremiumEntitlementEventAsync(
                userId,
                subscription?.Id,
                subscription?.Provider ?? "economy",
                "PremiumReconciliationIncident",
                desiredPremium ? "Active" : "Inactive",
                null,
                subscription?.ExternalSubscriptionId,
                new
                {
                    reason,
                    desiredPremium,
                    identityPremium,
                    errorCode = syncResult.Error.Code
                },
                cancellationToken);
            return;
        }

        await AppendPremiumEntitlementEventAsync(
            userId,
            subscription?.Id,
            subscription?.Provider ?? "economy",
            "PremiumReconciliationFixed",
            desiredPremium ? "Active" : "Inactive",
            null,
            subscription?.ExternalSubscriptionId,
            new
            {
                reason,
                desiredPremium,
                previousIdentityPremium = identityPremium
            },
            cancellationToken);

        logger?.LogWarning(
            "Premium entitlement mismatch reconciled. Provider={Provider} UserId={UserId} Reason={Reason} IdentityPremium={IdentityPremium} EconomyPremium={EconomyPremium} CorrelationId={CorrelationId}",
            subscription?.Provider ?? "economy",
            userId,
            reason,
            identityPremium,
            desiredPremium,
            CurrentCorrelationId);
    }

    private async Task AppendPremiumEntitlementEventAsync(
        Guid userId,
        Guid? subscriptionId,
        string provider,
        string eventType,
        string status,
        string? externalEventId,
        string? externalSubscriptionId,
        object? payload,
        CancellationToken cancellationToken)
    {
        var eventLog = new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscriptionId,
            Provider = provider,
            EventType = eventType,
            Status = status,
            ExternalEventId = externalEventId,
            ExternalSubscriptionId = externalSubscriptionId,
            PayloadJson = payload is null ? null : JsonSerializer.Serialize(payload),
            CreatedAtUtc = DateTime.UtcNow,
            ProcessedAtUtc = DateTime.UtcNow
        };

        dbContext.SubscriptionEventLogs.Add(eventLog);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex)
        {
            logger?.LogWarning(
                ex,
                "Failed to write premium entitlement audit event. Provider={Provider} UserId={UserId} EventType={EventType} CorrelationId={CorrelationId}",
                provider,
                userId,
                eventType,
                CurrentCorrelationId);

            dbContext.Entry(eventLog).State = EntityState.Detached;
        }
    }
}
