using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private static readonly TimeSpan StoreReceiptFutureSkew = TimeSpan.FromMinutes(5);

    private Result EnsureStoreReceiptIsFresh(
        Guid userId,
        string provider,
        string operation,
        string? transactionDate)
    {
        if (string.IsNullOrWhiteSpace(transactionDate))
        {
            return Result.Success();
        }

        if (!TryParseStoreTransactionDate(transactionDate, out var purchasedAtUtc))
        {
            logger?.LogWarning(
                "Store receipt transaction date could not be parsed. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} CorrelationIdHash={CorrelationIdHash}",
                provider,
                operation,
                EconomyLogSanitizer.SafeUserId(userId),
                CurrentCorrelationIdHash);
            return Result.Failure(EconomyErrors.StorePurchaseInvalid);
        }

        var now = DateTimeOffset.UtcNow;
        if (purchasedAtUtc > now.Add(StoreReceiptFutureSkew))
        {
            logger?.LogWarning(
                "Store receipt transaction date is in the future. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} PurchasedAtUtc={PurchasedAtUtc} CorrelationIdHash={CorrelationIdHash}",
                provider,
                operation,
                EconomyLogSanitizer.SafeUserId(userId),
                purchasedAtUtc,
                CurrentCorrelationIdHash);
            return Result.Failure(EconomyErrors.StorePurchaseInvalid);
        }

        var maxAge = TimeSpan.FromHours(Math.Max(1, options.Value.MaxStoreReceiptAgeHours));
        var receiptAge = now - purchasedAtUtc;
        if (receiptAge > maxAge)
        {
            logger?.LogWarning(
                "Store receipt transaction date exceeded the replay window. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} PurchasedAtUtc={PurchasedAtUtc} AgeHours={AgeHours:F2} MaxAgeHours={MaxAgeHours} CorrelationIdHash={CorrelationIdHash}",
                provider,
                operation,
                EconomyLogSanitizer.SafeUserId(userId),
                purchasedAtUtc,
                receiptAge.TotalHours,
                options.Value.MaxStoreReceiptAgeHours,
                CurrentCorrelationIdHash);
            return Result.Failure(EconomyErrors.StorePurchaseInvalid);
        }

        return Result.Success();
    }

    private static bool TryParseStoreTransactionDate(string raw, out DateTimeOffset purchasedAtUtc)
    {
        var value = raw.Trim();
        if (DateTimeOffset.TryParse(value, out var parsedDate))
        {
            purchasedAtUtc = parsedDate.ToUniversalTime();
            return true;
        }

        if (long.TryParse(value, out var unixValue))
        {
            try
            {
                purchasedAtUtc = unixValue > 10_000_000_000L
                    ? DateTimeOffset.FromUnixTimeMilliseconds(unixValue)
                    : DateTimeOffset.FromUnixTimeSeconds(unixValue);
                return true;
            }
            catch (ArgumentOutOfRangeException)
            {
                purchasedAtUtc = default;
                return false;
            }
        }

        purchasedAtUtc = default;
        return false;
    }
}
