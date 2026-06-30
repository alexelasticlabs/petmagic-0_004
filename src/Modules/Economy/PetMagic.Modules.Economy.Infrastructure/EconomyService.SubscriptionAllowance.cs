using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<DateTime?> GrantPremiumWeeklyTokensIfDueAsync(
        Guid userId,
        Wallet wallet,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var subscription = await GetLatestUserSubscriptionAsync(userId, cancellationToken);
        if (!IsActivePremiumSubscription(subscription))
        {
            return null;
        }

        var subscriptionStartUtc = subscription!.CurrentPeriodStartUtc ?? subscription.CreatedAtUtc;
        if (subscriptionStartUtc > now)
        {
            return subscriptionStartUtc;
        }

        var elapsedDays = (now - subscriptionStartUtc).TotalDays;
        var targetGrantCount = (int)Math.Floor(elapsedDays / 7d);

        var existingWeeklyGrantMetadata = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(
                x => x.UserId == userId
                    && x.Source == WalletLedgerSource.PremiumSubscriptionWeeklyGrant)
            .Select(x => new { x.Reason, x.CreatedAtUtc })
            .ToListAsync(cancellationToken);
        var grantedReasons = existingWeeklyGrantMetadata
            .Select(x => x.Reason)
            .ToHashSet(StringComparer.Ordinal);
        var legacyGrantedCount = existingWeeklyGrantMetadata.Count(
            x => x.CreatedAtUtc >= subscriptionStartUtc
                && IsLegacyPremiumWeeklyGrantReason(x.Reason));

        var grantedCount = 0;
        var appliedAnyGrants = false;
        for (var index = 0; index < targetGrantCount; index++)
        {
            var sequence = index + 1;
            var reason = BuildPremiumWeeklyGrantReason(subscriptionStartUtc, sequence);
            var wasGrantedByLegacyRecord = sequence <= legacyGrantedCount;
            if (wasGrantedByLegacyRecord || grantedReasons.Contains(reason))
            {
                grantedCount += 1;
                continue;
            }

            ApplyWalletDelta(
                wallet,
                options.Value.WeeklyPremiumSpark,
                WalletLedgerSource.PremiumSubscriptionWeeklyGrant,
                reason,
                now);
            grantedReasons.Add(reason);
            grantedCount += 1;
            appliedAnyGrants = true;
        }

        if (appliedAnyGrants)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return subscriptionStartUtc.AddDays((grantedCount + 1) * 7d);
    }

    private async Task GrantPremiumSubscriptionAllowanceIfDueAsync(
        UserSubscription subscription,
        string providerContext,
        CancellationToken cancellationToken)
    {
        await using var transaction = dbContext.Database.IsRelational() && dbContext.Database.CurrentTransaction is null
            ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken)
            : null;

        try
        {
            var now = DateTime.UtcNow;
            var periodStartUtc = subscription.CurrentPeriodStartUtc ?? subscription.CreatedAtUtc;
            if (subscription.LastTokenGrantAtUtc.HasValue
                && subscription.LastTokenGrantAtUtc.Value >= periodStartUtc)
            {
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return;
            }

            var allowanceReason = BuildPremiumAllowanceGrantReason(periodStartUtc);
            var existingGrantAtUtc = await dbContext.WalletLedgerEntries
                .AsNoTracking()
                .Where(
                    x => x.UserId == subscription.UserId
                        && x.Source == WalletLedgerSource.PremiumSubscriptionGrant
                        && IsPremiumAllowanceGrantReasonForPeriod(x.Reason, periodStartUtc))
                .Select(x => (DateTime?)x.CreatedAtUtc)
                .OrderByDescending(x => x)
                .FirstOrDefaultAsync(cancellationToken);

            if (existingGrantAtUtc.HasValue)
            {
                var didChange = false;
                if (subscription.MonthlyTokensGranted != options.Value.WeeklyPremiumSpark)
                {
                    subscription.MonthlyTokensGranted = options.Value.WeeklyPremiumSpark;
                    didChange = true;
                }

                if (!subscription.LastTokenGrantAtUtc.HasValue
                    || subscription.LastTokenGrantAtUtc.Value < existingGrantAtUtc.Value)
                {
                    subscription.LastTokenGrantAtUtc = existingGrantAtUtc.Value;
                    didChange = true;
                }

                if (didChange)
                {
                    subscription.UpdatedAtUtc = now;
                    await dbContext.SaveChangesAsync(cancellationToken);
                }

                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return;
            }

            var wallet = await GetOrCreateWalletAsync(subscription.UserId, cancellationToken);

            ApplyWalletDelta(
                wallet,
                options.Value.WeeklyPremiumSpark,
                WalletLedgerSource.PremiumSubscriptionGrant,
                allowanceReason,
                now);

            subscription.MonthlyTokensGranted = options.Value.WeeklyPremiumSpark;
            subscription.LastTokenGrantAtUtc = now;
            subscription.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Failed to grant premium subscription allowance. UserId={UserId} SubscriptionId={SubscriptionId} Provider={Provider} CorrelationId={CorrelationId}",
                subscription.UserId,
                subscription.Id,
                providerContext,
                CurrentCorrelationId);

            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            throw;
        }
    }

    private static string GetManageSubscriptionAction(string? provider)
    {
        return provider?.Trim().ToLowerInvariant() switch
        {
            "stripe" => "portal",
            "app_store" => "app_store",
            "google_play" => "google_play",
            _ => "none"
        };
    }

    private static DateTime DeriveCurrentPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime fallbackUtc)
    {
        var endUtc = currentPeriodEndUtc ?? fallbackUtc;
        return billingPeriod.Trim().ToLowerInvariant() switch
        {
            "yearly" or "year" => endUtc.AddYears(-1),
            _ => endUtc.AddMonths(-1)
        };
    }

    private static DateTime? ResolveNotificationPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime? fallbackPeriodStartUtc)
    {
        if (fallbackPeriodStartUtc.HasValue)
        {
            return fallbackPeriodStartUtc;
        }

        return currentPeriodEndUtc.HasValue
            ? DeriveCurrentPeriodStartUtc(billingPeriod, currentPeriodEndUtc, currentPeriodEndUtc.Value)
            : null;
    }

    private static string BuildPremiumWeeklyGrantReason(DateTime subscriptionStartUtc, int sequence)
    {
        return $"premium_weekly:{subscriptionStartUtc:O}:{sequence}";
    }

    private static string BuildPremiumAllowanceGrantReason(DateTime periodStartUtc)
    {
        return $"premium_allowance:{periodStartUtc:O}";
    }

    private static bool IsPremiumAllowanceGrantReasonForPeriod(string? reason, DateTime periodStartUtc)
    {
        const string prefix = "premium_allowance:";
        if (string.IsNullOrWhiteSpace(reason)
            || !reason.StartsWith(prefix, StringComparison.Ordinal))
        {
            return false;
        }

        return reason.EndsWith(periodStartUtc.ToString("O"), StringComparison.Ordinal);
    }

    private static bool IsLegacyPremiumWeeklyGrantReason(string? reason)
    {
        const string prefix = "premium_weekly:";
        if (string.IsNullOrWhiteSpace(reason)
            || !reason.StartsWith(prefix, StringComparison.Ordinal)
            || reason.Length <= prefix.Length + 36
            || reason[prefix.Length + 36] != ':')
        {
            return false;
        }

        return Guid.TryParseExact(reason.Substring(prefix.Length, 36), "D", out _);
    }
}
