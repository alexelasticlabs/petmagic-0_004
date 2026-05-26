using System.Data;

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

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService(
    EconomyDbContext dbContext,
    IPaymentGateway paymentGateway,
    IStoreSubscriptionVerifier storeSubscriptionVerifier,
    IOptions<EconomyOptions> options,
    IIdentityService? identityService = null,
    ILogger<EconomyService>? logger = null) : IEconomyService
{
    private readonly EconomyAdminConfigurationService _adminConfigurationService =
        new(dbContext, options);

    private readonly EconomyAdminRedeemCodeService _adminRedeemCodeService =
        new(dbContext);

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
}
