using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
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
    IIdentityService? identityService = null,
    ILogger<EconomyService>? logger = null) : IEconomyService
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
        var source = string.IsNullOrWhiteSpace(command.Source)
            ? WalletLedgerSource.GenerationSpend
            : command.Source;
        var response = ApplyWalletDelta(wallet, -command.Amount, source, command.Reason, now);
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

        if (redeemCode.MinimumSuccessfulPurchases > 0)
        {
            var successfulPurchases = await dbContext.PurchaseOrders
                .AsNoTracking()
                .CountAsync(
                    x => x.UserId == command.UserId
                        && x.Status == PurchaseOrderStatus.Succeeded,
                    cancellationToken);

            if (successfulPurchases < redeemCode.MinimumSuccessfulPurchases)
            {
                return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodePurchaseRequirementNotMet);
            }
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

    public async Task<Result<RewardsSummaryResponse>> GetRewardsSummaryAsync(Guid userId, CancellationToken cancellationToken)
    {
        var profile = await GetOrCreateReferralProfileAsync(userId, cancellationToken);
        var activatedReferral = await dbContext.ReferralAttributions
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.RefereeUserId == userId, cancellationToken);

        var referredUsers = await dbContext.ReferralAttributions
            .AsNoTracking()
            .Where(x => x.ReferrerUserId == userId)
            .ToListAsync(cancellationToken);

        var rewarded = referredUsers
            .Where(x => string.Equals(x.Status, ReferralAttributionStatus.Rewarded, StringComparison.Ordinal))
            .ToList();

        return Result.Success(new RewardsSummaryResponse(
            profile.Code,
            options.Value.ReferralBonusSpark,
            activatedReferral?.Status ?? "none",
            activatedReferral?.ReferrerCode,
            activatedReferral?.CreatedAtUtc,
            activatedReferral?.QualifiedAtUtc,
            rewarded.Sum(x => x.RewardSpark),
            referredUsers.Count,
            referredUsers.Count(x => string.Equals(x.Status, ReferralAttributionStatus.Pending, StringComparison.Ordinal)),
            rewarded.Count));
    }

    public async Task<Result<ReferralCodeAppliedResponse>> ApplyReferralCodeAsync(ApplyReferralCodeCommand command, CancellationToken cancellationToken)
    {
        var normalizedCode = NormalizeReferralCode(command.Code);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralCodeNotFound);
        }

        var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
            : null;

        var referrerProfile = await dbContext.ReferralProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Code == normalizedCode, cancellationToken);

        if (referrerProfile is null)
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralCodeNotFound);
        }

        if (referrerProfile.UserId == command.UserId)
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralSelfReferral);
        }

        var alreadyLinked = await dbContext.ReferralAttributions
            .AnyAsync(x => x.RefereeUserId == command.UserId, cancellationToken);
        if (alreadyLinked)
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralAlreadyLinked);
        }

        if (await HasCompletedPaidTransactionAsync(command.UserId, cancellationToken))
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralPaidUserIneligible);
        }

        var now = DateTime.UtcNow;
        dbContext.ReferralAttributions.Add(new ReferralAttribution
        {
            Id = Guid.NewGuid(),
            ReferrerUserId = referrerProfile.UserId,
            RefereeUserId = command.UserId,
            ReferrerCode = referrerProfile.Code,
            Status = ReferralAttributionStatus.Pending,
            RewardSpark = options.Value.ReferralBonusSpark,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(new ReferralCodeAppliedResponse(
            referrerProfile.Code,
            ReferralAttributionStatus.Pending,
            options.Value.ReferralBonusSpark,
            now));
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

        configuration.Region = EconomyPaymentProviderPolicy.NormalizeConfigRegion(command.Region);
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

    public async Task<Result<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>> GetAdminRedeemCodeActivationsAsync(
        Guid redeemCodeId,
        int skip,
        int take,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var codeExists = await dbContext.RedeemCodes
            .AsNoTracking()
            .AnyAsync(x => x.Id == redeemCodeId, cancellationToken);

        if (!codeExists)
        {
            return Result.Failure<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>(EconomyErrors.RedeemCodeNotFound);
        }

        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 20, 200);

        var query = dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => x.RedeemCodeId == redeemCodeId)
            .AsQueryable();

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        var items = await query
            .OrderByDescending(x => x.RedeemedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new AdminRedeemCodeRedemptionResponse(
                x.Id,
                x.UserId,
                x.RewardKind,
                x.RewardValue,
                x.WalletLedgerEntryId,
                x.PremiumExpiresAtUtc,
                x.RedeemedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
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
            CampaignName = NullIfWhiteSpace(command.CampaignName),
            CampaignChannel = NullIfWhiteSpace(command.CampaignChannel),
            MinimumSuccessfulPurchases = command.MinimumSuccessfulPurchases,
            CreatedBy = NullIfWhiteSpace(command.CreatedBy),
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
        code.CampaignName = NullIfWhiteSpace(command.CampaignName);
        code.CampaignChannel = NullIfWhiteSpace(command.CampaignChannel);
        code.MinimumSuccessfulPurchases = command.MinimumSuccessfulPurchases;
        code.CreatedBy = NullIfWhiteSpace(command.CreatedBy);
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
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Stripe SDK signature verification failed. Falling back to manual signature validation.");

            if (!EconomyWebhookParser.VerifyStripeSignatureFallback(command.RawBody, command.StripeSignature, options.Value.StripeWebhookSecret))
            {
                return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidStripeSignature);
            }

            var envelope = EconomyWebhookParser.ParseStripeEnvelope(command.RawBody);
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

        var parsedEvent = EconomyWebhookParser.ParseStripeEvent(command.RawBody);
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

                    await SettlePendingReferralBonusAsync(
                        parsedEvent.UserId.Value,
                        $"premium:stripe:{subscription.PlanId}",
                        DateTime.UtcNow,
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
                        ? (parsedEvent.CancelAtPeriodEnd ? "Canceled" : EconomyWebhookParser.MapStripeSubscriptionStatus(parsedEvent.Status))
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
        var parsed = EconomyWebhookParser.ParseAppStoreServerNotification(command.SignedPayload);
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

        var status = EconomyWebhookParser.MapAppStoreNotificationStatus(parsed.NotificationType, parsed.Subtype, parsed.ExpiresAtUtc);
        var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, parsed.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

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
        var parsed = EconomyWebhookParser.ParseGooglePlayDeveloperNotification(command.MessageData, command.MessageId);
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

        var status = EconomyWebhookParser.MapGooglePlayNotificationStatus(parsed.NotificationType, verification.Value.Status, verification.Value.IsActive);
        var cancelAtPeriodEnd = parsed.NotificationType == 3;
        var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, verification.Value.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

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

    private async Task<ReferralProfile> GetOrCreateReferralProfileAsync(Guid userId, CancellationToken cancellationToken)
    {
        var profile = await dbContext.ReferralProfiles.FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (profile is not null)
        {
            return profile;
        }

        var now = DateTime.UtcNow;
        profile = new ReferralProfile
        {
            UserId = userId,
            Code = await GenerateUniqueReferralCodeAsync(cancellationToken),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.ReferralProfiles.Add(profile);
        await dbContext.SaveChangesAsync(cancellationToken);
        return profile;
    }

    private async Task<string> GenerateUniqueReferralCodeAsync(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 20; attempt++)
        {
            var code = GenerateReferralCode();
            if (!await dbContext.ReferralProfiles.AnyAsync(x => x.Code == code, cancellationToken))
            {
                return code;
            }
        }

        return $"PM{Guid.NewGuid():N}"[..12].ToUpperInvariant();
    }

    private static string GenerateReferralCode()
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        Span<byte> bytes = stackalloc byte[8];
        RandomNumberGenerator.Fill(bytes);

        var builder = new StringBuilder("PM", 10);
        foreach (var value in bytes)
        {
            builder.Append(alphabet[value % alphabet.Length]);
        }

        return builder.ToString();
    }

    private async Task<bool> HasCompletedPaidTransactionAsync(Guid userId, CancellationToken cancellationToken)
    {
        var hasSucceededPackPurchase = await dbContext.PurchaseOrders
            .AsNoTracking()
            .AnyAsync(x => x.UserId == userId && x.Status == PurchaseOrderStatus.Succeeded, cancellationToken);
        if (hasSucceededPackPurchase)
        {
            return true;
        }

        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .AnyAsync(x => x.UserId == userId, cancellationToken);
    }

    private async Task SettlePendingReferralBonusAsync(Guid refereeUserId, string triggerReason, DateTime now, CancellationToken cancellationToken)
    {
        var referral = await dbContext.ReferralAttributions
            .FirstOrDefaultAsync(
                x => x.RefereeUserId == refereeUserId
                    && x.Status == ReferralAttributionStatus.Pending,
                cancellationToken);

        if (referral is null)
        {
            return;
        }

        var referrerWallet = await GetOrCreateWalletAsync(referral.ReferrerUserId, cancellationToken);
        var refereeWallet = await GetOrCreateWalletAsync(referral.RefereeUserId, cancellationToken);
        var rewardSpark = referral.RewardSpark > 0 ? referral.RewardSpark : options.Value.ReferralBonusSpark;

        ApplyWalletDelta(
            referrerWallet,
            rewardSpark,
            WalletLedgerSource.ReferralBonus,
            $"referral:inviter:{referral.RefereeUserId:D}:{triggerReason}",
            now,
            out var referrerLedgerEntryId);

        ApplyWalletDelta(
            refereeWallet,
            rewardSpark,
            WalletLedgerSource.ReferralBonus,
            $"referral:friend:{referral.ReferrerUserId:D}:{triggerReason}",
            now,
            out var refereeLedgerEntryId);

        referral.Status = ReferralAttributionStatus.Rewarded;
        referral.ReferrerLedgerEntryId = referrerLedgerEntryId;
        referral.RefereeLedgerEntryId = refereeLedgerEntryId;
        referral.QualifiedAtUtc = now;
        referral.UpdatedAtUtc = now;
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
        await SettlePendingReferralBonusAsync(order.UserId, $"purchase:{order.Id:D}", now, cancellationToken);

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
        var lastRedeemedAtUtc = redemptions
            .OrderByDescending(x => x.RedeemedAtUtc)
            .Select(x => (DateTime?)x.RedeemedAtUtc)
            .FirstOrDefault();

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
                redemptions,
                code.CampaignName,
                code.CampaignChannel,
                code.MinimumSuccessfulPurchases,
                code.CreatedBy,
                lastRedeemedAtUtc);
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

    private static string NormalizeReferralCode(string rawCode)
    {
        return Regex.Replace(rawCode.Trim().ToUpperInvariant(), "[^A-Z0-9]", string.Empty, RegexOptions.CultureInvariant);
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
        var platform = EconomyPaymentProviderPolicy.NormalizePlatform(query.Platform);
        var region = EconomyPaymentProviderPolicy.NormalizeRegion(query.Country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(region);
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var methods = new List<PaywallPaymentMethodResponse>();

        if (string.Equals(platform, "web", StringComparison.Ordinal))
        {
            var stripeConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
            if (stripeConfig is not null)
            {
                methods.Add(ToPaywallPaymentMethodResponse(stripeConfig, platform, region, "web"));
            }

            return SortPaymentMethods(methods);
        }

        var nativeProvider = string.Equals(platform, "ios", StringComparison.Ordinal) ? "app_store" : "google_play";
        var nativeConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, nativeProvider, platform, region, isEuRegion, query.AppVersion);
        if (nativeConfig is not null)
        {
            methods.Add(ToPaywallPaymentMethodResponse(nativeConfig, platform, region, "in_app"));
        }

        var stripeMobileConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
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

    private async Task<bool> IsPaymentProviderAllowedAsync(
        string provider,
        string platform,
        string country,
        string appVersion,
        CancellationToken cancellationToken)
    {
        var normalizedPlatform = EconomyPaymentProviderPolicy.NormalizePlatform(platform);
        var normalizedRegion = EconomyPaymentProviderPolicy.NormalizeRegion(country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(normalizedRegion);
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var config = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, provider, normalizedPlatform, normalizedRegion, isEuRegion, appVersion);
        if (config is null)
        {
            return false;
        }

        return EconomyPaymentProviderPolicy.IsProviderAllowedForCheckout(provider, normalizedPlatform, config);
    }

    private static DateTime? ResolveNotificationPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime? fallbackPeriodStartUtc)
    {
        if (currentPeriodEndUtc.HasValue)
        {
            return DeriveCurrentPeriodStartUtc(billingPeriod, currentPeriodEndUtc, currentPeriodEndUtc.Value);
        }

        return fallbackPeriodStartUtc;
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
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

}
