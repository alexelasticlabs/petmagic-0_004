using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<Result<PaymentCustomer>> GetOrCreatePaymentCustomerAsync(
        Guid userId,
        string provider,
        string? stripeMode,
        CancellationToken cancellationToken)
    {
        var existing = await dbContext.PaymentCustomers
            .FirstOrDefaultAsync(x => x.UserId == userId && x.Provider == provider, cancellationToken);

        if (existing is not null)
        {
            return Result.Success(existing);
        }

        var stripeApiKey = string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            ? ResolveStripeApiKey(stripeMode)
            : null;

        if (string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            && string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PaymentCustomer>(EconomyErrors.PaymentProviderUnavailable);
        }

        var createResult = await paymentGateway.CreateCustomerAsync(
            new PaymentCustomerCreateRequest(provider, userId, stripeApiKey),
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
        return IsActivePremiumSubscription(subscription);
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

        try
        {
            dbContext.Wallets.Add(wallet);
            await dbContext.SaveChangesAsync(cancellationToken);
            return wallet;
        }
        catch (DbUpdateException) when (dbContext.Database.IsRelational())
        {
            dbContext.ChangeTracker.Clear();
            return await dbContext.Wallets.FirstAsync(x => x.UserId == userId, cancellationToken);
        }
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

        try
        {
            dbContext.ReferralProfiles.Add(profile);
            await dbContext.SaveChangesAsync(cancellationToken);
            return profile;
        }
        catch (DbUpdateException) when (dbContext.Database.IsRelational())
        {
            dbContext.ChangeTracker.Clear();
            return await dbContext.ReferralProfiles.FirstAsync(x => x.UserId == userId, cancellationToken);
        }
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
            .AnyAsync(
                x => x.UserId == userId
                    && !string.IsNullOrWhiteSpace(x.ExternalSubscriptionId)
                    && (x.Status == "Active"
                        || x.Status == "GracePeriod"
                        || x.Status == "Canceled")
                    && (x.CurrentPeriodEndUtc == null || x.CurrentPeriodEndUtc >= DateTime.UtcNow),
                cancellationToken);
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

    private WalletOperationResponse ApplyWalletDelta(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
    {
        return ApplyWalletDelta(wallet, delta, source, reason, now, out _, sourceProvider, sourceTransactionId);
    }

    private WalletOperationResponse ApplyWalletDelta(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        out Guid ledgerEntryId,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
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
            SourceProvider = string.IsNullOrWhiteSpace(sourceProvider) ? null : sourceProvider.Trim(),
            SourceTransactionId = string.IsNullOrWhiteSpace(sourceTransactionId) ? null : sourceTransactionId.Trim(),
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

    private WalletStateResponse ToWalletState(
        Wallet wallet,
        bool isPremium,
        DateTime? nextPremiumWeeklyGrantAtUtc = null)
    {
        var nextWeeklyGrantAtUtc = nextPremiumWeeklyGrantAtUtc ?? wallet.LastWeeklyGrantAtUtc?.AddDays(7);

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
            LogPaymentFailed(order, EconomyErrors.PurchaseAlreadyProcessed, "purchase.confirm");
            return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
        }

        var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        ApplyWalletDelta(
            wallet,
            order.SparkToGrant,
            WalletLedgerSource.PackPurchase,
            $"purchase:{order.Id:D}",
            now,
            order.PaymentProvider,
            order.ExternalPaymentId);
        await SettlePendingReferralBonusAsync(order.UserId, $"purchase:{order.Id:D}", now, cancellationToken);

        order.Status = PurchaseOrderStatus.Succeeded;
        order.ConfirmedAtUtc = now;
        wallet.UpdatedAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        await _pushNotificationSender.NotifyWalletUpdateAsync(
            order.UserId,
            new WalletPushNotification(
                Status: "succeeded",
                OrderId: order.Id,
                SparkDelta: order.SparkToGrant),
            cancellationToken);
        LogPaymentSucceeded(order, "purchase.confirm");
        return Result.Success(order);
    }

    private async Task<Result<PurchaseOrder>> ConfirmStorePurchaseInternalAsync(
        PurchaseOrder order,
        string externalPaymentId,
        CancellationToken cancellationToken)
    {
        var normalizedExternalPaymentId = externalPaymentId.Trim();
        if (string.IsNullOrWhiteSpace(normalizedExternalPaymentId))
        {
            return Result.Failure<PurchaseOrder>(EconomyErrors.StorePurchaseInvalid);
        }

        var existingOrder = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(
                x => x.PaymentProvider == order.PaymentProvider
                    && x.ExternalPaymentId == normalizedExternalPaymentId,
                cancellationToken);

        if (existingOrder is not null && existingOrder.Id != order.Id)
        {
            if (existingOrder.UserId != order.UserId)
            {
                return Result.Failure<PurchaseOrder>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(existingOrder);
        }

        order.ExternalPaymentId = normalizedExternalPaymentId;
        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(order);
        }

        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure
            && string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
        {
            return Result.Success(order);
        }

        return confirmResult;
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
            null,
            null,
            null,
            null,
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
            IsStoreProvider(order.PaymentProvider) ? null : order.ExternalPaymentId,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc);
    }

    private static bool IsStoreProvider(string provider)
    {
        return string.Equals(provider, "google_play", StringComparison.OrdinalIgnoreCase)
            || string.Equals(provider, "app_store", StringComparison.OrdinalIgnoreCase);
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
        return WhitespaceRegex().Replace(rawCode.Trim().ToUpperInvariant(), string.Empty);
    }

    private static string NormalizeReferralCode(string rawCode)
    {
        return NonAlphanumericRegex().Replace(rawCode.Trim().ToUpperInvariant(), string.Empty);
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

        const string configsCacheKey = "economy:payment_provider_configs";
        if (!memoryCache.TryGetValue(configsCacheKey, out List<PaymentProviderConfiguration>? configs) || configs is null)
        {
            configs = await dbContext.PaymentProviderConfigurations
                .AsNoTracking()
                .Where(x => x.IsEnabled)
                .ToListAsync(cancellationToken);
            memoryCache.Set(configsCacheKey, configs, TimeSpan.FromMinutes(5));
        }

        var methods = new List<PaywallPaymentMethodResponse>();

        if (string.Equals(platform, "web", StringComparison.Ordinal))
        {
            var stripeConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
            if (stripeConfig is not null && IsStripeModeConfigured(stripeConfig.Mode))
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
        if (stripeMobileConfig is not null
            && stripeMobileConfig.ExternalCheckoutAllowed
            && IsStripeMobileModeConfigured(stripeMobileConfig.Mode))
        {
            methods.Add(ToPaywallPaymentMethodResponse(
                stripeMobileConfig,
                platform,
                region,
                "in_app"));
        }

        return SortPaymentMethods(methods);
    }

    private static PaywallPaymentMethodResponse ToPaywallPaymentMethodResponse(
        PaymentProviderConfiguration config,
        string platform,
        string region,
        string purchaseChannel)
    {
        if (string.Equals(config.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            return ToStripePaywallPaymentMethodResponse(
                config,
                platform,
                region,
                purchaseChannel);
        }

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

    private static PaywallPaymentMethodResponse ToStripePaywallPaymentMethodResponse(
        PaymentProviderConfiguration config,
        string platform,
        string region,
        string purchaseChannel)
    {
        var title = config.WarningTitle;
        var message = config.WarningMessage;
        var note = config.Notes;
        var isEuRegion = string.Equals(region, "EU", StringComparison.OrdinalIgnoreCase)
            || EconomyPaymentProviderPolicy.IsEuRegion(region);
        if (string.IsNullOrWhiteSpace(title))
        {
            title = "Pay with Stripe";
        }

        if (string.IsNullOrWhiteSpace(message))
        {
            message = isEuRegion
                ? "Stripe billing is completed inside PetMagic with native payment sheet (Card / Apple Pay / Google Pay). Provider terms and support may differ from App Store or Google Play."
                : "Stripe billing is completed inside PetMagic with native payment sheet (Card / Apple Pay / Google Pay). Your payment details are processed securely by Stripe.";
        }

        if (string.IsNullOrWhiteSpace(note))
        {
            note = string.Equals(platform, "ios", StringComparison.OrdinalIgnoreCase)
                ? "Subscription renewal and cancellation are available in PetMagic subscription management."
                : "You can manage renewal and cancellation in PetMagic subscription management.";
        }

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
            title,
            message,
            note);
    }

    private static List<PaywallPaymentMethodResponse> SortPaymentMethods(IEnumerable<PaywallPaymentMethodResponse> methods)
    {
        var source = methods.ToList();
        var hasStripe = source.Any(x => IsStripeProvider(x.Provider));

        if (hasStripe)
        {
            source = [.. source.Select(x => x with
            {
                IsSelectedByDefault = IsStripeProvider(x.Provider),
                IsRecommended = IsStripeProvider(x.Provider)
            })];
        }

        return [.. source
            .OrderByDescending(x => IsStripeProvider(x.Provider))
            .ThenByDescending(x => x.IsSelectedByDefault)
            .ThenByDescending(x => x.IsRecommended)
            .ThenBy(x => x.Provider, StringComparer.Ordinal)];
    }

    private static bool IsStripeProvider(string provider)
    {
        return string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase);
    }

    private static PaywallLegalTextsResponse BuildPaywallLegalTexts()
    {
        return new PaywallLegalTextsResponse(
            "Payments for in-app subscriptions are processed by Apple App Store or Google Play. You can manage or cancel the subscription in your store account settings.",
            "Alternative billing with Stripe is completed inside the app and may require additional provider disclosures depending on your region.",
            "Stripe payments are completed inside PetMagic with native payment sheets. PetMagic does not store raw card details.");
    }

    [GeneratedRegex("\\s+", RegexOptions.CultureInvariant)]
    private static partial Regex WhitespaceRegex();

    [GeneratedRegex("[^A-Z0-9]", RegexOptions.CultureInvariant)]
    private static partial Regex NonAlphanumericRegex();
}
