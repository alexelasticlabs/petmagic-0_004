using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
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
    IMemoryCache memoryCache,
    IEconomyPushTokenService? pushTokenService = null,
    IEconomyPushNotificationSender? pushNotificationSender = null,
    IIdentityService? identityService = null,
    ILogger<EconomyService>? logger = null,
    IAdminAuditLog? adminAuditLog = null,
    IStoreWebhookSecurityValidator? storeWebhookSecurityValidator = null) : IEconomyService, IEconomyAdminService
{
    private readonly EconomyAdminConfigurationService _adminConfigurationService =
        new(dbContext, options);

    private readonly EconomyAdminRedeemCodeService _adminRedeemCodeService =
        new(dbContext);

    private readonly IEconomyPushTokenService _pushTokenService =
        pushTokenService ?? new EconomyPushTokenService(dbContext);

    private readonly IEconomyPushNotificationSender _pushNotificationSender =
        pushNotificationSender ?? new NoopEconomyPushNotificationSender();

    public async Task<Result<WalletStateResponse>> GetWalletAsync(Guid userId, bool isPremium, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
        var resolvedPremium = await ResolvePremiumStatusAsync(userId, isPremium, cancellationToken);
        DateTime? premiumNextGrantAtUtc = null;
        if (resolvedPremium)
        {
            premiumNextGrantAtUtc = await GrantPremiumWeeklyTokensIfDueAsync(
                userId,
                wallet,
                DateTime.UtcNow,
                cancellationToken);
        }

        return Result.Success(ToWalletState(wallet, resolvedPremium, premiumNextGrantAtUtc));
    }

    public Task<Result> RegisterPushTokenAsync(RegisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        return _pushTokenService.RegisterAsync(command, cancellationToken);
    }

    public Task<Result> UnregisterPushTokenAsync(UnregisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        return _pushTokenService.UnregisterAsync(command, cancellationToken);
    }

    public async Task<Result<WalletOperationResponse>> ClaimWeeklyGrantAsync(ClaimWeeklyGrantCommand command, CancellationToken cancellationToken)
    {
        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;
        var resolvedPremium = await ResolvePremiumStatusAsync(command.UserId, command.IsPremium, cancellationToken);

        if (resolvedPremium)
        {
            var balanceBefore = wallet.Balance;
            var nextGrantAtUtc = await GrantPremiumWeeklyTokensIfDueAsync(command.UserId, wallet, now, cancellationToken);
            var delta = wallet.Balance - balanceBefore;

            if (delta <= 0)
            {
                return Result.Failure<WalletOperationResponse>(EconomyErrors.WeeklyGrantCooldown);
            }

            var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(new WalletOperationResponse(
                wallet.UserId,
                delta,
                wallet.Balance,
                WalletLedgerSource.PremiumSubscriptionWeeklyGrant,
                now,
                nextGrantAtUtc,
                adRewardsRemainingToday));
        }

        if (wallet.LastWeeklyGrantAtUtc is DateTime lastWeeklyGrantAtUtc)
        {
            var nextWeeklyAtUtc = lastWeeklyGrantAtUtc.AddDays(7);
            if (nextWeeklyAtUtc > now)
            {
                return Result.Failure<WalletOperationResponse>(EconomyErrors.WeeklyGrantCooldown);
            }
        }

        var amount = options.Value.WeeklyFreeSpark;
        var response = ApplyWalletDelta(wallet, amount, WalletLedgerSource.WeeklyGrant, "weekly payout", now);
        wallet.LastWeeklyGrantAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> ClaimAdRewardAsync(ClaimAdRewardCommand command, CancellationToken cancellationToken)
    {
        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
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
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> SpendAsync(SpendBalanceCommand command, CancellationToken cancellationToken)
    {
        if (command.Amount <= 0)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InvalidAmount);
        }

        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;
        var source = string.IsNullOrWhiteSpace(command.Source)
            ? WalletLedgerSource.GenerationSpend
            : command.Source;
        if (source == WalletLedgerSource.WatermarkUnlock)
        {
            var existingSpend = await dbContext.WalletLedgerEntries
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == command.UserId
                        && x.Source == WalletLedgerSource.WatermarkUnlock
                        && x.Reason == command.Reason
                        && x.Delta < 0,
                    cancellationToken);
            if (existingSpend is not null)
            {
                return Result.Success(new WalletOperationResponse(
                    wallet.UserId,
                    0,
                    wallet.Balance,
                    source,
                    existingSpend.CreatedAtUtc,
                    wallet.LastWeeklyGrantAtUtc?.AddDays(7),
                    Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow)));
            }
        }

        if (wallet.Balance < command.Amount)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InsufficientBalance);
        }

        var response = ApplyWalletDelta(wallet, -command.Amount, source, command.Reason, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException) when (source == WalletLedgerSource.WatermarkUnlock)
        {
            var existing = await TryResolveExistingWatermarkUnlockSpendAsync(
                command.UserId,
                command.Reason,
                cancellationToken);
            if (existing is not null)
            {
                return Result.Success(existing);
            }

            throw;
        }

        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> CreditAsync(CreditBalanceCommand command, CancellationToken cancellationToken)
    {
        if (command.Amount <= 0)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InvalidAmount);
        }

        var normalizedReason = NormalizeCreditReason(command);
        if (IsGenerationRefund(command.Source))
        {
            var existingRefund = await TryResolveExistingGenerationRefundCreditAsync(
                command.UserId,
                normalizedReason,
                cancellationToken);
            if (existingRefund is not null)
            {
                return Result.Success(existingRefund);
            }
        }

        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;
        var response = ApplyWalletDelta(wallet, command.Amount, command.Source, normalizedReason, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException) when (IsGenerationRefund(command.Source))
        {
            var existing = await TryResolveExistingGenerationRefundCreditAsync(
                command.UserId,
                normalizedReason,
                cancellationToken);
            if (existing is not null)
            {
                return Result.Success(existing);
            }

            throw;
        }

        return Result.Success(response);
    }

    public async Task<Result<RedeemCodeAppliedResponse>> ApplyRedeemCodeAsync(ApplyRedeemCodeCommand command, CancellationToken cancellationToken)
    {
        var normalizedCode = NormalizeRedeemCode(command.Code);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeNotFound);
        }

        await using var transaction = dbContext.Database.IsRelational()
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
        var startsAtUtc = redeemCode.StartsAtUtc;
        if (!redeemCode.IsActive || (startsAtUtc.HasValue && startsAtUtc.Value > now))
        {
            return Result.Failure<RedeemCodeAppliedResponse>(EconomyErrors.RedeemCodeInactive);
        }

        var expiresAtUtc = redeemCode.ExpiresAtUtc;
        if (expiresAtUtc.HasValue && expiresAtUtc.Value <= now)
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

        var aggregation = await dbContext.ReferralAttributions
            .AsNoTracking()
            .Where(x => x.ReferrerUserId == userId)
            .GroupBy(x => 1)
            .Select(g => new
            {
                TotalCount = g.Count(),
                RewardedCount = g.Count(x => x.Status == ReferralAttributionStatus.Rewarded),
                PendingCount = g.Count(x => x.Status == ReferralAttributionStatus.Pending),
                TotalRewardSpark = g.Where(x => x.Status == ReferralAttributionStatus.Rewarded).Sum(x => x.RewardSpark)
            })
            .FirstOrDefaultAsync(cancellationToken);

        return Result.Success(new RewardsSummaryResponse(
            profile.Code,
            options.Value.ReferralBonusSpark,
            activatedReferral?.Status ?? "none",
            activatedReferral?.ReferrerCode,
            activatedReferral?.CreatedAtUtc,
            activatedReferral?.QualifiedAtUtc,
            aggregation?.TotalRewardSpark ?? 0,
            aggregation?.TotalCount ?? 0,
            aggregation?.PendingCount ?? 0,
            aggregation?.RewardedCount ?? 0));
    }

    public async Task<Result<ReferralCodeAppliedResponse>> ApplyReferralCodeAsync(ApplyReferralCodeCommand command, CancellationToken cancellationToken)
    {
        var normalizedCode = NormalizeReferralCode(command.Code);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            return Result.Failure<ReferralCodeAppliedResponse>(EconomyErrors.ReferralCodeNotFound);
        }

        await using var transaction = dbContext.Database.IsRelational()
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

    private async Task<WalletOperationResponse?> TryResolveExistingWatermarkUnlockSpendAsync(
        Guid userId,
        string reason,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();

        var existingSpend = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == userId
                    && x.Source == WalletLedgerSource.WatermarkUnlock
                    && x.Reason == reason
                    && x.Delta < 0,
                cancellationToken);
        if (existingSpend is null)
        {
            return null;
        }

        var wallet = await dbContext.Wallets
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        var balance = wallet?.Balance ?? 0;

        return new WalletOperationResponse(
            userId,
            0,
            balance,
            WalletLedgerSource.WatermarkUnlock,
            existingSpend.CreatedAtUtc,
            wallet?.LastWeeklyGrantAtUtc?.AddDays(7),
            Math.Max(0, options.Value.AdRewardDailyLimit - (wallet?.AdRewardsClaimedInWindow ?? 0)));
    }

    private async Task<WalletOperationResponse?> TryResolveExistingGenerationRefundCreditAsync(
        Guid userId,
        string reason,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();

        var existingCredit = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == userId
                    && x.Source == WalletLedgerSource.GenerationRefund
                    && x.Reason == reason
                    && x.Delta > 0,
                cancellationToken);
        if (existingCredit is null)
        {
            return null;
        }

        var wallet = await dbContext.Wallets
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        return new WalletOperationResponse(
            userId,
            0,
            wallet?.Balance ?? existingCredit.BalanceAfter,
            WalletLedgerSource.GenerationRefund,
            existingCredit.CreatedAtUtc,
            wallet?.LastWeeklyGrantAtUtc?.AddDays(7),
            Math.Max(0, options.Value.AdRewardDailyLimit - (wallet?.AdRewardsClaimedInWindow ?? 0)));
    }

    private static bool IsGenerationRefund(string source)
    {
        return string.Equals(source, WalletLedgerSource.GenerationRefund, StringComparison.Ordinal);
    }

    private static string NormalizeCreditReason(CreditBalanceCommand command)
    {
        return string.IsNullOrWhiteSpace(command.IdempotencyKey)
            ? command.Reason
            : command.IdempotencyKey.Trim();
    }

    private async Task<IDbContextTransaction?> BeginWalletSerializableTransactionAsync(CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational() || dbContext.Database.CurrentTransaction is not null)
        {
            return null;
        }

        return await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
    }
}
