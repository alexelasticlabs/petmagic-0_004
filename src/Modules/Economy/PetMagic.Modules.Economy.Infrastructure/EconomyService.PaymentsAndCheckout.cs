using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

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
    public async Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken)
    {
        var packEntities = await dbContext.CurrencyPacks
            .Where(x => x.IsActive)
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

        var packs = packEntities
            .Select(x => new CurrencyPackResponse(
                x.Id,
                x.Code,
                x.DisplayName,
                x.CurrencyCode,
                x.PriceAmount,
                x.GrantedSpark,
                x.BonusSpark,
                x.GrantedSpark + x.BonusSpark,
                ResolvePackStoreProductId(x, "google_play"),
                ResolvePackStoreProductId(x, "app_store")))
            .ToList();

        return Result.Success<IReadOnlyList<CurrencyPackResponse>>(packs);
    }

    public async Task<Result<WalletCheckoutConfigResponse>> GetWalletCheckoutConfigAsync(GetWalletCheckoutConfigQuery query, CancellationToken cancellationToken)
    {
        var packsResult = await ListPacksAsync(cancellationToken);
        if (packsResult.IsFailure)
        {
            return Result.Failure<WalletCheckoutConfigResponse>(packsResult.Error);
        }

        var region = EconomyPaymentProviderPolicy.NormalizeRegion(query.Country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(region);
        var targetCurrency = isEuRegion ? "EUR" : "USD";

        var filteredPacks = packsResult.Value
            .Where(x => string.Equals(x.CurrencyCode, targetCurrency, StringComparison.OrdinalIgnoreCase))
            .ToList();

        var availablePaymentMethods = await BuildAvailablePaymentMethodsAsync(
            new GetPaywallConfigQuery(query.Platform, query.AppVersion, query.Country, query.Locale),
            cancellationToken);

        return Result.Success(new WalletCheckoutConfigResponse(
            filteredPacks,
            availablePaymentMethods,
            availablePaymentMethods.Any(x => x.RequiresExternalWarning)));
    }

    public async Task<Result<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(CancellationToken cancellationToken)
    {
        var configuredPlans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DisplayOrder)
            .ToListAsync(cancellationToken);

        var stripeEnabled = HasAnyStripeSecretKey();
        if (configuredPlans.Count > 0)
        {
            var plans = configuredPlans
                .Select(x => new PremiumPlanResponse(
                    x.Id,
                    x.BillingPeriod == "yearly" ? "year" : "month",
                    x.PriceAmount,
                    x.BillingPeriod == "yearly" ? 149.99m : null,
                    x.CurrencyCode,
                    x.MonthlyTokenLimit,
                    x.IsRecommended,
                    x.BillingPeriod == "yearly" ? 33 : null,
                    x.DisplayOrder,
                    stripeEnabled,
                    x.GoogleProductId,
                    x.AppleProductId))
                .ToList();

            return Result.Success<IReadOnlyList<PremiumPlanResponse>>(plans);
        }

        var catalogPlans = PremiumPlanCatalog.All
            .OrderBy(x => x.SortOrder)
            .Select(x => new PremiumPlanResponse(
                x.PlanCode,
                x.BillingInterval,
                x.PriceAmount,
                x.CompareAtPriceAmount,
                x.CurrencyCode,
                x.TokenAllowance,
                x.IsPopular,
                x.DiscountPercent,
                x.SortOrder,
                stripeEnabled,
                x.GooglePlayProductId,
                x.AppStoreProductId))
            .ToList();

        return Result.Success<IReadOnlyList<PremiumPlanResponse>>(catalogPlans);
    }

    public async Task<Result<PaywallConfigResponse>> GetPaywallConfigAsync(GetPaywallConfigQuery query, CancellationToken cancellationToken)
    {
        var plans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DisplayOrder)
            .Select(x => new PaywallPlanResponse(
                x.Id,
                x.Name,
                x.BillingPeriod,
                x.PriceAmount,
                x.CurrencyCode,
                x.MonthlyTokenLimit,
                x.IsRecommended,
                x.IsActive,
                x.AppleProductId,
                x.GoogleProductId,
                x.StripePriceId,
                x.DisplayOrder,
                x.BillingPeriod == "yearly" ? decimal.Round(x.PriceAmount / 12m, 2, MidpointRounding.AwayFromZero) : null,
                x.BillingPeriod == "yearly" ? 33 : null))
            .ToListAsync(cancellationToken);

        var availablePaymentMethods = await BuildAvailablePaymentMethodsAsync(query, cancellationToken);
        var legalTexts = BuildPaywallLegalTexts();

        return Result.Success(new PaywallConfigResponse(
            plans,
            plans.FirstOrDefault(x => x.IsRecommended)?.PlanId,
            availablePaymentMethods,
            legalTexts,
            availablePaymentMethods.Any(x => x.RequiresExternalWarning)));
    }

    public async Task<Result<PremiumStatusResponse>> GetPremiumStatusAsync(Guid userId, CancellationToken cancellationToken)
    {
        var summary = await GetSubscriptionSummaryAsync(userId, cancellationToken);
        if (summary.IsFailure)
        {
            return Result.Failure<PremiumStatusResponse>(summary.Error);
        }

        return Result.Success(new PremiumStatusResponse(
            summary.Value.IsPremium,
            summary.Value.CanManageSubscription,
            summary.Value.Provider));
    }

    public async Task<Result<SubscriptionSummaryResponse>> GetSubscriptionSummaryAsync(Guid userId, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
        var subscription = await GetLatestUserSubscriptionAsync(userId, cancellationToken);

        var profileIsPremium = false;
        if (identityService is not null)
        {
            var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
            if (profile.IsFailure)
            {
                return Result.Failure<SubscriptionSummaryResponse>(profile.Error);
            }

            profileIsPremium = profile.Value.IsPremium;
        }

        SubscriptionPlan? plan = null;
        if (!string.IsNullOrWhiteSpace(subscription?.PlanId))
        {
            plan = await dbContext.SubscriptionPlans
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == subscription.PlanId, cancellationToken);
        }

        var isPremium = IsActivePremiumSubscription(subscription) || profileIsPremium;
        var manageAction = GetManageSubscriptionAction(subscription?.Provider);

        string? cardBrand = null;
        string? cardLast4 = null;
        if (string.Equals(subscription?.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            var savedCard = await dbContext.SavedPaymentMethods
                .AsNoTracking()
                .Where(x => x.UserId == userId && x.Provider == "stripe" && x.IsActive)
                .OrderByDescending(x => x.IsDefault)
                .ThenByDescending(x => x.UpdatedAtUtc)
                .Select(x => new { x.Brand, x.Last4 })
                .FirstOrDefaultAsync(cancellationToken);
            cardBrand = savedCard?.Brand;
            cardLast4 = savedCard?.Last4;
        }

        return Result.Success(new SubscriptionSummaryResponse(
            isPremium,
            subscription?.Provider,
            subscription?.PurchaseChannel,
            subscription?.Status ?? (isPremium ? "Active" : "None"),
            plan?.Name,
            plan?.BillingPeriod,
            subscription?.CurrentPeriodStartUtc,
            subscription?.CurrentPeriodEndUtc,
            subscription?.CancelAtPeriodEnd ?? false,
            subscription?.MonthlyTokenLimit ?? plan?.MonthlyTokenLimit ?? 0,
            wallet.Balance,
            !string.Equals(manageAction, "None", StringComparison.Ordinal),
            manageAction,
            subscription?.LastTokenGrantAtUtc,
            cardBrand,
            cardLast4,
            options.Value.WeeklyPremiumSpark));
    }

    public async Task<Result<StripeDiagnosticsResponse>> GetStripeDiagnosticsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var summaryResult = await GetSubscriptionSummaryAsync(userId, cancellationToken);
        if (summaryResult.IsFailure)
        {
            return Result.Failure<StripeDiagnosticsResponse>(summaryResult.Error);
        }

        var externalCustomerId = await dbContext.PaymentCustomers
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.Provider == "stripe")
            .Select(x => x.ExternalCustomerId)
            .FirstOrDefaultAsync(cancellationToken);

        var recentWebhookEvents = await dbContext.ProcessedWebhookEvents
            .AsNoTracking()
            .Where(x => x.Provider == "stripe")
            .OrderByDescending(x => x.ProcessedAtUtc)
            .Take(30)
            .Select(x => new StripeWebhookEventSnapshotResponse(
                x.EventId,
                x.EventType,
                x.ProcessedAtUtc))
            .ToListAsync(cancellationToken);

        var recentSubscriptionEvents = await dbContext.SubscriptionEventLogs
            .AsNoTracking()
            .Where(x => x.Provider == "stripe" && x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(20)
            .Select(x => new StripeSubscriptionEventSnapshotResponse(
                x.EventType,
                x.Status,
                x.ExternalEventId,
                x.ExternalSubscriptionId,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        var recentStripePurchases = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.PaymentProvider == "stripe")
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(20)
            .Select(x => new StripePurchaseSnapshotResponse(
                x.Id,
                x.Status,
                x.ExternalPaymentId,
                x.PriceAmount,
                x.CurrencyCode,
                x.CreatedAtUtc,
                x.ConfirmedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(new StripeDiagnosticsResponse(
            summaryResult.Value,
            externalCustomerId,
            recentWebhookEvents,
            recentSubscriptionEvents,
            recentStripePurchases,
            DateTime.UtcNow));
    }

    public async Task<Result<IReadOnlyList<PaymentMethodResponse>>> ListPaymentMethodsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var methods = await dbContext.SavedPaymentMethods
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.IsActive)
            .OrderByDescending(x => x.IsDefault)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .Select(x => new PaymentMethodResponse(
                x.Id,
                x.Provider,
                x.Brand,
                x.Last4,
                x.ExpMonth,
                x.ExpYear,
                x.IsDefault,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<PaymentMethodResponse>>(methods);
    }

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
                "Failed to request cancel_at_period_end for Stripe subscription {SubscriptionId}.",
                subscription.ExternalSubscriptionId);

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
                    "Failed to immediately cancel Stripe subscription {SubscriptionId} for admin premium revoke.",
                    subscription.ExternalSubscriptionId);

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
                "Failed to verify Stripe subscription {SubscriptionId} for user {UserId}.",
                normalizedSubscriptionId,
                command.UserId);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (!string.Equals(stripeSubscription.CustomerId, customer.ExternalCustomerId, StringComparison.Ordinal))
        {
            logger?.LogWarning(
                "Stripe subscription {SubscriptionId} belongs to customer {CustomerId}, but user {UserId} is linked to {ExpectedCustomerId}.",
                normalizedSubscriptionId,
                stripeSubscription.CustomerId,
                command.UserId,
                customer.ExternalCustomerId);

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

    public async Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetWalletLedgerAsync(
        Guid userId,
        int skip,
        int take,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 20, 100);

        var query = dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id);

        var items = await query
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new WalletLedgerItemResponse(
                x.Id,
                x.UserId,
                x.Delta,
                x.BalanceAfter,
                x.Source,
                x.Reason,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<PurchaseCheckoutResponse>> CreatePackPurchaseAsync(CreatePackPurchaseCommand command, CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        var isStripe = string.Equals(provider, "stripe", StringComparison.Ordinal);
        var isStoreProvider =
            string.Equals(provider, "google_play", StringComparison.Ordinal)
            || string.Equals(provider, "app_store", StringComparison.Ordinal);

        if (!isStripe && !isStoreProvider)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        PaymentProviderConfiguration? providerConfig = await ResolveEnabledPaymentProviderConfigAsync(
            provider,
            command.Platform,
            command.Country,
            command.AppVersion,
            cancellationToken);
        if (providerConfig is null)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        string? stripeApiKey = null;
        if (isStripe)
        {
            stripeApiKey = ResolveStripeApiKey(providerConfig.Mode);
            if (string.IsNullOrWhiteSpace(stripeApiKey))
            {
                return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
            }
        }

        var currencyCode = command.CurrencyCode.Trim().ToUpperInvariant();
        var pack = await dbContext.CurrencyPacks
            .FirstOrDefaultAsync(x => x.Id == command.PackId && x.IsActive && x.CurrencyCode == currencyCode, cancellationToken);

        if (pack is null)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        var order = new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            PackId = pack.Id,
            SavedPaymentMethodId = command.PaymentMethodId,
            PaymentProvider = provider,
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = pack.PriceAmount,
            CurrencyCode = pack.CurrencyCode,
            SparkToGrant = pack.GrantedSpark + pack.BonusSpark,
            CreatedAtUtc = DateTime.UtcNow
        };

        if (isStoreProvider)
        {
            order.CheckoutUrl = string.Empty;
            dbContext.PurchaseOrders.Add(order);
            await dbContext.SaveChangesAsync(cancellationToken);

            return Result.Success(new PurchaseCheckoutResponse(
                order.Id,
                order.UserId,
                order.PaymentProvider,
                order.ExternalPaymentId ?? string.Empty,
                string.Empty,
                null,
                null,
                null,
                null,
                order.Status,
                order.PriceAmount,
                order.CurrencyCode,
                order.SparkToGrant,
                order.CreatedAtUtc));
        }

        if (command.PaymentMethodId.HasValue)
        {
            var savedMethod = await dbContext.SavedPaymentMethods
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == command.PaymentMethodId.Value
                        && x.UserId == command.UserId
                        && x.Provider == provider
                        && x.IsActive,
                    cancellationToken);

            if (savedMethod is null)
            {
                return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentMethodNotFound);
            }

            var customer = await dbContext.PaymentCustomers
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.UserId == command.UserId && x.Provider == provider, cancellationToken);

            if (customer is null)
            {
                return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentMethodNotFound);
            }

            var savedPaymentResult = await paymentGateway.CreatePaymentWithSavedMethodAsync(
                new PaymentSavedMethodCreateRequest(
                    provider,
                    order.Id,
                    order.UserId,
                    order.PriceAmount,
                    order.CurrencyCode,
                    order.SparkToGrant,
                    pack.DisplayName,
                    customer.ExternalCustomerId,
                    savedMethod.ExternalPaymentMethodId,
                    stripeApiKey),
                cancellationToken);

            if (savedPaymentResult.IsFailure)
            {
                return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
            }

            order.ExternalPaymentId = savedPaymentResult.Value.ExternalPaymentId;
            order.CheckoutUrl = string.Empty;
            dbContext.PurchaseOrders.Add(order);

            var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
            if (confirmResult.IsFailure)
            {
                return Result.Failure<PurchaseCheckoutResponse>(confirmResult.Error);
            }

            return Result.Success(ToPurchaseCheckoutResponse(confirmResult.Value));
        }

        var usePaymentSheet = string.Equals(command.Platform, "android", StringComparison.OrdinalIgnoreCase)
            || string.Equals(command.Platform, "ios", StringComparison.OrdinalIgnoreCase);
        string? stripePublishableKey = null;
        string? orderCustomerId = null;

        if (usePaymentSheet)
        {
            stripePublishableKey = ResolveStripePublishableKey(providerConfig.Mode);
            if (string.IsNullOrWhiteSpace(stripePublishableKey))
            {
                return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
            }

            var customer = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, providerConfig.Mode, cancellationToken);
            if (customer.IsFailure)
            {
                return Result.Failure<PurchaseCheckoutResponse>(customer.Error);
            }

            orderCustomerId = customer.Value.ExternalCustomerId;
        }

        var paymentResult = await paymentGateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                provider,
                order.Id,
                order.UserId,
                order.PriceAmount,
                order.CurrencyCode,
                order.SparkToGrant,
                pack.DisplayName,
                stripeApiKey,
                stripePublishableKey,
                orderCustomerId,
                usePaymentSheet),
            cancellationToken);

        if (paymentResult.IsFailure)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (usePaymentSheet
            && string.IsNullOrWhiteSpace(paymentResult.Value.PaymentIntentClientSecret))
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.IsNullOrWhiteSpace(paymentResult.Value.CheckoutUrl)
            && string.IsNullOrWhiteSpace(paymentResult.Value.PaymentIntentClientSecret))
        {
            EmptyCheckoutUrlCounter.Add(
                1,
                new KeyValuePair<string, object?>("provider", provider),
                new KeyValuePair<string, object?>("platform", command.Platform),
                new KeyValuePair<string, object?>("currency", order.CurrencyCode));

            logger?.LogWarning(
                "Payment gateway returned empty checkout URL for wallet top-up. OrderId={OrderId} UserId={UserId} PackId={PackId} Provider={Provider} ExternalPaymentId={ExternalPaymentId}",
                order.Id,
                order.UserId,
                order.PackId,
                provider,
                paymentResult.Value.ExternalPaymentId);
        }

        order.ExternalPaymentId = paymentResult.Value.ExternalPaymentId;
        order.CheckoutUrl = paymentResult.Value.CheckoutUrl;

        dbContext.PurchaseOrders.Add(order);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new PurchaseCheckoutResponse(
            order.Id,
            order.UserId,
            order.PaymentProvider,
            order.ExternalPaymentId ?? string.Empty,
            order.CheckoutUrl ?? string.Empty,
            paymentResult.Value.PaymentIntentClientSecret,
            paymentResult.Value.CustomerId,
            paymentResult.Value.CustomerEphemeralKeySecret,
            paymentResult.Value.PublishableKey,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.CreatedAtUtc));
    }

    public async Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetPurchaseHistoryAsync(
        Guid userId,
        int skip,
        int take,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 20, 100);

        var items = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .Join(
                dbContext.CurrencyPacks.AsNoTracking(),
                order => order.PackId,
                pack => pack.Id,
                (order, pack) => new { order, pack })
            .OrderByDescending(x => x.order.CreatedAtUtc)
            .ThenByDescending(x => x.order.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new PurchaseHistoryItemResponse(
                x.order.Id,
                x.order.UserId,
                x.order.PackId,
                x.pack.Code,
                x.pack.DisplayName,
                x.order.PaymentProvider,
                x.order.Status,
                x.order.PriceAmount,
                x.order.CurrencyCode,
                x.order.SparkToGrant,
                x.order.ExternalPaymentId,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<PurchaseOrderResponse>> ConfirmPackPurchaseAsync(ConfirmPackPurchaseCommand command, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure)
        {
            return Result.Failure<PurchaseOrderResponse>(confirmResult.Error);
        }

        return Result.Success(ToPurchaseOrderResponse(confirmResult.Value));
    }

    public async Task<Result<PurchaseOrderResponse>> VerifyStripeCheckoutSessionAsync(VerifyStripeCheckoutSessionCommand command, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        var normalizedRequestedReference = command.StripeReferenceId?.Trim();
        var stripeReferenceId = !string.IsNullOrWhiteSpace(normalizedRequestedReference)
            ? normalizedRequestedReference
            : order.ExternalPaymentId;

        if (!string.IsNullOrWhiteSpace(normalizedRequestedReference)
            && !string.IsNullOrWhiteSpace(order.ExternalPaymentId)
            && !string.Equals(order.ExternalPaymentId, normalizedRequestedReference, StringComparison.Ordinal))
        {
            logger?.LogWarning(
                "Stripe reference mismatch for order verification. OrderId={OrderId} UserId={UserId} RequestedReference={RequestedReference} StoredReference={StoredReference}",
                order.Id,
                order.UserId,
                normalizedRequestedReference,
                order.ExternalPaymentId);

            stripeReferenceId = order.ExternalPaymentId;
        }

        if (string.IsNullOrWhiteSpace(stripeReferenceId))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return Result.Success(ToPurchaseOrderResponse(order));
        }

        var apiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        StripeConfiguration.ApiKey = apiKey;

        try
        {
            if (stripeReferenceId.StartsWith("cs_", StringComparison.OrdinalIgnoreCase))
            {
                var sessionService = new Stripe.Checkout.SessionService();
                var session = await sessionService.GetAsync(stripeReferenceId, cancellationToken: cancellationToken);

                if (!string.Equals(session.PaymentStatus, "paid", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(session.Status, "complete", StringComparison.OrdinalIgnoreCase))
                {
                    return Result.Success(ToPurchaseOrderResponse(order));
                }
            }
            else if (stripeReferenceId.StartsWith("pi_", StringComparison.OrdinalIgnoreCase))
            {
                var paymentIntentService = new PaymentIntentService();
                var paymentIntent = await paymentIntentService.GetAsync(stripeReferenceId, cancellationToken: cancellationToken);

                if (!string.Equals(paymentIntent.Status, "succeeded", StringComparison.OrdinalIgnoreCase))
                {
                    return Result.Success(ToPurchaseOrderResponse(order));
                }
            }
            else
            {
                return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }
        catch (Exception ex)
        {
            logger?.LogWarning(ex, "Stripe payment verification failed for reference {StripeReferenceId}", stripeReferenceId);
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.IsNullOrWhiteSpace(order.ExternalPaymentId))
        {
            order.ExternalPaymentId = stripeReferenceId;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        // For mobile PaymentSheet flows we can observe Stripe success before webhook delivery.
        // Settle immediately and keep webhook handling idempotent.
        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure
            && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(confirmResult.Error);
        }

        if (confirmResult.IsSuccess)
        {
            return Result.Success(ToPurchaseOrderResponse(confirmResult.Value));
        }

        var refreshedOrder = await dbContext.PurchaseOrders
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.Id && x.UserId == order.UserId, cancellationToken);

        if (refreshedOrder is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        return Result.Success(ToPurchaseOrderResponse(refreshedOrder));
    }

    public async Task<Result<PurchaseOrderResponse>> GetPurchaseAsync(Guid userId, Guid orderId, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == orderId && x.UserId == userId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        return Result.Success(ToPurchaseOrderResponse(order));
    }

    public async Task<Result<PurchaseOrderResponse>> VerifyPackStorePurchaseAsync(
        VerifyPackStorePurchaseCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "google_play", StringComparison.Ordinal)
            && !string.Equals(provider, "app_store", StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);
        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        if (!string.Equals(order.PaymentProvider, provider, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return Result.Success(ToPurchaseOrderResponse(order));
        }

        var pack = await dbContext.CurrencyPacks
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);
        if (pack is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        var expectedProductId = ResolvePackStoreProductId(pack, provider);
        if (!string.Equals(expectedProductId, command.ProductId.Trim(), StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var verification = await storeSubscriptionVerifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                command.UserId,
                provider,
                command.ProductId,
                command.ServerVerificationData,
                command.LocalVerificationData,
                command.PurchaseId,
                command.TransactionDate),
            cancellationToken);

        if (verification.IsFailure)
        {
            return Result.Failure<PurchaseOrderResponse>(verification.Error);
        }

        if (!verification.Value.IsPurchased)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        order.ExternalPaymentId = string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? command.ServerVerificationData
            : verification.Value.ExternalTransactionId
                ?? command.PurchaseId
                ?? order.ExternalPaymentId;
        await dbContext.SaveChangesAsync(cancellationToken);

        // Store purchase settlement is webhook-authoritative.
        return Result.Success(ToPurchaseOrderResponse(order));
    }

    private string ResolvePackStoreProductId(CurrencyPack pack, string provider)
    {
        var code = pack.Code.Trim();
        if (string.IsNullOrWhiteSpace(code))
        {
            return string.Empty;
        }

        // Keep backward compatibility: when code already looks like an IAP SKU, use it as-is.
        if (code.Contains('.', StringComparison.Ordinal))
        {
            return code.ToLowerInvariant();
        }

        var bundleId = options.Value.AppStoreBundleId?.Trim();
        if (string.IsNullOrWhiteSpace(bundleId))
        {
            bundleId = options.Value.GooglePlayPackageName?.Trim();
        }

        if (string.IsNullOrWhiteSpace(bundleId))
        {
            bundleId = "com.petmagic.app";
        }

        var normalizedProvider = provider.Trim().ToLowerInvariant() switch
        {
            "google_play" => "google",
            "app_store" => "apple",
            _ => "store"
        };

        return $"{bundleId}.tokens.{normalizedProvider}.{code.ToLowerInvariant()}";
    }
}
