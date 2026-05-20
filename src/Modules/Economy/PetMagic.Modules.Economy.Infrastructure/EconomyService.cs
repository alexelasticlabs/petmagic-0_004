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

        var alreadyRedeemed = await dbContext.RedeemCodeRedemptions
            .AnyAsync(x => x.RedeemCodeId == redeemCode.Id && x.UserId == command.UserId, cancellationToken);

        if (alreadyRedeemed)
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeAlreadyUsed);
        }

        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var operation = ApplyWalletDelta(
            wallet,
            redeemCode.RewardSpark,
            WalletLedgerSource.RedeemCode,
            $"redeem:{redeemCode.CodePrefix}",
            now,
            out var ledgerEntryId);

        redeemCode.RedeemedCount += 1;
        redeemCode.UpdatedAtUtc = now;

        dbContext.RedeemCodeRedemptions.Add(new RedeemCodeRedemption
        {
            Id = Guid.NewGuid(),
            RedeemCodeId = redeemCode.Id,
            UserId = command.UserId,
            WalletLedgerEntryId = ledgerEntryId,
            RedeemedAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(new RedeemCodeAppliedResponse(redeemCode.Id, redeemCode.RewardSpark, operation));
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

    public Task<Result<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(CancellationToken cancellationToken)
    {
        var stripeEnabled = !string.IsNullOrWhiteSpace(options.Value.StripeSecretKey);
        var plans = PremiumPlanCatalog.All
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

        return Task.FromResult(Result.Success<IReadOnlyList<PremiumPlanResponse>>(plans));
    }

    public async Task<Result<PremiumStatusResponse>> GetPremiumStatusAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (identityService is null)
        {
            return Result.Success(new PremiumStatusResponse(false, false, null));
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        if (profile.IsFailure)
        {
            return Result.Failure<PremiumStatusResponse>(profile.Error);
        }

        var hasStripeCustomer = await dbContext.PaymentCustomers
            .AsNoTracking()
            .AnyAsync(x => x.UserId == userId && x.Provider == "stripe", cancellationToken);

        return Result.Success(new PremiumStatusResponse(
            profile.Value.IsPremium,
            hasStripeCustomer,
            hasStripeCustomer ? "stripe" : null));
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

        var plan = PremiumPlanCatalog.Find(command.PlanCode);
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

        var plan = PremiumPlanCatalog.Find(command.PlanCode);
        if (plan is null)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var expectedProductId = string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? plan.GooglePlayProductId
            : plan.AppStoreProductId;

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

        var premiumResult = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(command.UserId, true),
            cancellationToken);

        if (premiumResult.IsFailure)
        {
            return Result.Failure<PremiumStoreVerificationResponse>(premiumResult.Error);
        }

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

    public async Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken)
    {
        var codes = await dbContext.RedeemCodes
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new AdminRedeemCodeResponse(
                x.Id,
                x.CodePrefix,
                x.Description,
                x.RewardSpark,
                x.MaxRedemptions,
                x.RedeemedCount,
                x.IsActive,
                x.StartsAtUtc,
                x.ExpiresAtUtc,
                x.CreatedAtUtc,
                x.UpdatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminRedeemCodeResponse>>(codes);
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
        var code = new RedeemCode
        {
            Id = Guid.NewGuid(),
            CodeHash = codeHash,
            CodePrefix = BuildRedeemCodePrefix(normalizedCode),
            Description = command.Description.Trim(),
            RewardSpark = command.RewardSpark,
            MaxRedemptions = command.MaxRedemptions,
            RedeemedCount = 0,
            IsActive = command.IsActive,
            StartsAtUtc = command.StartsAtUtc,
            ExpiresAtUtc = command.ExpiresAtUtc,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.RedeemCodes.Add(code);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToAdminRedeemCodeResponse(code));
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

        code.Description = command.Description.Trim();
        code.RewardSpark = command.RewardSpark;
        code.MaxRedemptions = command.MaxRedemptions;
        code.IsActive = command.IsActive;
        code.StartsAtUtc = command.StartsAtUtc;
        code.ExpiresAtUtc = command.ExpiresAtUtc;
        code.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToAdminRedeemCodeResponse(code));
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
        if (identityService is null)
        {
            return fallbackIsPremium;
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        return profile.IsSuccess ? profile.Value.IsPremium : fallbackIsPremium;
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

    private static AdminRedeemCodeResponse ToAdminRedeemCodeResponse(RedeemCode code)
    {
        return new AdminRedeemCodeResponse(
            code.Id,
            code.CodePrefix,
            code.Description,
            code.RewardSpark,
            code.MaxRedemptions,
            code.RedeemedCount,
            code.IsActive,
            code.StartsAtUtc,
            code.ExpiresAtUtc,
            code.CreatedAtUtc,
            code.UpdatedAtUtc);
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

    private static string HashRedeemCode(string normalizedCode)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(normalizedCode));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string BuildRedeemCodePrefix(string normalizedCode)
    {
        return normalizedCode[..Math.Min(normalizedCode.Length, 4)];
    }

    private static (bool Success, Guid? OrderId, Guid? UserId, string? ObjectId, string? Purpose, string? SetupIntentId, string? Status) ParseStripeEvent(string rawBody)
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
                return (false, null, null, null, null, null, null);
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

            Guid? orderId = null;
            Guid? userId = null;
            string? purpose = null;
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
            }

            return (true, orderId, userId, objectId, purpose, setupIntentId, status);
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
                return (false, null, null, null, null, null, null);
            }

            return (true, orderId, null, objectId, null, null, null);
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
