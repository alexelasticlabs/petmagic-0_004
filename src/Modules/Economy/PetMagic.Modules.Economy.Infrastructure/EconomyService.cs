using System.Data;
using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using Npgsql;

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
    IStoreWebhookSecurityValidator? storeWebhookSecurityValidator = null,
    IGenerationBillingReconciliationService? generationBillingReconciliation = null,
    IHttpContextAccessor? httpContextAccessor = null,
    ILoggerFactory? loggerFactory = null,
    NpgsqlDataSource? postgreSqlDataSource = null) : IEconomyService, IEconomyAdminService
{
    private readonly NpgsqlDataSource? _postgreSqlDataSource = postgreSqlDataSource;

    private readonly EconomyAdminConfigurationService _adminConfigurationService =
        new(
            dbContext,
            options,
            new EconomyAdminAuditOutbox(
                dbContext,
                adminAuditLog,
                httpContextAccessor,
                loggerFactory?.CreateLogger<EconomyAdminAuditOutbox>()));

    private readonly EconomyAdminRedeemCodeService _adminRedeemCodeService =
        new(
            dbContext,
            new EconomyAdminAuditOutbox(
                dbContext,
                adminAuditLog,
                httpContextAccessor,
                loggerFactory?.CreateLogger<EconomyAdminAuditOutbox>()));

    private readonly IEconomyPushTokenService _pushTokenService =
        pushTokenService ?? new EconomyPushTokenService(dbContext);

    private readonly IEconomyPushNotificationSender _pushNotificationSender =
        pushNotificationSender ?? new NoopEconomyPushNotificationSender();

    private readonly IGenerationBillingReconciliationService? _generationBillingReconciliation =
        generationBillingReconciliation;

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
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "claim_weekly_grant",
            ExecuteAsync,
            cancellationToken);

        async Task<Result<WalletOperationResponse>> ExecuteAsync(CancellationToken operationCancellationToken)
        {
            await using var transaction = await BeginWalletSerializableTransactionAsync(operationCancellationToken);
            var wallet = await GetOrCreateWalletAsync(command.UserId, operationCancellationToken);
            var now = DateTime.UtcNow;
            var resolvedPremium = await ResolvePremiumStatusAsync(command.UserId, command.IsPremium, operationCancellationToken);

            if (resolvedPremium)
            {
                var balanceBefore = wallet.Balance;
                var nextGrantAtUtc = await GrantPremiumWeeklyTokensIfDueAsync(command.UserId, wallet, now, operationCancellationToken);
                var delta = wallet.Balance - balanceBefore;

                if (delta <= 0)
                {
                    return Result.Failure<WalletOperationResponse>(EconomyErrors.WeeklyGrantCooldown);
                }

                var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(operationCancellationToken);
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
            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                amount,
                WalletLedgerSource.WeeklyGrant,
                "weekly payout",
                now,
                operationCancellationToken);
            if (walletMutation.IsFailure)
            {
                return Result.Failure<WalletOperationResponse>(walletMutation.Error);
            }

            wallet.LastWeeklyGrantAtUtc = now;

            await dbContext.SaveChangesAsync(operationCancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(operationCancellationToken);
            }

            return Result.Success(walletMutation.Value.Response);
        }
    }

    public async Task<Result<WalletOperationResponse>> ClaimAdRewardAsync(ClaimAdRewardCommand command, CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "claim_ad_reward",
            ExecuteAsync,
            cancellationToken);

        async Task<Result<WalletOperationResponse>> ExecuteAsync(CancellationToken operationCancellationToken)
        {
            await using var transaction = await BeginWalletSerializableTransactionAsync(operationCancellationToken);
            var wallet = await GetOrCreateWalletAsync(command.UserId, operationCancellationToken);
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

            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                options.Value.AdRewardSpark,
                WalletLedgerSource.AdReward,
                "rewarded ad",
                now,
                operationCancellationToken);
            if (walletMutation.IsFailure)
            {
                return Result.Failure<WalletOperationResponse>(walletMutation.Error);
            }

            wallet.AdRewardsClaimedInWindow += 1;

            await dbContext.SaveChangesAsync(operationCancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(operationCancellationToken);
            }

            return Result.Success(walletMutation.Value.Response);
        }
    }

    public async Task<Result<WalletOperationResponse>> SpendAsync(SpendBalanceCommand command, CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "wallet_spend",
            SpendInternalAsync,
            command,
            cancellationToken);
    }

    private async Task<Result<WalletOperationResponse>> SpendInternalAsync(SpendBalanceCommand command, CancellationToken cancellationToken)
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
        var idempotencyScope = string.IsNullOrWhiteSpace(command.IdempotencyScope)
            ? source
            : command.IdempotencyScope;
        var sourceTransactionId = BuildInternalWalletIdempotencyTransactionId(
            command.UserId,
            idempotencyScope,
            command.IdempotencyKey);
        var walletMutation = await ApplyWalletMutationAsync(
            wallet,
            -command.Amount,
            source,
            command.Reason,
            now,
            cancellationToken,
            sourceTransactionId is null ? null : InternalWalletMutationProvider,
            sourceTransactionId);
        if (walletMutation.IsFailure)
        {
            return Result.Failure<WalletOperationResponse>(walletMutation.Error);
        }

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsWalletBalanceCheckViolation(exception))
        {
            dbContext.ChangeTracker.Clear();
            EconomyMetrics.RecordWalletBalanceNegativePrevented("spend", source);
            logger?.LogError(
                "Wallet balance CHECK constraint prevented an overdraft. UserIdHash={UserIdHash} Amount={Amount} Source={Source} CorrelationIdHash={CorrelationIdHash}",
                EconomyLogSanitizer.SafeUserId(command.UserId),
                command.Amount,
                source,
                CurrentCorrelationIdHash);
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InsufficientBalance);
        }
        catch (DbUpdateException)
        {
            var existing = await TryResolveExistingWalletMutationAsync(
                command.UserId,
                source,
                command.Reason,
                sourceTransactionId is null ? null : InternalWalletMutationProvider,
                sourceTransactionId,
                clearChangeTracker: true,
                cancellationToken);
            if (existing is not null)
            {
                return Result.Success(existing.Response);
            }

            throw;
        }

        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(walletMutation.Value.Response);
    }

    public async Task<Result<WalletOperationResponse>> CreditAsync(CreditBalanceCommand command, CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "wallet_credit",
            CreditInternalAsync,
            command,
            cancellationToken);
    }

    private async Task<Result<WalletOperationResponse>> CreditInternalAsync(CreditBalanceCommand command, CancellationToken cancellationToken)
    {
        if (command.Amount <= 0)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InvalidAmount);
        }

        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
        var normalizedReason = NormalizeCreditReason(command);
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;
        var idempotencyScope = string.IsNullOrWhiteSpace(command.IdempotencyScope)
            ? command.Source
            : command.IdempotencyScope;
        var sourceTransactionId = BuildInternalWalletIdempotencyTransactionId(
            command.UserId,
            idempotencyScope,
            command.IdempotencyKey);
        var previousMutation = await TryResolvePreviousCreditIdempotencyKeysAsync(
            command,
            idempotencyScope,
            cancellationToken);
        if (previousMutation is not null)
        {
            return Result.Success(previousMutation.Response);
        }

        var walletMutation = await ApplyWalletMutationAsync(
            wallet,
            command.Amount,
            command.Source,
            normalizedReason,
            now,
            cancellationToken,
            sourceTransactionId is null ? null : InternalWalletMutationProvider,
            sourceTransactionId);
        if (walletMutation.IsFailure)
        {
            return Result.Failure<WalletOperationResponse>(walletMutation.Error);
        }

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            var existing = await TryResolveExistingWalletMutationAsync(
                command.UserId,
                command.Source,
                normalizedReason,
                sourceTransactionId is null ? null : InternalWalletMutationProvider,
                sourceTransactionId,
                clearChangeTracker: true,
                cancellationToken);
            if (existing is not null)
            {
                return Result.Success(existing.Response);
            }

            throw;
        }

        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(walletMutation.Value.Response);
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
                    var walletMutation = await ApplyWalletMutationAsync(
                        wallet,
                        redeemCode.RewardValue,
                        WalletLedgerSource.RedeemCode,
                        $"redeem:{redeemCode.CodePrefix}",
                        now,
                        cancellationToken);
                    if (walletMutation.IsFailure)
                    {
                        return Result.Failure<RedeemCodeAppliedResponse>(walletMutation.Error);
                    }

                    walletOperation = walletMutation.Value.Response;
                    ledgerEntryId = walletMutation.Value.LedgerEntryId;
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

    private static string NormalizeCreditReason(CreditBalanceCommand command)
    {
        if (!string.IsNullOrWhiteSpace(command.LedgerReason))
        {
            return command.LedgerReason.Trim();
        }

        return string.IsNullOrWhiteSpace(command.IdempotencyKey)
            ? command.Reason
            : command.IdempotencyKey.Trim();
    }

    private async Task<WalletMutationResult?> TryResolvePreviousCreditIdempotencyKeysAsync(
        CreditBalanceCommand command,
        string idempotencyScope,
        CancellationToken cancellationToken)
    {
        if (command.PreviousIdempotencyKeys is null || command.PreviousIdempotencyKeys.Count == 0)
        {
            return null;
        }

        var checkedKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var previousKey in command.PreviousIdempotencyKeys)
        {
            var normalizedPreviousKey = NormalizeWalletMutationReason(previousKey);
            if (normalizedPreviousKey is null
                || !checkedKeys.Add(normalizedPreviousKey)
                || string.Equals(normalizedPreviousKey, command.IdempotencyKey?.Trim(), StringComparison.Ordinal))
            {
                continue;
            }

            // The compatibility keys represent historical internal credits whose
            // ledger reason was the idempotency key itself. Check both the internal
            // transaction id and that legacy ledger reason before issuing a new credit.
            var previousTransactionId = BuildInternalWalletIdempotencyTransactionId(
                command.UserId,
                idempotencyScope,
                normalizedPreviousKey);
            var existing = await TryResolveExistingWalletMutationAsync(
                command.UserId,
                command.Source,
                normalizedPreviousKey,
                previousTransactionId is null ? null : InternalWalletMutationProvider,
                previousTransactionId,
                clearChangeTracker: false,
                cancellationToken);
            if (existing is not null)
            {
                return existing;
            }
        }

        return null;
    }

    private static string? BuildInternalWalletIdempotencyTransactionId(Guid userId, string source, string? idempotencyKey)
    {
        if (string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return null;
        }

        var rawKey = $"{userId:D}:{source.Trim()}:{idempotencyKey.Trim()}";
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey))).ToLowerInvariant();
        return $"wallet:{hash}";
    }

    private async Task<IDbContextTransaction?> BeginWalletSerializableTransactionAsync(CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational() || dbContext.Database.CurrentTransaction is not null)
        {
            return null;
        }

        return await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
    }

    private Task<Result<T>> ExecuteWalletSerializableMutationWithRetryAsync<T, TCommand>(
        string operation,
        Func<TCommand, CancellationToken, Task<Result<T>>> action,
        TCommand command,
        CancellationToken cancellationToken)
    {
        return ExecuteWalletSerializableMutationWithRetryAsync(
            operation,
            ct => action(command, ct),
            cancellationToken);
    }

    private async Task<Result<T>> ExecuteWalletSerializableMutationWithRetryAsync<T>(
        string operation,
        Func<CancellationToken, Task<Result<T>>> action,
        CancellationToken cancellationToken)
    {
        const int maxAttempts = 3;

        for (var attempt = 1; ; attempt++)
        {
            try
            {
                return await action(cancellationToken);
            }
            catch (Exception exception) when (ShouldRetryWalletSerializableMutation(exception, attempt, maxAttempts, cancellationToken))
            {
                dbContext.ChangeTracker.Clear();
                var delay = TimeSpan.FromMilliseconds(25 * attempt * attempt);
                logger?.LogWarning(
                    "Retrying serializable wallet mutation after transient database failure. Operation={Operation} Attempt={Attempt} MaxAttempts={MaxAttempts} DelayMs={DelayMs} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                    operation,
                    attempt,
                    maxAttempts,
                    delay.TotalMilliseconds,
                    SafeLogValues.ExceptionType(exception),
                    CurrentCorrelationIdHash);
                await Task.Delay(delay, cancellationToken);
            }
        }
    }

    private static bool ShouldRetryWalletSerializableMutation(
        Exception exception,
        int attempt,
        int maxAttempts,
        CancellationToken cancellationToken)
    {
        return attempt < maxAttempts
            && !cancellationToken.IsCancellationRequested
            && IsWalletSerializableRetryableException(exception);
    }

    internal static bool IsWalletSerializableRetryableException(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is Npgsql.PostgresException postgresException
                && (postgresException.SqlState == Npgsql.PostgresErrorCodes.SerializationFailure
                    || postgresException.SqlState == Npgsql.PostgresErrorCodes.DeadlockDetected))
            {
                return true;
            }

            if (current is Npgsql.NpgsqlException { IsTransient: true })
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsWalletBalanceCheckViolation(DbUpdateException exception)
    {
        return exception.InnerException is Npgsql.PostgresException
        {
            SqlState: Npgsql.PostgresErrorCodes.CheckViolation,
            ConstraintName: "CK_economy_wallets_Balance_NonNegative"
        };
    }
}
