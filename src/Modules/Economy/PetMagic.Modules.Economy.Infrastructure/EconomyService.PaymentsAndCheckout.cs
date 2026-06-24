using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
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
        const string cacheKey = "economy:currency_packs";
        if (memoryCache.TryGetValue(cacheKey, out IReadOnlyList<CurrencyPackResponse>? cached) && cached is not null)
        {
            return Result.Success(cached);
        }

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

        memoryCache.Set(cacheKey, (IReadOnlyList<CurrencyPackResponse>)packs, TimeSpan.FromMinutes(10));
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
        const string cacheKey = "economy:premium_plans";
        if (memoryCache.TryGetValue(cacheKey, out IReadOnlyList<PremiumPlanResponse>? cached) && cached is not null)
        {
            return Result.Success(cached);
        }

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

            memoryCache.Set(cacheKey, (IReadOnlyList<PremiumPlanResponse>)plans, TimeSpan.FromMinutes(10));
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

        memoryCache.Set(cacheKey, (IReadOnlyList<PremiumPlanResponse>)catalogPlans, TimeSpan.FromMinutes(10));
        return Result.Success<IReadOnlyList<PremiumPlanResponse>>(catalogPlans);
    }

    public async Task<Result<BillingProductsResponse>> ListBillingProductsAsync(CancellationToken cancellationToken)
    {
        var packs = await dbContext.CurrencyPacks
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

        var plans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DisplayOrder)
            .ToListAsync(cancellationToken);

        return Result.Success(new BillingProductsResponse(
            packs
                .Select(x => new BillingTokenPackProductResponse(
                    x.Id,
                    x.Code,
                    x.DisplayName,
                    x.GrantedSpark + x.BonusSpark,
                    ResolvePackStoreProductId(x, "google_play"),
                    ResolvePackStoreProductId(x, "app_store")))
                .ToList(),
            plans
                .Select(x => new BillingSubscriptionProductResponse(
                    x.Id,
                    x.Name,
                    x.BillingPeriod,
                    x.MonthlyTokenLimit,
                    x.GoogleProductId,
                    x.AppleProductId))
                .ToList()));
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

        SubscriptionPlan? plan = null;
        if (!string.IsNullOrWhiteSpace(subscription?.PlanId))
        {
            plan = await dbContext.SubscriptionPlans
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == subscription.PlanId, cancellationToken);
        }

        var isPremium = IsActivePremiumSubscription(subscription);
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
                x.CreatedAtUtc,
                x.SourceProvider,
                null))
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
                LogPaymentFailed(order, savedPaymentResult.Error, "saved_method.create");
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

        // The current Flutter app does not bundle Stripe PaymentSheet. Use hosted
        // Checkout for mobile too so the client always receives a checkout URL.
        var usePaymentSheet = false;
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
            LogPaymentFailed(order, paymentResult.Error, "payment.create");
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (usePaymentSheet
            && string.IsNullOrWhiteSpace(paymentResult.Value.PaymentIntentClientSecret))
        {
            order.ExternalPaymentId = paymentResult.Value.ExternalPaymentId;
            LogPaymentFailed(order, EconomyErrors.PaymentGatewayFailed, "payment_sheet.missing_client_secret");
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.IsNullOrWhiteSpace(paymentResult.Value.CheckoutUrl)
            && string.IsNullOrWhiteSpace(paymentResult.Value.PaymentIntentClientSecret))
        {
            EconomyMetrics.RecordEmptyCheckoutUrl(provider, command.Platform, order.CurrencyCode);

            logger?.LogWarning(
                "Payment gateway returned empty checkout URL for wallet top-up. OrderId={OrderId} UserId={UserId} PackId={PackId} Provider={Provider} HasExternalPaymentId={HasExternalPaymentId} CorrelationId={CorrelationId}",
                order.Id,
                order.UserId,
                order.PackId,
                provider,
                !string.IsNullOrWhiteSpace(paymentResult.Value.ExternalPaymentId),
                CurrentCorrelationId);
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

}
