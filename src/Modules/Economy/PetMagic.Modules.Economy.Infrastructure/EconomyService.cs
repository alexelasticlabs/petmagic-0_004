using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class EconomyService(
    EconomyDbContext dbContext,
    IPaymentGateway paymentGateway,
    IStoreSubscriptionVerifier storeSubscriptionVerifier,
    IOptions<EconomyOptions> options,
    IIdentityService? identityService = null) : IEconomyService
{
    public async Task<Result<WalletStateResponse>> GetWalletAsync(Guid userId, bool isPremium, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
        var resolvedPremium = await ResolvePremiumStatusAsync(userId, isPremium, cancellationToken);
        return Result.Success(ToWalletState(wallet, resolvedPremium));
    }

    public async Task<Result<WalletOperationResponse>> ClaimWeeklyGrantAsync(ClaimWeeklyGrantCommand command, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        if (wallet.LastWeeklyGrantAtUtc is DateTime lastWeeklyGrantAtUtc)
        {
            var nextWeeklyAtUtc = lastWeeklyGrantAtUtc.AddDays(7);
            if (nextWeeklyAtUtc > now)
            {
                return Result.Failure<WalletOperationResponse>(EconomyErrors.WeeklyGrantCooldown);
            }
        }

        var resolvedPremium = await ResolvePremiumStatusAsync(command.UserId, command.IsPremium, cancellationToken);
        var amount = resolvedPremium ? options.Value.WeeklyPremiumSpark : options.Value.WeeklyFreeSpark;
        var response = ApplyWalletDelta(wallet, amount, WalletLedgerSource.WeeklyGrant, "weekly payout", now);
        wallet.LastWeeklyGrantAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> ClaimAdRewardAsync(ClaimAdRewardCommand command, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        if (wallet.AdRewardWindowStartedAtUtc is null || wallet.AdRewardWindowStartedAtUtc.Value.Date != now.Date)
        {
            wallet.AdRewardWindowStartedAtUtc = now;
            wallet.AdRewardsClaimedInWindow = 0;
        }

        if (wallet.AdRewardsClaimedInWindow >= options.Value.AdRewardDailyLimit)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.AdRewardLimitReached);
        }

        var response = ApplyWalletDelta(wallet, options.Value.AdRewardSpark, WalletLedgerSource.AdReward, "rewarded ad", now);
        wallet.AdRewardsClaimedInWindow += 1;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> SpendAsync(SpendBalanceCommand command, CancellationToken cancellationToken)
    {
        if (command.Amount <= 0)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InvalidAmount);
        }

        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        if (wallet.Balance < command.Amount)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InsufficientBalance);
        }

        var now = DateTime.UtcNow;
        var response = ApplyWalletDelta(wallet, -command.Amount, WalletLedgerSource.GenerationSpend, command.Reason, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> CreditAsync(CreditBalanceCommand command, CancellationToken cancellationToken)
    {
        if (command.Amount <= 0)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InvalidAmount);
        }

        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;
        var response = ApplyWalletDelta(wallet, command.Amount, command.Source, command.Reason, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(response);
    }

    public async Task<Result<RedeemCodeAppliedResponse>> ApplyRedeemCodeAsync(ApplyRedeemCodeCommand command, CancellationToken cancellationToken)
    {
        var normalizedCode = NormalizeRedeemCode(command.Code);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeNotFound);
        }

        var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
            : null;

        var codeHash = HashRedeemCode(normalizedCode);
        var redeemCode = await dbContext.RedeemCodes
            .FirstOrDefaultAsync(x => x.CodeHash == codeHash, cancellationToken);

        if (redeemCode is null)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeNotFound);
        }

        var now = DateTime.UtcNow;
        if (!redeemCode.IsActive || redeemCode.StartsAtUtc > now)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeInactive);
        }

        if (redeemCode.ExpiresAtUtc <= now)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeExpired);
        }

        if (redeemCode.RedeemedCount >= redeemCode.MaxRedemptions)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeExhausted);
        }

        var userRedemptionCount = await dbContext.RedeemCodeRedemptions
            .CountAsync(x => x.RedeemCodeId == redeemCode.Id && x.UserId == command.UserId, cancellationToken);

        if (userRedemptionCount >= redeemCode.MaxRedemptionsPerUser)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(
                redeemCode.MaxRedemptionsPerUser <= 1
                    ? EconomyErrors.RedeemCodeAlreadyUsed
                    : EconomyErrors.RedeemCodeUserLimitReached);
        }

        WalletOperationResponse? walletOperation = null;
        Guid? ledgerEntryId = null;
        DateTime? premiumExpiresAtUtc = null;

        switch (NormalizeRewardKind(redeemCode.RewardKind))
        {
            case RedeemCodeRewardKind.Spark:
                {
                    var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
                    walletOperation = ApplyWalletDelta(
                        wallet,
                        redeemCode.RewardValue,
                        WalletLedgerSource.RedeemCode,
                        $"redeem:{redeemCode.CodePrefix}",
                        now,
                        out var createdLedgerEntryId);
                    ledgerEntryId = createdLedgerEntryId;
                    break;
                }
            default:
                return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeRewardUnsupported);
        }

        redeemCode.RedeemedCount += 1;
        redeemCode.UpdatedAtUtc = now;

        dbContext.RedeemCodeRedemptions.Add(new RedeemCodeRedemption
        {
            Id = Guid.NewGuid(),
            RedeemCodeId = redeemCode.Id,
            UserId = command.UserId,
            RewardKind = redeemCode.RewardKind,
            RewardValue = redeemCode.RewardValue,
            WalletLedgerEntryId = ledgerEntryId,
            PremiumExpiresAtUtc = premiumExpiresAtUtc,
            RedeemedAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(new RedeemCodeAppliedResponse(
            redeemCode.Id,
            redeemCode.RewardKind,
            redeemCode.RewardValue,
            walletOperation,
            premiumExpiresAtUtc));
    }

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

    public async Task<Result<WalletCheckoutConfigResponse>> GetWalletCheckoutConfigAsync(
        GetWalletCheckoutConfigQuery query,
        CancellationToken cancellationToken)
    {
        var packsResult = await ListPacksAsync(cancellationToken);
        var methods = await BuildAvailablePaymentMethodsAsync(
            new GetPaywallConfigQuery(query.Platform, query.AppVersion, query.Country, query.Locale),
            cancellationToken);

        return Result.Success(new WalletCheckoutConfigResponse(
            packsResult.Value,
            methods,
            methods.Any(x => x.RequiresExternalWarning)));
    }

    public async Task<Result<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(CancellationToken cancellationToken)
    {
        var configuredPlans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DisplayOrder)
            .ToListAsync(cancellationToken);

        var stripeEnabled = !string.IsNullOrWhiteSpace(options.Value.StripeSecretKey);
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

        if (!await IsPaymentProviderAllowedAsync(provider, command.Platform, command.Country, command.AppVersion, cancellationToken))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(command.PlanCode, cancellationToken);
        if (plan is null)
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var customer = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, cancellationToken);
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
                plan.BillingInterval),
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

        var customer = await dbContext.PaymentCustomers
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == command.UserId && x.Provider == provider, cancellationToken);

        if (customer is null)
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var portal = await paymentGateway.CreateBillingPortalSessionAsync(
            new BillingPortalCreateRequest(provider, command.UserId, customer.ExternalCustomerId),
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

        string? externalSubscriptionId = verification.Value.ExternalSubscriptionId;
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
            MapStoreSubscriptionStatus(verification.Value.Status, verification.Value.IsActive),
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

        var customerResult = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, cancellationToken);
        if (customerResult.IsFailure)
        {
            return Result.Failure<PaymentMethodSetupResponse>(customerResult.Error);
        }

        var setupResult = await paymentGateway.CreatePaymentMethodSetupAsync(
            new PaymentMethodSetupCreateRequest(provider, command.UserId, customerResult.Value.ExternalCustomerId),
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

        if (!await IsPaymentProviderAllowedAsync(provider, command.Platform, command.Country, command.AppVersion, cancellationToken))
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
                    savedMethod.ExternalPaymentMethodId),
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
                pack.DisplayName),
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

    public async Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetAdminWalletLedgerAsync(
        int skip,
        int take,
        string? source,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedSource = string.IsNullOrWhiteSpace(source)
            ? null
            : source.Trim().ToLowerInvariant();

        var query = dbContext.WalletLedgerEntries
            .AsNoTracking()
            .AsQueryable();

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        if (!string.IsNullOrWhiteSpace(normalizedSource))
        {
            query = query.Where(x => x.Source == normalizedSource);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
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

    public async Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetAdminPurchaseHistoryAsync(
        int skip,
        int take,
        string? status,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();

        var query = dbContext.PurchaseOrders
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        var items = await query
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

    public async Task<Result<OffsetPagedResponse<AdminUserSubscriptionResponse>>> GetAdminSubscriptionsAsync(
        int skip,
        int take,
        string? status,
        string? provider,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();
        var normalizedProvider = string.IsNullOrWhiteSpace(provider)
            ? null
            : provider.Trim().ToLowerInvariant();

        var query = dbContext.UserSubscriptions
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(normalizedProvider))
        {
            query = query.Where(x => x.Provider == normalizedProvider);
        }

        var items = await query
            .GroupJoin(
                dbContext.SubscriptionPlans.AsNoTracking(),
                subscription => subscription.PlanId,
                plan => plan.Id,
                (subscription, plans) => new { subscription, plans })
            .SelectMany(
                pair => pair.plans.DefaultIfEmpty(),
                (pair, plan) => new AdminUserSubscriptionResponse(
                    pair.subscription.Id,
                    pair.subscription.UserId,
                    pair.subscription.Provider,
                    pair.subscription.PurchaseChannel,
                    pair.subscription.Region,
                    pair.subscription.PlanId,
                    plan != null ? plan.Name : null,
                    pair.subscription.Status,
                    pair.subscription.CurrentPeriodStartUtc,
                    pair.subscription.CurrentPeriodEndUtc,
                    pair.subscription.CancelAtPeriodEnd,
                    pair.subscription.MonthlyTokenLimit,
                    pair.subscription.MonthlyTokensGranted,
                    pair.subscription.LastTokenGrantAtUtc,
                    pair.subscription.CreatedAtUtc,
                    pair.subscription.UpdatedAtUtc))
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.SubscriptionId)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<IReadOnlyList<AdminCurrencyPackResponse>>> ListAdminCurrencyPacksAsync(CancellationToken cancellationToken)
    {
        var packs = await dbContext.CurrencyPacks
            .AsNoTracking()
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .ThenBy(x => x.Code)
            .Select(x => new AdminCurrencyPackResponse(
                x.Id,
                x.Code,
                x.DisplayName,
                x.CurrencyCode,
                x.PriceAmount,
                x.GrantedSpark,
                x.BonusSpark,
                x.GrantedSpark + x.BonusSpark,
                x.IsActive,
                x.SortOrder))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminCurrencyPackResponse>>(packs);
    }

    public async Task<Result<IReadOnlyList<AdminSubscriptionPlanResponse>>> ListAdminSubscriptionPlansAsync(CancellationToken cancellationToken)
    {
        var plans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .OrderBy(x => x.DisplayOrder)
            .ThenBy(x => x.Id)
            .Select(x => new AdminSubscriptionPlanResponse(
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
                x.UpdatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminSubscriptionPlanResponse>>(plans);
    }

    public async Task<Result<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>> ListAdminPaymentProviderConfigurationsAsync(CancellationToken cancellationToken)
    {
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .OrderBy(x => x.Platform)
            .ThenBy(x => x.Provider)
            .ThenBy(x => x.Region)
            .Select(x => new AdminPaymentProviderConfigurationResponse(
                x.Id,
                x.Provider,
                x.Platform,
                x.Region,
                x.IsEnabled,
                x.IsRecommended,
                x.IsSelectedByDefault,
                x.RequiresExternalWarning,
                x.RequiresStoreDisclosure,
                x.AllowedFromAppVersion,
                x.ExternalCheckoutAllowed,
                x.BonusTokensPercent,
                x.DisplayLabel,
                x.DisplaySubtitle,
                x.WarningTitle,
                x.WarningMessage,
                x.Mode,
                x.Notes,
                x.UpdatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>(configs);
    }

    public async Task<Result<AdminCurrencyPackResponse>> UpdateCurrencyPackAsync(
        UpdateCurrencyPackCommand command,
        CancellationToken cancellationToken)
    {
        var pack = await dbContext.CurrencyPacks
            .FirstOrDefaultAsync(x => x.Id == command.PackId, cancellationToken);

        if (pack is null)
        {
            return Result.Failure<AdminCurrencyPackResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        pack.DisplayName = command.DisplayName.Trim();
        pack.PriceAmount = decimal.Round(command.PriceAmount, 2, MidpointRounding.AwayFromZero);
        pack.GrantedSpark = command.GrantedSpark;
        pack.BonusSpark = command.BonusSpark;
        pack.IsActive = command.IsActive;
        pack.SortOrder = command.SortOrder;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToAdminCurrencyPackResponse(pack));
    }

    public async Task<Result<AdminSubscriptionPlanResponse>> UpdateSubscriptionPlanAsync(
        UpdateSubscriptionPlanCommand command,
        CancellationToken cancellationToken)
    {
        var plan = await dbContext.SubscriptionPlans
            .FirstOrDefaultAsync(x => x.Id == command.PlanId, cancellationToken);

        if (plan is null)
        {
            return Result.Failure<AdminSubscriptionPlanResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        plan.Name = command.Name.Trim();
        plan.PriceAmount = decimal.Round(command.PriceAmount, 2, MidpointRounding.AwayFromZero);
        plan.CurrencyCode = command.CurrencyCode.Trim().ToUpperInvariant();
        plan.MonthlyTokenLimit = command.MonthlyTokenLimit;
        plan.IsRecommended = command.IsRecommended;
        plan.IsActive = command.IsActive;
        plan.AppleProductId = NullIfWhiteSpace(command.AppleProductId);
        plan.GoogleProductId = NullIfWhiteSpace(command.GoogleProductId);
        plan.StripePriceId = NullIfWhiteSpace(command.StripePriceId);
        plan.DisplayOrder = command.DisplayOrder;
        plan.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new AdminSubscriptionPlanResponse(
            plan.Id,
            plan.Name,
            plan.BillingPeriod,
            plan.PriceAmount,
            plan.CurrencyCode,
            plan.MonthlyTokenLimit,
            plan.IsRecommended,
            plan.IsActive,
            plan.AppleProductId,
            plan.GoogleProductId,
            plan.StripePriceId,
            plan.DisplayOrder,
            plan.UpdatedAtUtc));
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> UpdatePaymentProviderConfigurationAsync(
        UpdatePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        var configuration = await dbContext.PaymentProviderConfigurations
            .FirstOrDefaultAsync(x => x.Id == command.ConfigurationId, cancellationToken);

        if (configuration is null)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationNotFound);
        }

        configuration.Region = NormalizeConfigRegion(command.Region);
        configuration.IsEnabled = command.IsEnabled;
        configuration.IsRecommended = command.IsRecommended;
        configuration.IsSelectedByDefault = command.IsSelectedByDefault;
        configuration.RequiresExternalWarning = command.RequiresExternalWarning;
        configuration.RequiresStoreDisclosure = command.RequiresStoreDisclosure;
        configuration.AllowedFromAppVersion = command.AllowedFromAppVersion.Trim();
        configuration.ExternalCheckoutAllowed = command.ExternalCheckoutAllowed;
        configuration.BonusTokensPercent = command.BonusTokensPercent;
        configuration.DisplayLabel = NullIfWhiteSpace(command.DisplayLabel);
        configuration.DisplaySubtitle = NullIfWhiteSpace(command.DisplaySubtitle);
        configuration.WarningTitle = NullIfWhiteSpace(command.WarningTitle);
        configuration.WarningMessage = NullIfWhiteSpace(command.WarningMessage);
        configuration.Mode = command.Mode.Trim().ToLowerInvariant();
        configuration.Notes = NullIfWhiteSpace(command.Notes);
        configuration.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new AdminPaymentProviderConfigurationResponse(
            configuration.Id,
            configuration.Provider,
            configuration.Platform,
            configuration.Region,
            configuration.IsEnabled,
            configuration.IsRecommended,
            configuration.IsSelectedByDefault,
            configuration.RequiresExternalWarning,
            configuration.RequiresStoreDisclosure,
            configuration.AllowedFromAppVersion,
            configuration.ExternalCheckoutAllowed,
            configuration.BonusTokensPercent,
            configuration.DisplayLabel,
            configuration.DisplaySubtitle,
            configuration.WarningTitle,
            configuration.WarningMessage,
            configuration.Mode,
            configuration.Notes,
            configuration.UpdatedAtUtc));
    }

    public async Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken)
    {
        var codes = await dbContext.RedeemCodes
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var codeIds = codes.Select(x => x.Id).ToArray();
        var redemptions = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId))
            .OrderByDescending(x => x.RedeemedAtUtc)
            .ToListAsync(cancellationToken);

        var redemptionsByCode = redemptions
            .GroupBy(x => x.RedeemCodeId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<AdminRedeemCodeRedemptionResponse>)group
                    .Select(ToAdminRedeemCodeRedemptionResponse)
                    .ToList());

        var result = codes
            .Select(code => ToAdminRedeemCodeResponse(code, redemptionsByCode.GetValueOrDefault(code.Id) ?? []))
            .ToList();

        return Result.Success<IReadOnlyList<AdminRedeemCodeResponse>>(result);
    }

    public async Task<Result<OffsetPagedResponse<AdminSubscriptionEventResponse>>> GetAdminSubscriptionEventsAsync(
        int skip,
        int take,
        string? provider,
        string? status,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedProvider = string.IsNullOrWhiteSpace(provider)
            ? null
            : provider.Trim().ToLowerInvariant();
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();

        var query = dbContext.SubscriptionEventLogs
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedProvider))
        {
            query = query.Where(x => x.Provider == normalizedProvider);
        }

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new AdminSubscriptionEventResponse(
                x.Id,
                x.UserId,
                x.UserSubscriptionId,
                x.Provider,
                x.EventType,
                x.Status,
                x.ExternalEventId,
                x.ExternalSubscriptionId,
                x.CreatedAtUtc,
                x.ProcessedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<AdminRedeemCodeResponse>> CreateRedeemCodeAsync(
        CreateRedeemCodeCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedCode = NormalizeRedeemCode(command.Code);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeNotFound);
        }

        var codeHash = HashRedeemCode(normalizedCode);
        var exists = await dbContext.RedeemCodes.AnyAsync(x => x.CodeHash == codeHash, cancellationToken);
        if (exists)
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var rewardKind = NormalizeRewardKind(command.RewardKind);
        if (!string.Equals(rewardKind, RedeemCodeRewardKind.Spark, StringComparison.Ordinal))
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeRewardUnsupported);
        }

        var code = new RedeemCode
        {
            Id = Guid.NewGuid(),
            Code = normalizedCode,
            CodeHash = codeHash,
            CodePrefix = BuildRedeemCodePrefix(normalizedCode),
            Description = command.Description.Trim(),
            RewardKind = rewardKind,
            RewardValue = command.RewardValue,
            MaxRedemptions = command.MaxRedemptions,
            MaxRedemptionsPerUser = command.MaxRedemptionsPerUser,
            RedeemedCount = 0,
            IsActive = command.IsActive,
            StartsAtUtc = command.StartsAtUtc,
            ExpiresAtUtc = command.ExpiresAtUtc,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.RedeemCodes.Add(code);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToAdminRedeemCodeResponse(code, []));
    }

    public async Task<Result<AdminRedeemCodeResponse>> UpdateRedeemCodeAsync(
        UpdateRedeemCodeCommand command,
        CancellationToken cancellationToken)
    {
        var code = await dbContext.RedeemCodes
            .FirstOrDefaultAsync(x => x.Id == command.RedeemCodeId, cancellationToken);

        if (code is null)
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeNotFound);
        }

        if (command.MaxRedemptions < code.RedeemedCount)
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeExhausted);
        }

        var redeemedUserIds = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => x.RedeemCodeId == code.Id)
            .Select(x => x.UserId)
            .ToListAsync(cancellationToken);

        var maxRedeemedBySingleUser = redeemedUserIds
            .GroupBy(userId => userId)
            .Select(group => group.Count())
            .DefaultIfEmpty(0)
            .Max();

        if (command.MaxRedemptionsPerUser < maxRedeemedBySingleUser)
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeUserLimitReached);
        }

        var rewardKind = NormalizeRewardKind(command.RewardKind);
        if (!string.Equals(rewardKind, RedeemCodeRewardKind.Spark, StringComparison.Ordinal))
        {
            return Result.Failure<AdminRedeemCodeResponse>(EconomyErrors.RedeemCodeRewardUnsupported);
        }

        code.Description = command.Description.Trim();
        code.RewardKind = rewardKind;
        code.RewardValue = command.RewardValue;
        code.MaxRedemptions = command.MaxRedemptions;
        code.MaxRedemptionsPerUser = command.MaxRedemptionsPerUser;
        code.IsActive = command.IsActive;
        code.StartsAtUtc = command.StartsAtUtc;
        code.ExpiresAtUtc = command.ExpiresAtUtc;
        code.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        var redemptions = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => x.RedeemCodeId == code.Id)
            .OrderByDescending(x => x.RedeemedAtUtc)
            .ToListAsync(cancellationToken);

        return Result.Success(ToAdminRedeemCodeResponse(code, redemptions.Select(ToAdminRedeemCodeRedemptionResponse).ToList()));
    }

    public async Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken)
    {
        string? eventId;
        string? eventType;
        try
        {
            var stripeEvent = EventUtility.ConstructEvent(command.RawBody, command.StripeSignature, options.Value.StripeWebhookSecret);
            eventId = stripeEvent.Id;
            eventType = stripeEvent.Type;
        }
        catch
        {
            if (!VerifyStripeSignatureFallback(command.RawBody, command.StripeSignature, options.Value.StripeWebhookSecret))
            {
                return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidStripeSignature);
            }

            var envelope = ParseStripeEnvelope(command.RawBody);
            if (!envelope.Success)
            {
                return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
            }

            eventId = envelope.EventId;
            eventType = envelope.EventType;
        }

        if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
        {
            return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var parsedEvent = ParseStripeEvent(command.RawBody);
        if (!parsedEvent.Success)
        {
            return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "stripe" && x.EventId == eventId, cancellationToken);

        if (alreadyProcessed)
        {
            return Result.Success(new StripeWebhookResultResponse(eventId, false, "ignored_duplicate"));
        }

        dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            EventId = eventId,
            EventType = eventType,
            ProcessedAtUtc = DateTime.UtcNow
        });

        if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
            || string.Equals(eventType, "payment_intent.succeeded", StringComparison.Ordinal))
        {
            var order = await ResolveOrderAsync(parsedEvent.OrderId, parsedEvent.ObjectId, cancellationToken);
            if (order is not null)
            {
                var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
                if (confirmResult.IsFailure && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
                {
                    return Result.Failure<StripeWebhookResultResponse>(confirmResult.Error);
                }
            }
        }

        if (parsedEvent.UserId.HasValue
            && string.Equals(parsedEvent.Purpose, "premium_subscription", StringComparison.Ordinal))
        {
            if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
                || string.Equals(eventType, "customer.subscription.created", StringComparison.Ordinal))
            {
                if (identityService is null)
                {
                    return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.PremiumBillingUnavailable);
                }

                var premiumResult = await identityService.SetPremiumStatusAsync(
                    new SetPremiumStatusCommand(parsedEvent.UserId.Value, true),
                    cancellationToken);

                if (premiumResult.IsFailure)
                {
                    return Result.Failure<StripeWebhookResultResponse>(premiumResult.Error);
                }

                if (!string.IsNullOrWhiteSpace(parsedEvent.PlanCode))
                {
                    var (resolvedPlan, existingSubscription) = await ResolveStripePlanContextAsync(
                        parsedEvent.UserId.Value,
                        parsedEvent.PlanCode,
                        parsedEvent.SubscriptionId,
                        cancellationToken);

                    if (resolvedPlan is null)
                    {
                        return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
                    }

                    var subscription = await UpsertUserSubscriptionAsync(
                        parsedEvent.UserId.Value,
                        "stripe",
                        "web",
                        string.Empty,
                        resolvedPlan.PlanCode,
                        "Active",
                        parsedEvent.CustomerId,
                        parsedEvent.SubscriptionId,
                        parsedEvent.ObjectId,
                        parsedEvent.CurrentPeriodStartUtc ?? existingSubscription?.CurrentPeriodStartUtc ?? DateTime.UtcNow,
                        parsedEvent.CurrentPeriodEndUtc,
                        parsedEvent.CancelAtPeriodEnd,
                        resolvedPlan.MonthlyTokenLimit,
                        cancellationToken);

                    await AppendSubscriptionEventAsync(
                        parsedEvent.UserId.Value,
                        subscription.Id,
                        "stripe",
                        "SubscriptionActivated",
                        subscription.Status,
                        eventId,
                        subscription.ExternalSubscriptionId,
                        command.RawBody,
                        cancellationToken);
                }
            }

            if (string.Equals(eventType, "customer.subscription.updated", StringComparison.Ordinal)
                || string.Equals(eventType, "customer.subscription.deleted", StringComparison.Ordinal))
            {
                var isActive = string.Equals(parsedEvent.Status, "active", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(parsedEvent.Status, "trialing", StringComparison.OrdinalIgnoreCase);

                if (string.Equals(eventType, "customer.subscription.deleted", StringComparison.Ordinal))
                {
                    isActive = false;
                }

                if (identityService is null)
                {
                    return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.PremiumBillingUnavailable);
                }

                var premiumResult = await identityService.SetPremiumStatusAsync(
                    new SetPremiumStatusCommand(parsedEvent.UserId.Value, isActive),
                    cancellationToken);

                if (premiumResult.IsFailure)
                {
                    return Result.Failure<StripeWebhookResultResponse>(premiumResult.Error);
                }

                if (!string.IsNullOrWhiteSpace(parsedEvent.PlanCode) || !string.IsNullOrWhiteSpace(parsedEvent.SubscriptionId))
                {
                    var (resolvedPlan, existingSubscription) = await ResolveStripePlanContextAsync(
                        parsedEvent.UserId.Value,
                        parsedEvent.PlanCode,
                        parsedEvent.SubscriptionId,
                        cancellationToken);

                    if (resolvedPlan is null && existingSubscription is null)
                    {
                        return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
                    }

                    var resolvedPlanId = resolvedPlan?.PlanCode ?? existingSubscription!.PlanId;
                    var monthlyTokenLimit = resolvedPlan?.MonthlyTokenLimit ?? existingSubscription!.MonthlyTokenLimit;
                    var subscriptionStatus = isActive
                        ? (parsedEvent.CancelAtPeriodEnd ? "Canceled" : MapStripeSubscriptionStatus(parsedEvent.Status))
                        : "Expired";

                    var subscription = await UpsertUserSubscriptionAsync(
                        parsedEvent.UserId.Value,
                        "stripe",
                        "web",
                        string.Empty,
                        resolvedPlanId,
                        subscriptionStatus,
                        parsedEvent.CustomerId,
                        parsedEvent.SubscriptionId,
                        parsedEvent.ObjectId,
                        parsedEvent.CurrentPeriodStartUtc ?? existingSubscription?.CurrentPeriodStartUtc,
                        parsedEvent.CurrentPeriodEndUtc,
                        parsedEvent.CancelAtPeriodEnd,
                        monthlyTokenLimit,
                        cancellationToken);

                    await AppendSubscriptionEventAsync(
                        parsedEvent.UserId.Value,
                        subscription.Id,
                        "stripe",
                        string.Equals(eventType, "customer.subscription.deleted", StringComparison.Ordinal)
                            ? "SubscriptionExpired"
                            : "SubscriptionRenewed",
                        subscription.Status,
                        eventId,
                        subscription.ExternalSubscriptionId,
                        command.RawBody,
                        cancellationToken);
                }
            }
        }

        if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
            && string.Equals(parsedEvent.Purpose, "payment_method_setup", StringComparison.Ordinal)
            && parsedEvent.UserId.HasValue
            && !string.IsNullOrWhiteSpace(parsedEvent.SetupIntentId))
        {
            var methodResult = await paymentGateway.ResolveSetupIntentPaymentMethodAsync(
                new PaymentMethodResolveRequest("stripe", parsedEvent.SetupIntentId),
                cancellationToken);

            if (methodResult.IsFailure)
            {
                return Result.Failure<StripeWebhookResultResponse>(methodResult.Error);
            }

            await SavePaymentMethodAsync(parsedEvent.UserId.Value, "stripe", methodResult.Value, cancellationToken);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(new StripeWebhookResultResponse(eventId, true, "processed"));
    }

    public async Task<Result<StoreWebhookResultResponse>> HandleAppStoreServerNotificationAsync(
        AppStoreServerNotificationCommand command,
        CancellationToken cancellationToken)
    {
        var parsed = ParseAppStoreServerNotification(command.SignedPayload);
        if (!parsed.Success || string.IsNullOrWhiteSpace(parsed.EventId))
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "app_store" && x.EventId == parsed.EventId, cancellationToken);

        if (alreadyProcessed)
        {
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
        }

        dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
        {
            Id = Guid.NewGuid(),
            Provider = "app_store",
            EventId = parsed.EventId,
            EventType = parsed.NotificationType ?? "unknown",
            ProcessedAtUtc = DateTime.UtcNow
        });

        var existingSubscription = await dbContext.UserSubscriptions
            .FirstOrDefaultAsync(
                x => x.Provider == "app_store"
                    && ((!string.IsNullOrWhiteSpace(parsed.ExternalSubscriptionId) && x.ExternalSubscriptionId == parsed.ExternalSubscriptionId)
                        || (!string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId) && x.ExternalTransactionId == parsed.ExternalPurchaseId)),
                cancellationToken);

        if (existingSubscription is null)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_not_found"));
        }

        var plan = await ResolveStoreNotificationPlanAsync(existingSubscription.PlanId, parsed.ProductId, "app_store", cancellationToken);
        if (plan is null)
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var status = MapAppStoreNotificationStatus(parsed.NotificationType, parsed.Subtype, parsed.ExpiresAtUtc);
        var isPremium = IsStoreSubscriptionPremium(status, parsed.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

        if (identityService is null)
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(existingSubscription.UserId, isPremium),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<StoreWebhookResultResponse>(premiumResult.Error);
        }

        var subscription = await UpsertUserSubscriptionAsync(
            existingSubscription.UserId,
            "app_store",
            existingSubscription.PurchaseChannel,
            existingSubscription.Region,
            plan.PlanCode,
            status,
            parsed.EventId,
            parsed.ExternalSubscriptionId ?? existingSubscription.ExternalSubscriptionId,
            parsed.ExternalPurchaseId ?? existingSubscription.ExternalTransactionId,
            ResolveNotificationPeriodStartUtc(plan.BillingPeriod, parsed.ExpiresAtUtc, existingSubscription.CurrentPeriodStartUtc),
            parsed.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc,
            parsed.CancelAtPeriodEnd,
            plan.MonthlyTokenLimit,
            cancellationToken);

        await AppendSubscriptionEventAsync(
            existingSubscription.UserId,
            subscription.Id,
            "app_store",
            parsed.NotificationType ?? "AppStoreNotification",
            subscription.Status,
            parsed.EventId,
            subscription.ExternalSubscriptionId,
            command.SignedPayload,
            cancellationToken);

        return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, true, "processed"));
    }

    public async Task<Result<StoreWebhookResultResponse>> HandleGooglePlayDeveloperNotificationAsync(
        GooglePlayDeveloperNotificationCommand command,
        CancellationToken cancellationToken)
    {
        var parsed = ParseGooglePlayDeveloperNotification(command.MessageData, command.MessageId);
        if (!parsed.Success || string.IsNullOrWhiteSpace(parsed.EventId))
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "google_play" && x.EventId == parsed.EventId, cancellationToken);

        if (alreadyProcessed)
        {
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
        }

        dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
        {
            Id = Guid.NewGuid(),
            Provider = "google_play",
            EventId = parsed.EventId,
            EventType = $"notification_{parsed.NotificationType}",
            ProcessedAtUtc = DateTime.UtcNow
        });

        var existingSubscription = await dbContext.UserSubscriptions
            .FirstOrDefaultAsync(
                x => x.Provider == "google_play"
                    && ((!string.IsNullOrWhiteSpace(parsed.PurchaseToken) && x.ExternalTransactionId == parsed.PurchaseToken)
                        || (!string.IsNullOrWhiteSpace(parsed.PurchaseToken) && x.ExternalSubscriptionId == parsed.PurchaseToken)),
                cancellationToken);

        if (existingSubscription is null)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_not_found"));
        }

        var plan = await ResolveStoreNotificationPlanAsync(existingSubscription.PlanId, parsed.ProductId, "google_play", cancellationToken);
        if (plan is null)
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var verification = await storeSubscriptionVerifier.VerifyAsync(
            new StoreSubscriptionVerificationRequest(
                existingSubscription.UserId,
                "google_play",
                plan.PlanCode,
                parsed.ProductId ?? string.Empty,
                parsed.PurchaseToken ?? string.Empty,
                null,
                parsed.PurchaseToken,
                null),
            cancellationToken);

        if (verification.IsFailure)
        {
            return Result.Failure<StoreWebhookResultResponse>(verification.Error);
        }

        var status = MapGooglePlayNotificationStatus(parsed.NotificationType, verification.Value.Status, verification.Value.IsActive);
        var cancelAtPeriodEnd = parsed.NotificationType == 3;
        var isPremium = IsStoreSubscriptionPremium(status, verification.Value.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

        if (identityService is null)
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(existingSubscription.UserId, isPremium),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<StoreWebhookResultResponse>(premiumResult.Error);
        }

        var subscription = await UpsertUserSubscriptionAsync(
            existingSubscription.UserId,
            "google_play",
            existingSubscription.PurchaseChannel,
            existingSubscription.Region,
            plan.PlanCode,
            status,
            parsed.EventId,
            existingSubscription.ExternalSubscriptionId ?? verification.Value.ExternalSubscriptionId,
            parsed.PurchaseToken ?? existingSubscription.ExternalTransactionId,
            ResolveNotificationPeriodStartUtc(plan.BillingPeriod, verification.Value.ExpiresAtUtc, existingSubscription.CurrentPeriodStartUtc),
            verification.Value.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc,
            cancelAtPeriodEnd,
            plan.MonthlyTokenLimit,
            cancellationToken);

        await AppendSubscriptionEventAsync(
            existingSubscription.UserId,
            subscription.Id,
            "google_play",
            $"GooglePlayNotification:{parsed.NotificationType}",
            subscription.Status,
            parsed.EventId,
            subscription.ExternalSubscriptionId,
            command.MessageData,
            cancellationToken);

        return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed"));
    }

    private async Task<Result<PaymentCustomer>> GetOrCreatePaymentCustomerAsync(
        Guid userId,
        string provider,
        CancellationToken cancellationToken)
    {
        var existing = await dbContext.PaymentCustomers
            .FirstOrDefaultAsync(x => x.UserId == userId && x.Provider == provider, cancellationToken);

        if (existing is not null)
        {
            return Result.Success(existing);
        }

        var createResult = await paymentGateway.CreateCustomerAsync(
            new PaymentCustomerCreateRequest(provider, userId),
            cancellationToken);

        if (createResult.IsFailure)
        {
            return Result.Failure<PaymentCustomer>(createResult.Error);
        }

        var now = DateTime.UtcNow;
        var customer = new PaymentCustomer
        {
            UserId = userId,
            Provider = provider,
            ExternalCustomerId = createResult.Value.ExternalCustomerId,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.PaymentCustomers.Add(customer);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(customer);
    }

    private async Task SavePaymentMethodAsync(
        Guid userId,
        string provider,
        PaymentMethodDetailsResponse details,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var existing = await dbContext.SavedPaymentMethods
            .FirstOrDefaultAsync(x => x.Provider == provider && x.ExternalPaymentMethodId == details.ExternalPaymentMethodId, cancellationToken);

        if (existing is not null)
        {
            existing.UserId = userId;
            existing.Brand = details.Brand;
            existing.Last4 = details.Last4;
            existing.ExpMonth = details.ExpMonth;
            existing.ExpYear = details.ExpYear;
            existing.IsActive = true;
            existing.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return;
        }

        var hasDefault = await dbContext.SavedPaymentMethods
            .AnyAsync(x => x.UserId == userId && x.IsActive && x.IsDefault, cancellationToken);

        dbContext.SavedPaymentMethods.Add(new SavedPaymentMethod
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = provider,
            ExternalPaymentMethodId = details.ExternalPaymentMethodId,
            Brand = details.Brand,
            Last4 = details.Last4,
            ExpMonth = details.ExpMonth,
            ExpYear = details.ExpYear,
            IsDefault = !hasDefault,
            IsActive = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<bool> ResolvePremiumStatusAsync(Guid userId, bool fallbackIsPremium, CancellationToken cancellationToken)
    {
        var subscription = await GetLatestUserSubscriptionAsync(userId, cancellationToken);
        var subscriptionIsPremium = IsActivePremiumSubscription(subscription);

        if (identityService is null)
        {
            return subscriptionIsPremium || fallbackIsPremium;
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        var profileIsPremium = profile.IsSuccess ? profile.Value.IsPremium : fallbackIsPremium;
        return subscriptionIsPremium || profileIsPremium;
    }

    private async Task<Wallet> GetOrCreateWalletAsync(Guid userId, CancellationToken cancellationToken)
    {
        var wallet = await dbContext.Wallets.FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (wallet is not null)
        {
            return wallet;
        }

        wallet = new Wallet
        {
            UserId = userId,
            Balance = 0,
            AdRewardsClaimedInWindow = 0,
            UpdatedAtUtc = DateTime.UtcNow
        };

        dbContext.Wallets.Add(wallet);
        await dbContext.SaveChangesAsync(cancellationToken);
        return wallet;
    }

    private WalletOperationResponse ApplyWalletDelta(Wallet wallet, int delta, string source, string reason, DateTime now)
    {
        return ApplyWalletDelta(wallet, delta, source, reason, now, out _);
    }

    private WalletOperationResponse ApplyWalletDelta(Wallet wallet, int delta, string source, string reason, DateTime now, out Guid ledgerEntryId)
    {
        ledgerEntryId = Guid.NewGuid();
        wallet.Balance += delta;
        wallet.UpdatedAtUtc = now;

        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = ledgerEntryId,
            UserId = wallet.UserId,
            Delta = delta,
            BalanceAfter = wallet.Balance,
            Source = source,
            Reason = reason,
            CreatedAtUtc = now
        });

        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);
        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletOperationResponse(
            wallet.UserId,
            delta,
            wallet.Balance,
            source,
            now,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday);
    }

    private WalletStateResponse ToWalletState(Wallet wallet, bool isPremium)
    {
        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);

        if (wallet.AdRewardWindowStartedAtUtc is null || wallet.AdRewardWindowStartedAtUtc.Value.Date != DateTime.UtcNow.Date)
        {
            return new WalletStateResponse(
                wallet.UserId,
                wallet.Balance,
                nextWeeklyGrantAtUtc,
                options.Value.AdRewardDailyLimit,
                isPremium,
                wallet.UpdatedAtUtc);
        }

        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletStateResponse(
            wallet.UserId,
            wallet.Balance,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday,
            isPremium,
            wallet.UpdatedAtUtc);
    }

    private async Task<Result<PurchaseOrder>> ConfirmPurchaseInternalAsync(PurchaseOrder order, CancellationToken cancellationToken)
    {
        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
            || !string.Equals(order.Status, PurchaseOrderStatus.Pending, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
        }

        var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        ApplyWalletDelta(wallet, order.SparkToGrant, WalletLedgerSource.PackPurchase, $"purchase:{order.Id:D}", now);

        order.Status = PurchaseOrderStatus.Succeeded;
        order.ConfirmedAtUtc = now;
        wallet.UpdatedAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(order);
    }

    private async Task<PurchaseOrder?> ResolveOrderAsync(Guid? orderId, string? externalPaymentId, CancellationToken cancellationToken)
    {
        if (orderId.HasValue)
        {
            var byId = await dbContext.PurchaseOrders.FirstOrDefaultAsync(x => x.Id == orderId.Value, cancellationToken);
            if (byId is not null)
            {
                return byId;
            }
        }

        if (!string.IsNullOrWhiteSpace(externalPaymentId))
        {
            return await dbContext.PurchaseOrders.FirstOrDefaultAsync(
                x => x.PaymentProvider == "stripe" && x.ExternalPaymentId == externalPaymentId,
                cancellationToken);
        }

        return null;
    }

    private static PurchaseCheckoutResponse ToPurchaseCheckoutResponse(PurchaseOrder order)
    {
        return new PurchaseCheckoutResponse(
            order.Id,
            order.UserId,
            order.PaymentProvider,
            order.ExternalPaymentId ?? string.Empty,
            order.CheckoutUrl ?? string.Empty,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.CreatedAtUtc);
    }

    private static PurchaseOrderResponse ToPurchaseOrderResponse(PurchaseOrder order)
    {
        return new PurchaseOrderResponse(
            order.Id,
            order.UserId,
            order.PackId,
            order.PaymentProvider,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.ExternalPaymentId,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc);
    }

    private static AdminCurrencyPackResponse ToAdminCurrencyPackResponse(CurrencyPack pack)
    {
        return new AdminCurrencyPackResponse(
            pack.Id,
            pack.Code,
            pack.DisplayName,
            pack.CurrencyCode,
            pack.PriceAmount,
            pack.GrantedSpark,
            pack.BonusSpark,
            pack.GrantedSpark + pack.BonusSpark,
            pack.IsActive,
            pack.SortOrder);
    }

    private static AdminRedeemCodeResponse ToAdminRedeemCodeResponse(
        RedeemCode code,
        IReadOnlyList<AdminRedeemCodeRedemptionResponse> redemptions)
    {
        return new AdminRedeemCodeResponse(
            code.Id,
            string.IsNullOrWhiteSpace(code.Code) ? $"{code.CodePrefix}..." : code.Code,
            code.CodePrefix,
            code.Description,
            code.RewardKind,
            code.RewardValue,
            code.MaxRedemptions,
            code.MaxRedemptionsPerUser,
            code.RedeemedCount,
            code.IsActive,
            code.StartsAtUtc,
            code.ExpiresAtUtc,
            code.CreatedAtUtc,
            code.UpdatedAtUtc,
            redemptions);
    }

    private static AdminRedeemCodeRedemptionResponse ToAdminRedeemCodeRedemptionResponse(RedeemCodeRedemption redemption)
    {
        return new AdminRedeemCodeRedemptionResponse(
            redemption.Id,
            redemption.UserId,
            redemption.RewardKind,
            redemption.RewardValue,
            redemption.WalletLedgerEntryId,
            redemption.PremiumExpiresAtUtc,
            redemption.RedeemedAtUtc);
    }

    private static OffsetPagedResponse<T> ToPaged<T>(List<T> items, int skip, int take)
    {
        var hasMore = items.Count > take;
        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        return new OffsetPagedResponse<T>(items, skip, take, hasMore);
    }

    private static int NormalizeTake(int take, int fallback, int max)
    {
        if (take <= 0)
        {
            return fallback;
        }

        return Math.Min(take, max);
    }

    private static string NormalizeRedeemCode(string rawCode)
    {
        return Regex.Replace(rawCode.Trim().ToUpperInvariant(), "\\s+", string.Empty, RegexOptions.CultureInvariant);
    }

    private static string NormalizeRewardKind(string rawRewardKind)
    {
        return rawRewardKind.Trim().ToLowerInvariant();
    }

    private static string HashRedeemCode(string normalizedCode)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(normalizedCode));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string BuildRedeemCodePrefix(string normalizedCode)
    {
        return normalizedCode[..Math.Min(normalizedCode.Length, 4)];
    }

    private async Task<List<PaywallPaymentMethodResponse>> BuildAvailablePaymentMethodsAsync(
        GetPaywallConfigQuery query,
        CancellationToken cancellationToken)
    {
        var platform = NormalizePlatform(query.Platform);
        var region = NormalizeRegion(query.Country);
        var isEuRegion = IsEuRegion(region);
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var methods = new List<PaywallPaymentMethodResponse>();

        if (string.Equals(platform, "web", StringComparison.Ordinal))
        {
            var stripeConfig = SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
            if (stripeConfig is not null)
            {
                methods.Add(ToPaywallPaymentMethodResponse(stripeConfig, platform, region, "web"));
            }

            return SortPaymentMethods(methods);
        }

        var nativeProvider = string.Equals(platform, "ios", StringComparison.Ordinal) ? "app_store" : "google_play";
        var nativeConfig = SelectProviderConfig(configs, nativeProvider, platform, region, isEuRegion, query.AppVersion);
        if (nativeConfig is not null)
        {
            methods.Add(ToPaywallPaymentMethodResponse(nativeConfig, platform, region, "in_app"));
        }

        var stripeMobileConfig = SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
        if (stripeMobileConfig is not null && stripeMobileConfig.ExternalCheckoutAllowed)
        {
            methods.Add(ToPaywallPaymentMethodResponse(
                stripeMobileConfig,
                platform,
                region,
                string.Equals(platform, "ios", StringComparison.Ordinal) ? "external_checkout" : "alternative_billing"));
        }

        return SortPaymentMethods(methods);
    }

    private static PaywallPaymentMethodResponse ToPaywallPaymentMethodResponse(
        PaymentProviderConfiguration config,
        string platform,
        string region,
        string purchaseChannel)
    {
        return new PaywallPaymentMethodResponse(
            config.Provider,
            purchaseChannel,
            platform,
            region,
            config.IsEnabled,
            config.IsSelectedByDefault,
            config.RequiresExternalWarning,
            config.RequiresStoreDisclosure,
            config.IsRecommended,
            config.BonusTokensPercent,
            config.DisplayLabel,
            config.DisplaySubtitle,
            config.WarningTitle,
            config.WarningMessage,
            config.Notes);
    }

    private static List<PaywallPaymentMethodResponse> SortPaymentMethods(IEnumerable<PaywallPaymentMethodResponse> methods)
    {
        return methods
            .OrderByDescending(x => x.IsSelectedByDefault)
            .ThenByDescending(x => x.IsRecommended)
            .ThenBy(x => x.Provider, StringComparer.Ordinal)
            .ToList();
    }

    private static PaywallLegalTextsResponse BuildPaywallLegalTexts()
    {
        return new PaywallLegalTextsResponse(
            "Payments for in-app subscriptions are processed by Apple App Store or Google Play. You can manage or cancel the subscription in your store account settings.",
            "External checkout opens a secure billing flow outside the store. Premium activates after verification, and additional disclosures may apply in your region.",
            "Stripe checkout and customer portal are secure. PetMagic does not store raw card details and subscription management stays available inside PetMagic settings.");
    }

    private async Task<UserSubscription?> GetLatestUserSubscriptionAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<UserSubscription> UpsertUserSubscriptionAsync(
        Guid userId,
        string provider,
        string purchaseChannel,
        string region,
        string planId,
        string status,
        string? externalCustomerId,
        string? externalSubscriptionId,
        string? externalTransactionId,
        DateTime? currentPeriodStartUtc,
        DateTime? currentPeriodEndUtc,
        bool cancelAtPeriodEnd,
        int monthlyTokenLimit,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var subscription = await dbContext.UserSubscriptions.FirstOrDefaultAsync(
            x => x.UserId == userId
                && ((!string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.ExternalSubscriptionId == externalSubscriptionId)
                    || (string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.PlanId == planId)),
            cancellationToken);

        var normalizedStatus = status.Trim();
        var previousPeriodStartUtc = subscription?.CurrentPeriodStartUtc;
        var previousTokensGranted = subscription?.MonthlyTokensGranted ?? 0;

        if (subscription is null)
        {
            subscription = new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = provider,
                CreatedAtUtc = now
            };

            dbContext.UserSubscriptions.Add(subscription);
        }

        subscription.PurchaseChannel = purchaseChannel;
        subscription.Region = region;
        subscription.PlanId = planId;
        subscription.Status = normalizedStatus;
        subscription.ExternalCustomerId = externalCustomerId ?? subscription.ExternalCustomerId;
        subscription.ExternalSubscriptionId = externalSubscriptionId ?? subscription.ExternalSubscriptionId;
        subscription.ExternalTransactionId = externalTransactionId ?? subscription.ExternalTransactionId;

        if (currentPeriodStartUtc.HasValue
            && (!previousPeriodStartUtc.HasValue || currentPeriodStartUtc.Value > previousPeriodStartUtc.Value))
        {
            subscription.MonthlyTokensGranted = 0;
            subscription.LastTokenGrantAtUtc = null;
        }

        subscription.CurrentPeriodStartUtc = currentPeriodStartUtc ?? subscription.CurrentPeriodStartUtc;
        subscription.CurrentPeriodEndUtc = currentPeriodEndUtc ?? subscription.CurrentPeriodEndUtc;
        subscription.CancelAtPeriodEnd = cancelAtPeriodEnd;
        subscription.MonthlyTokenLimit = monthlyTokenLimit;
        subscription.UpdatedAtUtc = now;

        if (ShouldGrantSubscriptionTokens(subscription, previousPeriodStartUtc, previousTokensGranted))
        {
            var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
            ApplyWalletDelta(
                wallet,
                monthlyTokenLimit,
                WalletLedgerSource.PremiumSubscriptionGrant,
                $"subscription:{provider}:{planId}",
                now);
            subscription.MonthlyTokensGranted += monthlyTokenLimit;
            subscription.LastTokenGrantAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return subscription;
    }

    private async Task AppendSubscriptionEventAsync(
        Guid userId,
        Guid subscriptionId,
        string provider,
        string eventType,
        string status,
        string? externalEventId,
        string? externalSubscriptionId,
        string? payloadJson,
        CancellationToken cancellationToken)
    {
        dbContext.SubscriptionEventLogs.Add(new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscriptionId,
            Provider = provider,
            EventType = eventType,
            Status = status,
            ExternalEventId = externalEventId,
            ExternalSubscriptionId = externalSubscriptionId,
            PayloadJson = payloadJson,
            CreatedAtUtc = DateTime.UtcNow,
            ProcessedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static bool IsActivePremiumSubscription(UserSubscription? subscription)
    {
        if (subscription is null)
        {
            return false;
        }

        var status = subscription.Status;
        if (!string.Equals(status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "GracePeriod", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc >= DateTime.UtcNow;
    }

    private static string GetManageSubscriptionAction(string? provider)
    {
        return provider switch
        {
            "app_store" => "AppleSettings",
            "google_play" => "GooglePlaySettings",
            "stripe" => "StripeCustomerPortal",
            _ => "None"
        };
    }

    private async Task<ResolvedPremiumPlan?> ResolveConfiguredPremiumPlanAsync(string? planCode, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(planCode))
        {
            return null;
        }

        var normalizedPlanCode = planCode.Trim().ToLowerInvariant();
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == normalizedPlanCode && x.IsActive, cancellationToken);

        if (configuredPlan is not null)
        {
            return new ResolvedPremiumPlan(
                configuredPlan.Id,
                configuredPlan.Name,
                ToStripeBillingInterval(configuredPlan.BillingPeriod),
                configuredPlan.BillingPeriod,
                configuredPlan.PriceAmount,
                configuredPlan.CurrencyCode,
                configuredPlan.MonthlyTokenLimit,
                configuredPlan.GoogleProductId,
                configuredPlan.AppleProductId);
        }

        var catalogPlan = PremiumPlanCatalog.Find(normalizedPlanCode);
        if (catalogPlan is null)
        {
            return null;
        }

        return new ResolvedPremiumPlan(
            catalogPlan.PlanCode,
            catalogPlan.ProductName,
            catalogPlan.BillingInterval,
            catalogPlan.BillingInterval == "year" ? "yearly" : "monthly",
            catalogPlan.PriceAmount,
            catalogPlan.CurrencyCode,
            catalogPlan.TokenAllowance,
            catalogPlan.GooglePlayProductId,
            catalogPlan.AppStoreProductId);
    }

    private async Task<(ResolvedPremiumPlan? Plan, UserSubscription? ExistingSubscription)> ResolveStripePlanContextAsync(
        Guid userId,
        string? planCode,
        string? subscriptionId,
        CancellationToken cancellationToken)
    {
        UserSubscription? existingSubscription = null;
        if (!string.IsNullOrWhiteSpace(subscriptionId))
        {
            existingSubscription = await dbContext.UserSubscriptions
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == userId && x.Provider == "stripe" && x.ExternalSubscriptionId == subscriptionId,
                    cancellationToken);
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(planCode, cancellationToken);
        if (plan is null && !string.IsNullOrWhiteSpace(existingSubscription?.PlanId))
        {
            plan = await ResolveConfiguredPremiumPlanAsync(existingSubscription.PlanId, cancellationToken);
        }

        return (plan, existingSubscription);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoreNotificationPlanAsync(
        string? existingPlanId,
        string? productId,
        string provider,
        CancellationToken cancellationToken)
    {
        var plan = await ResolveStoredPremiumPlanAsync(existingPlanId, cancellationToken);
        if (plan is not null)
        {
            return plan;
        }

        if (string.IsNullOrWhiteSpace(productId))
        {
            return null;
        }

        var normalizedProductId = productId.Trim();
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => provider == "app_store"
                    ? x.AppleProductId == normalizedProductId
                    : x.GoogleProductId == normalizedProductId,
                cancellationToken);

        if (configuredPlan is not null)
        {
            return ToResolvedPremiumPlan(configuredPlan);
        }

        var catalogPlan = PremiumPlanCatalog.All.FirstOrDefault(
            x => string.Equals(
                provider == "app_store" ? x.AppStoreProductId : x.GooglePlayProductId,
                normalizedProductId,
                StringComparison.Ordinal));

        return catalogPlan is null ? null : ToResolvedPremiumPlan(catalogPlan);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoredPremiumPlanAsync(string? planCode, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(planCode))
        {
            return null;
        }

        var normalizedPlanCode = planCode.Trim().ToLowerInvariant();
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == normalizedPlanCode, cancellationToken);

        if (configuredPlan is not null)
        {
            return ToResolvedPremiumPlan(configuredPlan);
        }

        var catalogPlan = PremiumPlanCatalog.Find(normalizedPlanCode);
        return catalogPlan is null ? null : ToResolvedPremiumPlan(catalogPlan);
    }

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(SubscriptionPlan configuredPlan)
    {
        return new ResolvedPremiumPlan(
            configuredPlan.Id,
            configuredPlan.Name,
            ToStripeBillingInterval(configuredPlan.BillingPeriod),
            configuredPlan.BillingPeriod,
            configuredPlan.PriceAmount,
            configuredPlan.CurrencyCode,
            configuredPlan.MonthlyTokenLimit,
            configuredPlan.GoogleProductId,
            configuredPlan.AppleProductId);
    }

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(PremiumPlanDefinition catalogPlan)
    {
        return new ResolvedPremiumPlan(
            catalogPlan.PlanCode,
            catalogPlan.ProductName,
            catalogPlan.BillingInterval,
            catalogPlan.BillingInterval == "year" ? "yearly" : "monthly",
            catalogPlan.PriceAmount,
            catalogPlan.CurrencyCode,
            catalogPlan.TokenAllowance,
            catalogPlan.GooglePlayProductId,
            catalogPlan.AppStoreProductId);
    }

    private static string ToStripeBillingInterval(string billingPeriod)
    {
        return string.Equals(billingPeriod, "yearly", StringComparison.OrdinalIgnoreCase)
            ? "year"
            : "month";
    }

    private static DateTime DeriveCurrentPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime fallbackUtc)
    {
        if (!currentPeriodEndUtc.HasValue)
        {
            return fallbackUtc;
        }

        return string.Equals(billingPeriod, "yearly", StringComparison.OrdinalIgnoreCase)
            ? currentPeriodEndUtc.Value.AddYears(-1)
            : currentPeriodEndUtc.Value.AddMonths(-1);
    }

    private static bool ShouldGrantSubscriptionTokens(
        UserSubscription subscription,
        DateTime? previousPeriodStartUtc,
        int previousTokensGranted)
    {
        if (subscription.MonthlyTokenLimit <= 0)
        {
            return false;
        }

        if (!string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(subscription.Status, "GracePeriod", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (subscription.LastTokenGrantAtUtc is null && previousTokensGranted <= 0)
        {
            return true;
        }

        return subscription.CurrentPeriodStartUtc.HasValue
            && (!previousPeriodStartUtc.HasValue || subscription.CurrentPeriodStartUtc.Value > previousPeriodStartUtc.Value)
            && subscription.MonthlyTokensGranted < subscription.MonthlyTokenLimit;
    }

    private static PaymentProviderConfiguration? SelectProviderConfig(
        IEnumerable<PaymentProviderConfiguration> configs,
        string provider,
        string platform,
        string region,
        bool isEuRegion,
        string appVersion)
    {
        return configs
            .Where(x => string.Equals(x.Provider, provider, StringComparison.OrdinalIgnoreCase)
                && string.Equals(x.Platform, platform, StringComparison.OrdinalIgnoreCase)
                && MatchesRegion(x.Region, region, isEuRegion)
                && IsAppVersionAllowed(x.AllowedFromAppVersion, appVersion))
            .OrderByDescending(x => string.Equals(x.Region, region, StringComparison.OrdinalIgnoreCase))
            .ThenByDescending(x => string.Equals(x.Region, "EU", StringComparison.OrdinalIgnoreCase) && isEuRegion)
            .ThenByDescending(x => string.Equals(x.Region, "*", StringComparison.OrdinalIgnoreCase))
            .FirstOrDefault();
    }

    private async Task<bool> IsPaymentProviderAllowedAsync(
        string provider,
        string platform,
        string country,
        string appVersion,
        CancellationToken cancellationToken)
    {
        var normalizedPlatform = NormalizePlatform(platform);
        var normalizedRegion = NormalizeRegion(country);
        var isEuRegion = IsEuRegion(normalizedRegion);
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var config = SelectProviderConfig(configs, provider, normalizedPlatform, normalizedRegion, isEuRegion, appVersion);
        if (config is null)
        {
            return false;
        }

        return string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            ? string.Equals(normalizedPlatform, "web", StringComparison.Ordinal) || config.ExternalCheckoutAllowed
            : true;
    }

    private static bool MatchesRegion(string configuredRegion, string region, bool isEuRegion)
    {
        return string.Equals(configuredRegion, "*", StringComparison.OrdinalIgnoreCase)
            || string.Equals(configuredRegion, region, StringComparison.OrdinalIgnoreCase)
            || (isEuRegion && string.Equals(configuredRegion, "EU", StringComparison.OrdinalIgnoreCase));
    }

    private static DateTime? ResolveNotificationPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime? fallbackPeriodStartUtc)
    {
        if (currentPeriodEndUtc.HasValue)
        {
            return DeriveCurrentPeriodStartUtc(billingPeriod, currentPeriodEndUtc, currentPeriodEndUtc.Value);
        }

        return fallbackPeriodStartUtc;
    }

    private static bool IsStoreSubscriptionPremium(string status, DateTime? currentPeriodEndUtc)
    {
        if (!string.Equals(status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "GracePeriod", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return currentPeriodEndUtc is null || currentPeriodEndUtc >= DateTime.UtcNow;
    }

    private static string MapAppStoreNotificationStatus(string? notificationType, string? subtype, DateTime? expiresAtUtc)
    {
        if (string.Equals(notificationType, "EXPIRED", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "REFUND", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "REVOKE", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "GRACE_PERIOD_EXPIRED", StringComparison.OrdinalIgnoreCase))
        {
            return "Expired";
        }

        if (string.Equals(notificationType, "DID_FAIL_TO_RENEW", StringComparison.OrdinalIgnoreCase))
        {
            return expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow ? "GracePeriod" : "Expired";
        }

        if (string.Equals(notificationType, "DID_CHANGE_RENEWAL_STATUS", StringComparison.OrdinalIgnoreCase)
            && string.Equals(subtype, "AUTO_RENEW_DISABLED", StringComparison.OrdinalIgnoreCase))
        {
            return expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow ? "Canceled" : "Expired";
        }

        return expiresAtUtc.HasValue && expiresAtUtc.Value <= DateTime.UtcNow ? "Expired" : "Active";
    }

    private static string MapGooglePlayNotificationStatus(int notificationType, string providerStatus, bool isActive)
    {
        return notificationType switch
        {
            3 => isActive ? "Canceled" : "Expired",
            5 or 6 => "GracePeriod",
            12 or 13 => "Expired",
            _ => MapStoreSubscriptionStatus(providerStatus, isActive)
        };
    }

    private static (bool Success, string? EventId, string? NotificationType, string? Subtype, string? ProductId, string? ExternalSubscriptionId, string? ExternalPurchaseId, DateTime? ExpiresAtUtc, bool CancelAtPeriodEnd) ParseAppStoreServerNotification(string signedPayload)
    {
        try
        {
            using var rootDocument = JsonDocument.Parse(DecodeJwsPayloadJson(signedPayload));
            var root = rootDocument.RootElement;
            var eventId = root.TryGetProperty("notificationUUID", out var eventIdElement) && eventIdElement.ValueKind == JsonValueKind.String
                ? eventIdElement.GetString()
                : null;
            var notificationType = root.TryGetProperty("notificationType", out var typeElement) && typeElement.ValueKind == JsonValueKind.String
                ? typeElement.GetString()
                : null;
            var subtype = root.TryGetProperty("subtype", out var subtypeElement) && subtypeElement.ValueKind == JsonValueKind.String
                ? subtypeElement.GetString()
                : null;

            string? productId = null;
            string? externalSubscriptionId = null;
            string? externalPurchaseId = null;
            DateTime? expiresAtUtc = null;
            var cancelAtPeriodEnd = string.Equals(subtype, "AUTO_RENEW_DISABLED", StringComparison.OrdinalIgnoreCase);

            if (root.TryGetProperty("data", out var dataElement) && dataElement.ValueKind == JsonValueKind.Object)
            {
                if (dataElement.TryGetProperty("signedTransactionInfo", out var transactionInfoElement)
                    && transactionInfoElement.ValueKind == JsonValueKind.String)
                {
                    using var transactionDocument = JsonDocument.Parse(DecodeJwsPayloadJson(transactionInfoElement.GetString()!));
                    var transaction = transactionDocument.RootElement;
                    productId = transaction.TryGetProperty("productId", out var productElement) && productElement.ValueKind == JsonValueKind.String
                        ? productElement.GetString()
                        : null;
                    externalSubscriptionId = transaction.TryGetProperty("originalTransactionId", out var originalElement) && originalElement.ValueKind == JsonValueKind.String
                        ? originalElement.GetString()
                        : null;
                    externalPurchaseId = transaction.TryGetProperty("transactionId", out var transactionIdElement) && transactionIdElement.ValueKind == JsonValueKind.String
                        ? transactionIdElement.GetString()
                        : null;
                    expiresAtUtc = transaction.TryGetProperty("expiresDate", out var expiresElement)
                        ? ParseUnixMilliseconds(expiresElement)
                        : null;
                }

                if (dataElement.TryGetProperty("signedRenewalInfo", out var renewalInfoElement)
                    && renewalInfoElement.ValueKind == JsonValueKind.String)
                {
                    using var renewalDocument = JsonDocument.Parse(DecodeJwsPayloadJson(renewalInfoElement.GetString()!));
                    var renewal = renewalDocument.RootElement;
                    if (renewal.TryGetProperty("autoRenewStatus", out var autoRenewElement))
                    {
                        var autoRenewDisabled = autoRenewElement.ValueKind switch
                        {
                            JsonValueKind.Number => autoRenewElement.GetInt32() == 0,
                            JsonValueKind.String => autoRenewElement.GetString() == "0",
                            _ => false
                        };

                        cancelAtPeriodEnd = cancelAtPeriodEnd || autoRenewDisabled;
                    }
                }
            }

            return (!string.IsNullOrWhiteSpace(eventId), eventId, notificationType, subtype, productId, externalSubscriptionId, externalPurchaseId, expiresAtUtc, cancelAtPeriodEnd);
        }
        catch
        {
            return (false, null, null, null, null, null, null, null, false);
        }
    }

    private static (bool Success, string? EventId, int NotificationType, string? ProductId, string? PurchaseToken) ParseGooglePlayDeveloperNotification(string messageData, string? messageId)
    {
        try
        {
            var payloadBytes = Convert.FromBase64String(PadBase64(messageData));
            using var document = JsonDocument.Parse(payloadBytes);
            var root = document.RootElement;

            if (!root.TryGetProperty("subscriptionNotification", out var subscriptionElement)
                || subscriptionElement.ValueKind != JsonValueKind.Object)
            {
                return (false, null, 0, null, null);
            }

            var productId = subscriptionElement.TryGetProperty("subscriptionId", out var productElement) && productElement.ValueKind == JsonValueKind.String
                ? productElement.GetString()
                : null;
            var purchaseToken = subscriptionElement.TryGetProperty("purchaseToken", out var tokenElement) && tokenElement.ValueKind == JsonValueKind.String
                ? tokenElement.GetString()
                : null;
            var notificationType = subscriptionElement.TryGetProperty("notificationType", out var typeElement) && typeElement.ValueKind == JsonValueKind.Number
                ? typeElement.GetInt32()
                : 0;

            var eventId = !string.IsNullOrWhiteSpace(messageId)
                ? messageId
                : $"{purchaseToken}:{notificationType}";

            return (!string.IsNullOrWhiteSpace(productId) && !string.IsNullOrWhiteSpace(purchaseToken), eventId, notificationType, productId, purchaseToken);
        }
        catch
        {
            return (false, null, 0, null, null);
        }
    }

    private static string DecodeJwsPayloadJson(string signedPayload)
    {
        var parts = signedPayload.Split('.');
        if (parts.Length < 2)
        {
            throw new InvalidOperationException("Invalid JWS payload.");
        }

        return Encoding.UTF8.GetString(DecodeBase64Url(parts[1]));
    }

    private static byte[] DecodeBase64Url(string value)
    {
        return Convert.FromBase64String(PadBase64(value.Replace('-', '+').Replace('_', '/')));
    }

    private static string PadBase64(string value)
    {
        var remainder = value.Length % 4;
        return remainder == 0 ? value : value.PadRight(value.Length + (4 - remainder), '=');
    }

    private static DateTime? ParseUnixMilliseconds(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.String && long.TryParse(element.GetString(), out var stringValue))
        {
            return DateTimeOffset.FromUnixTimeMilliseconds(stringValue).UtcDateTime;
        }

        if (element.ValueKind == JsonValueKind.Number && element.TryGetInt64(out var numericValue))
        {
            return DateTimeOffset.FromUnixTimeMilliseconds(numericValue).UtcDateTime;
        }

        return null;
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static string NormalizeConfigRegion(string value)
    {
        var normalized = value.Trim();
        return string.Equals(normalized, "*", StringComparison.Ordinal) ? "*" : normalized.ToUpperInvariant();
    }

    private sealed record ResolvedPremiumPlan(
        string PlanCode,
        string ProductName,
        string BillingInterval,
        string BillingPeriod,
        decimal PriceAmount,
        string CurrencyCode,
        int MonthlyTokenLimit,
        string? GoogleProductId,
        string? AppleProductId);

    private static bool IsAppVersionAllowed(string configuredVersion, string appVersion)
    {
        if (!Version.TryParse(configuredVersion, out var minimumVersion))
        {
            return true;
        }

        if (!Version.TryParse(appVersion, out var currentVersion))
        {
            return true;
        }

        return currentVersion >= minimumVersion;
    }

    private static string NormalizePlatform(string platform)
    {
        var normalized = platform.Trim().ToLowerInvariant();
        return normalized switch
        {
            "iphone" => "ios",
            "ipad" => "ios",
            _ => normalized
        };
    }

    private static string NormalizeRegion(string region)
    {
        return string.IsNullOrWhiteSpace(region) ? "*" : region.Trim().ToUpperInvariant();
    }

    private static bool IsEuRegion(string region)
    {
        return region is "AT" or "BE" or "BG" or "HR" or "CY" or "CZ" or "DK" or "EE" or "FI" or "FR"
            or "DE" or "GR" or "HU" or "IE" or "IT" or "LV" or "LT" or "LU" or "MT" or "NL"
            or "PL" or "PT" or "RO" or "SK" or "SI" or "ES" or "SE";
    }

    private static string MapStoreSubscriptionStatus(string providerStatus, bool isActive)
    {
        if (!isActive)
        {
            return "Expired";
        }

        return providerStatus.Contains("GRACE", StringComparison.OrdinalIgnoreCase)
            ? "GracePeriod"
            : "Active";
    }

    private static string MapStripeSubscriptionStatus(string? providerStatus)
    {
        if (string.Equals(providerStatus, "trialing", StringComparison.OrdinalIgnoreCase))
        {
            return "Trialing";
        }

        if (string.Equals(providerStatus, "past_due", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "unpaid", StringComparison.OrdinalIgnoreCase))
        {
            return "PastDue";
        }

        if (string.Equals(providerStatus, "canceled", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "cancelled", StringComparison.OrdinalIgnoreCase))
        {
            return "Canceled";
        }

        return "Active";
    }

    private static (bool Success, Guid? OrderId, Guid? UserId, string? ObjectId, string? Purpose, string? SetupIntentId, string? Status, string? PlanCode, string? SubscriptionId, string? CustomerId, DateTime? CurrentPeriodStartUtc, DateTime? CurrentPeriodEndUtc, bool CancelAtPeriodEnd) ParseStripeEvent(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("data", out var dataElement)
                || dataElement.ValueKind != JsonValueKind.Object
                || !dataElement.TryGetProperty("object", out var objectElement)
                || objectElement.ValueKind != JsonValueKind.Object)
            {
                return (false, null, null, null, null, null, null, null, null, null, null, null, false);
            }

            string? objectId = null;
            if (objectElement.TryGetProperty("id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
            {
                objectId = idElement.GetString();
            }

            string? setupIntentId = null;
            if (objectElement.TryGetProperty("setup_intent", out var setupIntentElement) && setupIntentElement.ValueKind == JsonValueKind.String)
            {
                setupIntentId = setupIntentElement.GetString();
            }

            string? status = null;
            if (objectElement.TryGetProperty("status", out var statusElement) && statusElement.ValueKind == JsonValueKind.String)
            {
                status = statusElement.GetString();
            }

            string? customerId = null;
            if (objectElement.TryGetProperty("customer", out var customerElement) && customerElement.ValueKind == JsonValueKind.String)
            {
                customerId = customerElement.GetString();
            }

            string? subscriptionId = null;
            if (objectElement.TryGetProperty("subscription", out var subscriptionElement) && subscriptionElement.ValueKind == JsonValueKind.String)
            {
                subscriptionId = subscriptionElement.GetString();
            }
            else if (string.Equals(objectElement.GetProperty("object").GetString(), "subscription", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(objectId))
            {
                subscriptionId = objectId;
            }

            DateTime? currentPeriodStartUtc = null;
            if (objectElement.TryGetProperty("current_period_start", out var currentPeriodStartElement)
                && currentPeriodStartElement.TryGetInt64(out var currentPeriodStartUnix))
            {
                currentPeriodStartUtc = DateTimeOffset.FromUnixTimeSeconds(currentPeriodStartUnix).UtcDateTime;
            }

            DateTime? currentPeriodEndUtc = null;
            if (objectElement.TryGetProperty("current_period_end", out var currentPeriodEndElement)
                && currentPeriodEndElement.TryGetInt64(out var currentPeriodEndUnix))
            {
                currentPeriodEndUtc = DateTimeOffset.FromUnixTimeSeconds(currentPeriodEndUnix).UtcDateTime;
            }

            var cancelAtPeriodEnd = false;
            if (objectElement.TryGetProperty("cancel_at_period_end", out var cancelAtPeriodEndElement)
                && (cancelAtPeriodEndElement.ValueKind == JsonValueKind.True || cancelAtPeriodEndElement.ValueKind == JsonValueKind.False))
            {
                cancelAtPeriodEnd = cancelAtPeriodEndElement.GetBoolean();
            }

            Guid? orderId = null;
            Guid? userId = null;
            string? purpose = null;
            string? planCode = null;
            if (objectElement.TryGetProperty("metadata", out var metadataElement)
                && metadataElement.ValueKind == JsonValueKind.Object)
            {
                if (metadataElement.TryGetProperty("order_id", out var orderIdElement)
                    && orderIdElement.ValueKind == JsonValueKind.String)
                {
                    var rawOrderId = orderIdElement.GetString();
                    if (Guid.TryParse(rawOrderId, out var parsedOrderId))
                    {
                        orderId = parsedOrderId;
                    }
                }

                if (metadataElement.TryGetProperty("user_id", out var userIdElement)
                    && userIdElement.ValueKind == JsonValueKind.String)
                {
                    var rawUserId = userIdElement.GetString();
                    if (Guid.TryParse(rawUserId, out var parsedUserId))
                    {
                        userId = parsedUserId;
                    }
                }

                if (metadataElement.TryGetProperty("purpose", out var purposeElement)
                    && purposeElement.ValueKind == JsonValueKind.String)
                {
                    purpose = purposeElement.GetString();
                }

                if (metadataElement.TryGetProperty("plan_code", out var planCodeElement)
                    && planCodeElement.ValueKind == JsonValueKind.String)
                {
                    planCode = planCodeElement.GetString();
                }
            }

            return (true, orderId, userId, objectId, purpose, setupIntentId, status, planCode, subscriptionId, customerId, currentPeriodStartUtc, currentPeriodEndUtc, cancelAtPeriodEnd);
        }
        catch
        {
            var orderIdMatch = Regex.Match(rawBody, "\"order_id\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant);
            Guid? orderId = null;
            if (orderIdMatch.Success)
            {
                var rawOrderId = orderIdMatch.Groups["value"].Value;
                if (Guid.TryParse(rawOrderId, out var parsedOrderId))
                {
                    orderId = parsedOrderId;
                }
            }

            string? objectId = null;
            var objectIdMatch = Regex.Match(
                rawBody,
                "\"data\"\\s*:\\s*\\{\\s*\"object\"\\s*:\\s*\\{.*?\"id\"\\s*:\\s*\"(?<value>[^\"]+)\"",
                RegexOptions.CultureInvariant | RegexOptions.Singleline);

            if (objectIdMatch.Success)
            {
                objectId = objectIdMatch.Groups["value"].Value;
            }

            if (!orderId.HasValue && string.IsNullOrWhiteSpace(objectId))
            {
                return (false, null, null, null, null, null, null, null, null, null, null, null, false);
            }

            return (true, orderId, null, objectId, null, null, null, null, null, null, null, null, false);
        }
    }

    private static (bool Success, string? EventId, string? EventType) ParseStripeEnvelope(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("id", out var idElement)
                || idElement.ValueKind != JsonValueKind.String
                || !root.TryGetProperty("type", out var typeElement)
                || typeElement.ValueKind != JsonValueKind.String)
            {
                return (false, null, null);
            }

            var eventId = idElement.GetString();
            var eventType = typeElement.GetString();
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
        catch
        {
            var idMatch = Regex.Match(rawBody, "\"id\"\\s*:\\s*\"(?<value>evt_[^\"]+)\"", RegexOptions.CultureInvariant);
            var typeMatch = Regex.Match(rawBody, "\"type\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant);

            if (!idMatch.Success || !typeMatch.Success)
            {
                return (false, null, null);
            }

            var eventId = idMatch.Groups["value"].Value;
            var eventType = typeMatch.Groups["value"].Value;
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
    }

    private static bool VerifyStripeSignatureFallback(string rawBody, string signatureHeader, string secret)
    {
        if (string.IsNullOrWhiteSpace(signatureHeader) || string.IsNullOrWhiteSpace(secret))
        {
            return false;
        }

        string? timestamp = null;
        string? expectedSignature = null;

        var parts = signatureHeader.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var part in parts)
        {
            if (part.StartsWith("t=", StringComparison.Ordinal))
            {
                timestamp = part[2..];
            }
            else if (part.StartsWith("v1=", StringComparison.Ordinal))
            {
                expectedSignature = part[3..];
            }
        }

        if (string.IsNullOrWhiteSpace(timestamp) || string.IsNullOrWhiteSpace(expectedSignature))
        {
            return false;
        }

        var signedPayload = $"{timestamp}.{rawBody}";
        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var payloadBytes = Encoding.UTF8.GetBytes(signedPayload);

        using var hmac = new HMACSHA256(keyBytes);
        var computed = Convert.ToHexString(hmac.ComputeHash(payloadBytes)).ToLowerInvariant();
        return string.Equals(computed, expectedSignature, StringComparison.OrdinalIgnoreCase);
    }
}
