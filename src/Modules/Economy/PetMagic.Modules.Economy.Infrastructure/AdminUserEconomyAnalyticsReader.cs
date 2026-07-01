using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class AdminUserEconomyAnalyticsReader(EconomyDbContext dbContext) : IAdminUserEconomyAnalyticsReader
{
    public async Task<Result<AdminUserEconomyAnalyticsResponse>> GetAdminUserEconomyAnalyticsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var wallet = await dbContext.Wallets
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        var purchaseSummary = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalPurchases = group.Count(),
                SuccessfulPurchases = group.Count(x => x.Status == PurchaseOrderStatus.Succeeded),
                TotalPurchasedSpark = group.Where(x => x.Status == PurchaseOrderStatus.Succeeded).Sum(x => (int?)x.SparkToGrant) ?? 0,
                LastPurchaseAtUtc = group.Where(x => x.Status == PurchaseOrderStatus.Succeeded).Max(x => (DateTime?)(x.ConfirmedAtUtc ?? x.CreatedAtUtc))
            })
            .FirstOrDefaultAsync(cancellationToken);

        var recentPurchases = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(10)
            .Select(x => new AdminUserEconomyPurchaseResponse(
                x.Id,
                x.Status ?? string.Empty,
                x.PriceAmount,
                x.CurrencyCode ?? string.Empty,
                x.SparkToGrant,
                x.PaymentProvider ?? string.Empty,
                x.CreatedAtUtc,
                x.ConfirmedAtUtc))
            .ToListAsync(cancellationToken);

        var walletLedgerSummary = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalTokensCredited = group.Where(x => x.Delta > 0).Sum(x => (int?)x.Delta) ?? 0,
                TotalTokensSpent = group.Where(x => x.Delta < 0).Sum(x => (int?)(-x.Delta)) ?? 0,
                ManualTokensGranted = group.Where(x => x.Source == WalletLedgerSource.AdminGrant && x.Delta > 0).Sum(x => (int?)x.Delta) ?? 0,
                ManualTokensDebited = group.Where(x => x.Source == WalletLedgerSource.AdminDebit && x.Delta < 0).Sum(x => (int?)(-x.Delta)) ?? 0
            })
            .FirstOrDefaultAsync(cancellationToken);

        var recentWalletLedger = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(12)
            .Select(x => new AdminUserEconomyWalletLedgerResponse(
                x.Id,
                x.Delta,
                x.BalanceAfter,
                x.Source ?? string.Empty,
                x.Reason ?? string.Empty,
                x.CreatedAtUtc,
                x.SourceProvider,
                null))
            .ToListAsync(cancellationToken);

        var recentActivity = recentPurchases
            .Select(x => new AdminUserEconomyActivityResponse(
                "purchase",
                $"Purchase {x.Status}",
                $"{x.SparkToGrant} spark - {x.PriceAmount} {x.CurrencyCode}",
                x.ConfirmedAtUtc ?? x.CreatedAtUtc))
            .Concat(recentWalletLedger.Select(x => new AdminUserEconomyActivityResponse(
                "wallet",
                DescribeWalletLedgerTitle(x.Source),
                $"{DescribeWalletLedgerAmount(x.Delta)} - {x.Reason}",
                x.CreatedAtUtc)))
            .ToList();

        return Result.Success(new AdminUserEconomyAnalyticsResponse(
            wallet?.Balance ?? 0,
            walletLedgerSummary?.TotalTokensCredited ?? 0,
            walletLedgerSummary?.TotalTokensSpent ?? 0,
            walletLedgerSummary?.ManualTokensGranted ?? 0,
            walletLedgerSummary?.ManualTokensDebited ?? 0,
            purchaseSummary?.TotalPurchases ?? 0,
            purchaseSummary?.SuccessfulPurchases ?? 0,
            purchaseSummary?.TotalPurchasedSpark ?? 0,
            purchaseSummary?.LastPurchaseAtUtc,
            recentWalletLedger.Count > 0 ? recentWalletLedger[0].CreatedAtUtc : null,
            recentPurchases,
            recentWalletLedger,
            recentActivity));
    }

    private static string DescribeWalletLedgerTitle(string source)
    {
        return source switch
        {
            WalletLedgerSource.AdminGrant => "Admin token grant",
            WalletLedgerSource.AdminDebit => "Admin token debit",
            WalletLedgerSource.PackPurchase => "Pack purchase credited",
            WalletLedgerSource.PurchaseRefund => "Purchase refunded",
            WalletLedgerSource.AdReward => "Ad reward credited",
            WalletLedgerSource.WeeklyGrant => "Weekly grant credited",
            WalletLedgerSource.GenerationRefund => "Generation refunded",
            WalletLedgerSource.GenerationSpend => "Generation spend",
            _ => source
        };
    }

    private static string DescribeWalletLedgerAmount(int delta)
    {
        var sign = delta > 0 ? "+" : string.Empty;
        return $"{sign}{delta} tokens";
    }
}
