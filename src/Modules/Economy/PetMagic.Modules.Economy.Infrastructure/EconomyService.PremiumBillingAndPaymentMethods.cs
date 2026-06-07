using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Contracts;

using Stripe;
namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<PremiumCheckoutResponse>> CreatePremiumCheckoutAsync(
        CreatePremiumCheckoutCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var providerConfig = await ResolveEnabledPaymentProviderConfigAsync(
            provider,
            command.Platform,
            command.Country,
            command.AppVersion,
            cancellationToken);

        if (providerConfig is null)
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var stripeApiKey = ResolveStripeApiKey(providerConfig.Mode);
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var usePaymentSheet = string.Equals(command.Platform, "android", StringComparison.OrdinalIgnoreCase)
            || string.Equals(command.Platform, "ios", StringComparison.OrdinalIgnoreCase);
        string? stripePublishableKey = null;
        if (usePaymentSheet)
        {
            stripePublishableKey = ResolveStripePublishableKey(providerConfig.Mode);
            if (string.IsNullOrWhiteSpace(stripePublishableKey))
            {
                return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
            }
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(command.PlanCode, cancellationToken);
        if (plan is null)
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var customer = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, providerConfig.Mode, cancellationToken);
        if (customer.IsFailure)
        {
            return Result.Failure<PremiumCheckoutResponse>(customer.Error);
        }

        var checkout = await paymentGateway.CreateSubscriptionCheckoutAsync(
            new SubscriptionCheckoutCreateRequest(
                provider,
                command.UserId,
                customer.Value.ExternalCustomerId,
                plan.PlanCode,
                plan.ProductName,
                plan.PriceAmount,
                plan.CurrencyCode,
                plan.BillingInterval,
                stripeApiKey,
                stripePublishableKey,
                usePaymentSheet,
                plan.StripePriceId),
            cancellationToken);

        if (checkout.IsFailure)
        {
            return Result.Failure<PremiumCheckoutResponse>(checkout.Error);
        }

        if (usePaymentSheet
            && string.IsNullOrWhiteSpace(checkout.Value.PaymentIntentClientSecret))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        return Result.Success(new PremiumCheckoutResponse(
            provider,
            checkout.Value.CheckoutUrl,
            "pending",
            checkout.Value.ExternalCheckoutId,
            checkout.Value.PaymentIntentClientSecret,
            checkout.Value.CustomerId,
            checkout.Value.CustomerEphemeralKeySecret,
            checkout.Value.PublishableKey));
    }

    public async Task<Result<BillingPortalSessionResponse>> CreatePremiumBillingPortalAsync(
        CreatePremiumBillingPortalCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var customer = await dbContext.PaymentCustomers
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == command.UserId && x.Provider == provider, cancellationToken);

        if (customer is null)
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var portal = await paymentGateway.CreateBillingPortalSessionAsync(
            new BillingPortalCreateRequest(provider, command.UserId, customer.ExternalCustomerId, stripeApiKey),
            cancellationToken);

        if (portal.IsFailure)
        {
            return Result.Failure<BillingPortalSessionResponse>(portal.Error);
        }

        return Result.Success(new BillingPortalSessionResponse(provider, portal.Value.PortalUrl));
    }

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

        StripeConfiguration.ApiKey = stripeApiKey;

        try
        {
            await CancelStripeSubscriptionAsync(
                subscription.ExternalSubscriptionId,
                cancelImmediately: false,
                cancellationToken);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Failed to request cancel_at_period_end for Stripe subscription {SubscriptionId}. CorrelationId={CorrelationId}",
                subscription.ExternalSubscriptionId,
                CurrentCorrelationId);

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
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (identityService is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var subscription = await dbContext.UserSubscriptions
            .Where(x => x.UserId == command.UserId && x.Provider == "stripe")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (subscription is not null && !string.IsNullOrWhiteSpace(subscription.ExternalSubscriptionId))
        {
            var stripeApiKey = ResolveStripeApiKey();
            if (string.IsNullOrWhiteSpace(stripeApiKey))
            {
                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
            }

            StripeConfiguration.ApiKey = stripeApiKey;

            try
            {
                await CancelStripeSubscriptionAsync(
                    subscription.ExternalSubscriptionId,
                    cancelImmediately: true,
                    cancellationToken);
            }
            catch (Exception ex)
            {
                logger?.LogWarning(
                    ex,
                    "Failed to immediately cancel Stripe subscription {SubscriptionId} for admin premium revoke. CorrelationId={CorrelationId}",
                    subscription.ExternalSubscriptionId,
                    CurrentCorrelationId);

                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
            }

            subscription.CancelAtPeriodEnd = false;
            subscription.Status = "Expired";
            if (subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc > DateTime.UtcNow)
            {
                subscription.CurrentPeriodEndUtc = DateTime.UtcNow;
            }

            subscription.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            await AppendSubscriptionEventAsync(
                command.UserId,
                subscription.Id,
                "stripe",
                "AdminImmediateCancelRequested",
                subscription.Status,
                null,
                subscription.ExternalSubscriptionId,
                null,
                cancellationToken);

            if (adminAuditLog is not null)
            {
                await adminAuditLog.WriteAsync(
                    new AdminAuditEntry(
                        "admin.subscription.cancelled",
                        "subscription",
                        subscription.Id.ToString("D"),
                        "active",
                        subscription.Status,
                        SubjectUserId: command.UserId),
                    cancellationToken);
            }
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(command.UserId, false),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<SubscriptionSummaryResponse>(premiumResult.Error);
        }

        return await GetSubscriptionSummaryAsync(command.UserId, cancellationToken);
    }

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

        var userSubscription = await UpsertUserSubscriptionAsync(
            command.UserId,
            provider,
            "in_app",
            string.Empty,
            plan.PlanCode,
            "Pending",
            null,
            externalSubscriptionId,
            string.Equals(provider, "google_play", StringComparison.Ordinal) ? command.ServerVerificationData : command.PurchaseId,
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
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new PremiumStoreVerificationResponse(
            provider,
            command.ProductId,
            false,
            verification.Value.ExpiresAtUtc,
            "pending_webhook"));
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

        StripeConfiguration.ApiKey = stripeApiKey;

        Subscription stripeSubscription;
        try
        {
            stripeSubscription = await new SubscriptionService().GetAsync(
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
                normalizedSubscriptionId,
                command.UserId,
                CurrentCorrelationId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (!string.Equals(stripeSubscription.CustomerId, customer.ExternalCustomerId, StringComparison.Ordinal))
        {
            logger?.LogWarning(
                "Stripe subscription {SubscriptionId} belongs to customer {CustomerId}, but user {UserId} is linked to {ExpectedCustomerId}. CorrelationId={CorrelationId}",
                normalizedSubscriptionId,
                stripeSubscription.CustomerId,
                command.UserId,
                customer.ExternalCustomerId,
                CurrentCorrelationId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var mappedStatus = MapStripeSubscriptionStatusForVerification(stripeSubscription.Status);
        var currentPeriodStartUtc = NormalizeStripeUtcDateTime(stripeSubscription.StartDate);
        var currentPeriodEndUtc = ResolveStripeCurrentPeriodEndUtc(stripeSubscription);
        var isPremium = string.Equals(mappedStatus, "Active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(mappedStatus, "Trialing", StringComparison.OrdinalIgnoreCase)
            || (string.Equals(mappedStatus, "Canceled", StringComparison.OrdinalIgnoreCase)
            && currentPeriodEndUtc.HasValue
            && currentPeriodEndUtc.Value >= DateTime.UtcNow);

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

    private static DateTime? NormalizeStripeUtcDateTime(DateTime? value)
    {
        if (!value.HasValue)
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

    private static DateTime? ResolveStripeCurrentPeriodEndUtc(Subscription subscription)
    {
        return NormalizeStripeUtcDateTime(subscription.TrialEnd)
            ?? NormalizeStripeUtcDateTime(subscription.CancelAt)
            ?? NormalizeStripeUtcDateTime(subscription.EndedAt);
    }

    private static Task<Subscription> CancelStripeSubscriptionAsync(
        string externalSubscriptionId,
        bool cancelImmediately,
        CancellationToken cancellationToken)
    {
        var subscriptionService = new SubscriptionService();
        if (cancelImmediately)
        {
            return subscriptionService.CancelAsync(
                externalSubscriptionId,
                cancellationToken: cancellationToken);
        }

        return subscriptionService.UpdateAsync(
            externalSubscriptionId,
            new SubscriptionUpdateOptions
            {
                CancelAtPeriodEnd = true
            },
            cancellationToken: cancellationToken);
    }

    public async Task<Result<PaymentMethodSetupResponse>> CreatePaymentMethodSetupAsync(
        CreatePaymentMethodSetupCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PaymentMethodSetupResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PaymentMethodSetupResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var customerResult = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, null, cancellationToken);
        if (customerResult.IsFailure)
        {
            return Result.Failure<PaymentMethodSetupResponse>(customerResult.Error);
        }

        var setupResult = await paymentGateway.CreatePaymentMethodSetupAsync(
            new PaymentMethodSetupCreateRequest(provider, command.UserId, customerResult.Value.ExternalCustomerId, stripeApiKey),
            cancellationToken);

        if (setupResult.IsFailure)
        {
            return Result.Failure<PaymentMethodSetupResponse>(setupResult.Error);
        }

        return Result.Success(new PaymentMethodSetupResponse(
            provider,
            setupResult.Value.ExternalSetupId,
            setupResult.Value.CheckoutUrl));
    }

    public async Task<Result> RemovePaymentMethodAsync(RemovePaymentMethodCommand command, CancellationToken cancellationToken)
    {
        var method = await dbContext.SavedPaymentMethods
            .FirstOrDefaultAsync(x => x.Id == command.PaymentMethodId && x.UserId == command.UserId && x.IsActive, cancellationToken);

        if (method is null)
        {
            return Result.Failure(EconomyErrors.PaymentMethodNotFound);
        }

        var detachResult = await paymentGateway.DetachPaymentMethodAsync(
            new PaymentMethodDetachRequest(method.Provider, method.ExternalPaymentMethodId),
            cancellationToken);

        if (detachResult.IsFailure)
        {
            return Result.Failure(detachResult.Error);
        }

        method.IsActive = false;
        method.IsDefault = false;
        method.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }


}
