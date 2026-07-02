using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

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

    private async Task<Result> SavePaymentMethodAsync(
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
            if (existing.UserId != userId)
            {
                return Result.Failure(EconomyErrors.PaymentMethodOwnershipConflict);
            }

            existing.UserId = userId;
            existing.Brand = details.Brand;
            existing.Last4 = details.Last4;
            existing.ExpMonth = details.ExpMonth;
            existing.ExpYear = details.ExpYear;
            existing.IsActive = true;
            existing.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success();
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
        return Result.Success();
    }

    private async Task<bool> ResolvePremiumStatusAsync(Guid userId, bool fallbackIsPremium, CancellationToken cancellationToken)
    {
        var subscription = await GetLatestUserSubscriptionAsync(userId, cancellationToken);
        var isPremium = IsActivePremiumSubscription(subscription);
        if (isPremium != fallbackIsPremium)
        {
            await ReconcilePremiumEntitlementAsync(userId, "premium_claim_fallback_mismatch", cancellationToken);
        }

        return isPremium;
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
                        || x.Status == "PastDue"
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

        var referrerMutation = await ApplyWalletMutationAsync(
            referrerWallet,
            rewardSpark,
            WalletLedgerSource.ReferralBonus,
            $"referral:inviter:{referral.RefereeUserId:D}:{triggerReason}",
            now,
            cancellationToken);
        if (referrerMutation.IsFailure)
        {
            throw new InvalidOperationException(referrerMutation.Error.Message);
        }

        var refereeMutation = await ApplyWalletMutationAsync(
            refereeWallet,
            rewardSpark,
            WalletLedgerSource.ReferralBonus,
            $"referral:friend:{referral.ReferrerUserId:D}:{triggerReason}",
            now,
            cancellationToken);
        if (refereeMutation.IsFailure)
        {
            throw new InvalidOperationException(refereeMutation.Error.Message);
        }

        referral.Status = ReferralAttributionStatus.Rewarded;
        referral.ReferrerLedgerEntryId = referrerMutation.Value.LedgerEntryId == Guid.Empty
            ? referral.ReferrerLedgerEntryId
            : referrerMutation.Value.LedgerEntryId;
        referral.RefereeLedgerEntryId = refereeMutation.Value.LedgerEntryId == Guid.Empty
            ? referral.RefereeLedgerEntryId
            : refereeMutation.Value.LedgerEntryId;
        referral.QualifiedAtUtc = now;
        referral.UpdatedAtUtc = now;
    }
}
