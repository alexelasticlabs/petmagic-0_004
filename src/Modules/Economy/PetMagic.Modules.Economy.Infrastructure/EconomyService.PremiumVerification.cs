using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Contracts;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<PremiumStoreVerificationResponse>> VerifyPremiumStorePurchaseAsync(
        VerifyPremiumStorePurchaseCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "google_play", StringComparison.Ordinal)
            && !string.Equals(provider, "app_store", StringComparison.Ordinal))
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(command.PlanCode, cancellationToken);
        if (plan is null)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var expectedProductId = string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? plan.GoogleProductId
            : plan.AppleProductId;

        if (!string.Equals(expectedProductId, command.ProductId.Trim(), StringComparison.Ordinal))
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var verification = await storeSubscriptionVerifier.VerifyAsync(
            new StoreSubscriptionVerificationRequest(
                command.UserId,
                provider,
                command.PlanCode,
                command.ProductId,
                command.ServerVerificationData,
                command.LocalVerificationData,
                command.PurchaseId,
                command.TransactionDate),
            cancellationToken);

        if (verification.IsFailure)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(verification.Error);
        }

        if (!verification.Value.IsActive)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.StorePurchaseInactive);
        }

        if (!verification.Value.ExpiresAtUtc.HasValue)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var externalSubscriptionId = verification.Value.ExternalSubscriptionId;
        if (string.Equals(provider, "google_play", StringComparison.Ordinal))
        {
            var existingGoogleSubscription = await dbContext.UserSubscriptions
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == command.UserId && x.Provider == provider && x.PlanId == plan.PlanCode,
                    cancellationToken);

            externalSubscriptionId = existingGoogleSubscription?.ExternalSubscriptionId ?? verification.Value.ExternalSubscriptionId;
        }

        var mappedStatus = EconomyWebhookParser.MapStoreSubscriptionStatus(verification.Value.Status, verification.Value.IsActive);
        var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(mappedStatus, verification.Value.ExpiresAtUtc);
        var externalTransactionId = string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? command.ServerVerificationData
            : command.PurchaseId;

        if (await StoreSubscriptionBelongsToAnotherUserAsync(
                command.UserId,
                provider,
                externalSubscriptionId,
                externalTransactionId,
                cancellationToken))
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        if (identityService is null)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(command.UserId, isPremium),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(premiumResult.Error);
        }

        var userSubscription = await UpsertUserSubscriptionAsync(
            command.UserId,
            provider,
            "in_app",
            string.Empty,
            plan.PlanCode,
            mappedStatus,
            null,
            externalSubscriptionId,
            externalTransactionId,
            DeriveCurrentPeriodStartUtc(plan.BillingPeriod, verification.Value.ExpiresAtUtc, DateTime.UtcNow),
            verification.Value.ExpiresAtUtc,
            false,
            plan.MonthlyTokenLimit,
            cancellationToken);

        await AppendSubscriptionEventAsync(
            command.UserId,
            userSubscription.Id,
            provider,
            "ReceiptVerified",
            userSubscription.Status,
            command.PurchaseId,
            verification.Value.ExternalSubscriptionId,
            null,
            cancellationToken);

        logger?.LogInformation(
            "Store subscription validation succeeded. Provider={Provider} UserId={UserId} ProductId={ProductId} PlanId={PlanId} Status={Status} IsPremium={IsPremium} Environment={Environment} CorrelationId={CorrelationId}",
            provider,
            command.UserId,
            command.ProductId,
            plan.PlanCode,
            mappedStatus,
            isPremium,
            provider == "google_play" ? options.Value.GooglePlayEnvironment : options.Value.AppStoreEnvironment,
            CurrentCorrelationId);

        if (isPremium)
        {
            await GrantPremiumSubscriptionAllowanceIfDueAsync(
                userSubscription,
                provider,
                cancellationToken);

            await SettlePendingReferralBonusAsync(
                command.UserId,
                $"premium:{provider}:{userSubscription.PlanId}",
                DateTime.UtcNow,
                cancellationToken);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new PremiumStoreVerificationResponse(
            provider,
            command.ProductId,
            isPremium,
            verification.Value.ExpiresAtUtc,
            mappedStatus));
    }

    public async Task<Result<SubscriptionSummaryResponse>> VerifyPremiumStripeSubscriptionAsync(
        VerifyPremiumStripeSubscriptionCommand command,
        CancellationToken cancellationToken)
    {
        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var normalizedPlanCode = command.PlanCode.Trim().ToLowerInvariant();
        var normalizedSubscriptionId = command.ExternalSubscriptionId.Trim();

        var plan = await ResolveConfiguredPremiumPlanAsync(normalizedPlanCode, cancellationToken);
        if (plan is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var customer = await dbContext.PaymentCustomers
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == command.UserId && x.Provider == "stripe",
                cancellationToken);

        if (customer is null || string.IsNullOrWhiteSpace(customer.ExternalCustomerId))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var stripeClient = CreateStripeClient(stripeApiKey);

        Subscription stripeSubscription;
        try
        {
            stripeSubscription = await new SubscriptionService(stripeClient).GetAsync(
                normalizedSubscriptionId,
                new SubscriptionGetOptions
                {
                    Expand = ["items.data.price"]
                },
                cancellationToken: cancellationToken);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Failed to verify Stripe subscription {SubscriptionId} for user {UserId}. CorrelationId={CorrelationId}",
                EconomyLogSanitizer.SafeExternalId(normalizedSubscriptionId),
                command.UserId,
                CurrentCorrelationId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (!string.Equals(stripeSubscription.CustomerId, customer.ExternalCustomerId, StringComparison.Ordinal))
        {
            logger?.LogWarning(
                "Stripe subscription {SubscriptionId} belongs to customer {CustomerId}, but user {UserId} is linked to {ExpectedCustomerId}. CorrelationId={CorrelationId}",
                EconomyLogSanitizer.SafeExternalId(normalizedSubscriptionId),
                EconomyLogSanitizer.SafeExternalId(stripeSubscription.CustomerId),
                command.UserId,
                EconomyLogSanitizer.SafeExternalId(customer.ExternalCustomerId),
                CurrentCorrelationId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var mappedStatus = MapStripeSubscriptionStatusForVerification(stripeSubscription.Status);
        var periodBounds = ResolveStripeCurrentPeriodBounds(stripeSubscription);
        var currentPeriodStartUtc = periodBounds.CurrentPeriodStartUtc;
        var currentPeriodEndUtc = periodBounds.CurrentPeriodEndUtc;
        if (!IsStripeSubscriptionForPlan(
                stripeSubscription,
                plan.StripePriceId,
                plan.CurrencyCode,
                plan.PriceAmount,
                plan.BillingInterval))
        {
            logger?.LogWarning(
                "Stripe subscription {SubscriptionId} did not match expected plan {PlanCode} for user {UserId}. ExpectedPriceId={ExpectedPriceId} ExpectedCurrency={ExpectedCurrency} ExpectedInterval={ExpectedInterval} CorrelationId={CorrelationId}",
                EconomyLogSanitizer.SafeExternalId(normalizedSubscriptionId),
                plan.PlanCode,
                command.UserId,
                EconomyLogSanitizer.SafeExternalId(plan.StripePriceId),
                plan.CurrencyCode,
                plan.BillingInterval,
                CurrentCorrelationId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var isPremium = ShouldStripeSubscriptionRemainPremium(
            stripeSubscription.Status,
            currentPeriodEndUtc,
            stripeSubscription.CancelAtPeriodEnd);

        if (identityService is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(command.UserId, isPremium),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<SubscriptionSummaryResponse>(premiumResult.Error);
        }

        var subscription = await UpsertUserSubscriptionAsync(
            command.UserId,
            "stripe",
            "mobile",
            string.Empty,
            plan.PlanCode,
            mappedStatus,
            customer.ExternalCustomerId,
            stripeSubscription.Id,
            null,
            currentPeriodStartUtc ?? DeriveCurrentPeriodStartUtc(plan.BillingPeriod, currentPeriodEndUtc, DateTime.UtcNow),
            currentPeriodEndUtc,
            stripeSubscription.CancelAtPeriodEnd,
            plan.MonthlyTokenLimit,
            cancellationToken);

        await AppendSubscriptionEventAsync(
            command.UserId,
            subscription.Id,
            "stripe",
            "ManualStripeVerification",
            mappedStatus,
            null,
            stripeSubscription.Id,
            null,
            cancellationToken);

        if (isPremium)
        {
            await GrantPremiumSubscriptionAllowanceIfDueAsync(
                subscription,
                "stripe",
                cancellationToken);

            await SettlePendingReferralBonusAsync(
                command.UserId,
                $"premium:stripe:{subscription.PlanId}",
                DateTime.UtcNow,
                cancellationToken);
        }

        return await GetSubscriptionSummaryAsync(command.UserId, cancellationToken);
    }

    private static string MapStripeSubscriptionStatusForVerification(string? providerStatus)
    {
        return providerStatus?.Trim().ToLowerInvariant() switch
        {
            "trialing" => "Trialing",
            "active" => "Active",
            "past_due" => "PastDue",
            "unpaid" => "PastDue",
            "canceled" => "Canceled",
            "cancelled" => "Canceled",
            "incomplete" => "Pending",
            "incomplete_expired" => "Expired",
            "paused" => "Paused",
            _ => "Pending"
        };
    }

    internal static (DateTime? CurrentPeriodStartUtc, DateTime? CurrentPeriodEndUtc) ResolveStripeCurrentPeriodBounds(Subscription subscription)
    {
        var rawPeriodStartUtc = TryResolveStripeUnixTimestamp(subscription.RawJsonElement, "current_period_start");
        var rawPeriodEndUtc = TryResolveStripeUnixTimestamp(subscription.RawJsonElement, "current_period_end");
        var itemPeriodBounds = ResolveStripeItemPeriodBounds(subscription);

        return (
            rawPeriodStartUtc ?? itemPeriodBounds.CurrentPeriodStartUtc ?? NormalizeStripeUtcDateTime(subscription.StartDate),
            rawPeriodEndUtc ?? itemPeriodBounds.CurrentPeriodEndUtc ?? ResolveStripeCurrentPeriodEndUtcFallback(subscription));
    }

    internal static bool IsStripeSubscriptionForPlan(
        Subscription subscription,
        string? expectedStripePriceId,
        string expectedCurrencyCode,
        decimal expectedPriceAmount,
        string expectedBillingInterval)
    {
        var items = subscription.Items?.Data;
        if (items is null || items.Count == 0)
        {
            return false;
        }

        var normalizedExpectedPriceId = NullIfWhiteSpace(expectedStripePriceId);
        var expectedMinorUnits = ToStripeMinorUnits(expectedPriceAmount);
        var normalizedExpectedCurrency = expectedCurrencyCode.Trim();
        var normalizedExpectedInterval = expectedBillingInterval.Trim().ToLowerInvariant();

        foreach (var item in items)
        {
            if (item is null)
            {
                continue;
            }

            var resolvedPriceId = NullIfWhiteSpace(item.Price?.Id) ?? NullIfWhiteSpace(item.Plan?.Id);
            if (normalizedExpectedPriceId is not null)
            {
                if (string.Equals(resolvedPriceId, normalizedExpectedPriceId, StringComparison.Ordinal))
                {
                    return true;
                }

                continue;
            }

            var resolvedCurrency = item.Price?.Currency ?? item.Plan?.Currency;
            var resolvedUnitAmount = item.Price?.UnitAmount ?? item.Plan?.Amount;
            var resolvedInterval = item.Price?.Recurring?.Interval ?? item.Plan?.Interval;

            if (resolvedUnitAmount.HasValue
                && resolvedUnitAmount.Value == expectedMinorUnits
                && string.Equals(resolvedCurrency?.Trim(), normalizedExpectedCurrency, StringComparison.OrdinalIgnoreCase)
                && string.Equals(resolvedInterval?.Trim(), normalizedExpectedInterval, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static (DateTime? CurrentPeriodStartUtc, DateTime? CurrentPeriodEndUtc) ResolveStripeItemPeriodBounds(Subscription subscription)
    {
        var items = subscription.Items?.Data;
        if (items is null || items.Count == 0)
        {
            return (null, null);
        }

        var resolvedStartUtc = items
            .Select(x => NormalizeStripeUtcDateTime(x?.CurrentPeriodStart))
            .FirstOrDefault(x => x.HasValue);
        var resolvedEndUtc = items
            .Select(x => NormalizeStripeUtcDateTime(x?.CurrentPeriodEnd))
            .FirstOrDefault(x => x.HasValue);

        return (resolvedStartUtc, resolvedEndUtc);
    }

    private static DateTime? NormalizeStripeUtcDateTime(DateTime? value)
    {
        if (!value.HasValue || value.Value == default)
        {
            return null;
        }

        return value.Value.Kind switch
        {
            DateTimeKind.Utc => value.Value,
            DateTimeKind.Local => value.Value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value.Value, DateTimeKind.Utc)
        };
    }

    private static DateTime? ResolveStripeCurrentPeriodEndUtcFallback(Subscription subscription)
    {
        return NormalizeStripeUtcDateTime(subscription.TrialEnd)
            ?? NormalizeStripeUtcDateTime(subscription.CancelAt)
            ?? NormalizeStripeUtcDateTime(subscription.EndedAt);
    }

    private static DateTime? TryResolveStripeUnixTimestamp(JsonElement? rawJsonElement, string propertyName)
    {
        if (!rawJsonElement.HasValue)
        {
            return null;
        }

        var root = rawJsonElement.Value;
        if (root.ValueKind != JsonValueKind.Object
            || !root.TryGetProperty(propertyName, out var propertyValue))
        {
            return null;
        }

        if (propertyValue.ValueKind == JsonValueKind.Number
            && propertyValue.TryGetInt64(out var unixSeconds))
        {
            return DateTimeOffset.FromUnixTimeSeconds(unixSeconds).UtcDateTime;
        }

        if (propertyValue.ValueKind == JsonValueKind.String
            && long.TryParse(propertyValue.GetString(), out unixSeconds))
        {
            return DateTimeOffset.FromUnixTimeSeconds(unixSeconds).UtcDateTime;
        }

        return null;
    }
}
