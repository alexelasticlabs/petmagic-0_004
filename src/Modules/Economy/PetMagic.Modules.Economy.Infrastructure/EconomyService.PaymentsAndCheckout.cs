using System.Data;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken)
    {
        var packs = await dbContext.CurrencyPacks
            .Where(x => x.IsActive)
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .Select(x => new CurrencyPackResponse(
                x.Id,
                x.Code,
                x.DisplayName,
                x.CurrencyCode,
                x.PriceAmount,
                x.GrantedSpark,
                x.BonusSpark,
                x.GrantedSpark + x.BonusSpark))
            .ToListAsync(cancellationToken);

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

        return Result.Success(new SubscriptionSummaryResponse(
            isPremium,
            subscription?.Provider,
            subscription?.PurchaseChannel,
            subscription?.Status ?? (isPremium ? "Active" : "None"),
            plan?.Name,
            plan?.BillingPeriod,
            subscription?.CurrentPeriodEndUtc,
            subscription?.CancelAtPeriodEnd ?? false,
            subscription?.MonthlyTokenLimit ?? plan?.MonthlyTokenLimit ?? 0,
            wallet.Balance,
            !string.Equals(manageAction, "None", StringComparison.Ordinal),
            manageAction));
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
                stripeApiKey),
            cancellationToken);

        if (checkout.IsFailure)
        {
            return Result.Failure<PremiumCheckoutResponse>(checkout.Error);
        }

        return Result.Success(new PremiumCheckoutResponse(
            provider,
            checkout.Value.CheckoutUrl,
            "pending"));
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

        if (identityService is null)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.PremiumBillingUnavailable);
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

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(command.UserId, true),
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
            EconomyWebhookParser.MapStoreSubscriptionStatus(verification.Value.Status, verification.Value.IsActive),
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

        await SettlePendingReferralBonusAsync(command.UserId, $"premium:{provider}:{plan.PlanCode}", DateTime.UtcNow, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new PremiumStoreVerificationResponse(
            provider,
            command.ProductId,
            true,
            verification.Value.ExpiresAtUtc,
            verification.Value.Status));
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
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var providerConfig = await ResolveEnabledPaymentProviderConfigAsync(
            provider,
            command.Platform,
            command.Country,
            command.AppVersion,
            cancellationToken);

        if (providerConfig is null)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var stripeApiKey = ResolveStripeApiKey(providerConfig.Mode);
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
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

        var paymentResult = await paymentGateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                provider,
                order.Id,
                order.UserId,
                order.PriceAmount,
                order.CurrencyCode,
                order.SparkToGrant,
                pack.DisplayName,
                stripeApiKey),
            cancellationToken);

        if (paymentResult.IsFailure)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        order.ExternalPaymentId = paymentResult.Value.ExternalPaymentId;
        order.CheckoutUrl = paymentResult.Value.CheckoutUrl;

        dbContext.PurchaseOrders.Add(order);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(ToPurchaseCheckoutResponse(order));
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
                (order, pack) => new PurchaseHistoryItemResponse(
                    order.Id,
                    order.UserId,
                    order.PackId,
                    pack.Code,
                    pack.DisplayName,
                    order.PaymentProvider,
                    order.Status,
                    order.PriceAmount,
                    order.CurrencyCode,
                    order.SparkToGrant,
                    order.ExternalPaymentId,
                    order.CreatedAtUtc,
                    order.ConfirmedAtUtc))
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.OrderId)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
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
