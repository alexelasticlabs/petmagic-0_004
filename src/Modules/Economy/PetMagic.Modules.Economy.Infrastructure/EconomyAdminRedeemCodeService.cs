using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed partial class EconomyAdminRedeemCodeService(EconomyDbContext dbContext)
{
    private const int AdminRedeemCodeRedemptionsPreviewLimit = 5;

    public async Task<Result<OffsetPagedResponse<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, query.Skip);
        var normalizedTake = NormalizeTake(query.Take, 50, 200);
        var normalizedSearch = NormalizeListFilter(query.Search);
        var normalizedStatus = NormalizeListFilter(query.Status);
        var normalizedRewardKind = NormalizeListFilter(query.RewardKind);
        var normalizedSort = NormalizeListFilter(query.Sort);
        var now = DateTime.UtcNow;

        var codesQuery = dbContext.RedeemCodes
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            codesQuery = codesQuery.Where(x =>
                x.Code.ToLower().Contains(normalizedSearch) ||
                x.CodePrefix.ToLower().Contains(normalizedSearch) ||
                x.Description.ToLower().Contains(normalizedSearch) ||
                (x.CampaignName != null && x.CampaignName.ToLower().Contains(normalizedSearch)) ||
                (x.CampaignChannel != null && x.CampaignChannel.ToLower().Contains(normalizedSearch)) ||
                (x.CreatedBy != null && x.CreatedBy.ToLower().Contains(normalizedSearch)));
        }

        if (!string.IsNullOrWhiteSpace(normalizedRewardKind) && normalizedRewardKind != "all")
        {
            codesQuery = codesQuery.Where(x => x.RewardKind == normalizedRewardKind);
        }

        var filteredCodes = (await codesQuery.ToListAsync(cancellationToken))
            .Where(code => MatchesRedeemCodeStatus(code, normalizedStatus, now))
            .ToList();
        var totalCount = filteredCodes.Count;

        SortRedeemCodes(filteredCodes, normalizedSort);

        var pageCodes = filteredCodes
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToList();

        var pagedCodes = ToPaged(pageCodes, normalizedSkip, normalizedTake);
        var codes = pagedCodes.Items;

        var codeIds = codes.Select(x => x.Id).ToArray();

        if (codeIds.Length == 0)
        {
            return Result.Success(new OffsetPagedResponse<AdminRedeemCodeResponse>(
                [],
                normalizedSkip,
                normalizedTake,
                pagedCodes.HasMore,
                totalCount));
        }

        var sevenDaysAgo = now.AddDays(-7);
        var lastRedeemedAtByCode = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId))
            .GroupBy(x => x.RedeemCodeId)
            .Select(group => new
            {
                RedeemCodeId = group.Key,
                LastRedeemedAtUtc = group.Max(x => (DateTime?)x.RedeemedAtUtc)
            })
            .ToDictionaryAsync(x => x.RedeemCodeId, x => x.LastRedeemedAtUtc, cancellationToken);

        var recentStatsByCode = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId) && x.RedeemedAtUtc >= sevenDaysAgo)
            .GroupBy(x => x.RedeemCodeId)
            .Select(group => new
            {
                RedeemCodeId = group.Key,
                UsesLast7d = group.Count(),
                GrantedLast7d = group.Sum(x => x.RewardKind == RedeemCodeRewardKind.Spark ? x.RewardValue : 0)
            })
            .ToDictionaryAsync(x => x.RedeemCodeId, cancellationToken);

        var maxRedeemedBySingleUserByCode = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId))
            .GroupBy(x => new { x.RedeemCodeId, x.UserId })
            .Select(group => new
            {
                group.Key.RedeemCodeId,
                Count = group.Count()
            })
            .GroupBy(x => x.RedeemCodeId)
            .Select(group => new
            {
                RedeemCodeId = group.Key,
                MaxRedeemedBySingleUser = group.Max(x => x.Count)
            })
            .ToDictionaryAsync(x => x.RedeemCodeId, x => x.MaxRedeemedBySingleUser, cancellationToken);

        var redemptionPreviewRows = await dbContext.RedeemCodes
            .AsNoTracking()
            .Where(code => codeIds.Contains(code.Id))
            .SelectMany(code => dbContext.RedeemCodeRedemptions
                .AsNoTracking()
                .Where(redemption => redemption.RedeemCodeId == code.Id)
                .OrderByDescending(redemption => redemption.RedeemedAtUtc)
                .ThenByDescending(redemption => redemption.Id)
                .Take(AdminRedeemCodeRedemptionsPreviewLimit))
            .Select(ToAdminRedeemCodeRedemptionResponseProjection())
            .ToListAsync(cancellationToken);

        var redemptionsByCode = redemptionPreviewRows
            .GroupBy(x => x.RedeemCodeId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<AdminRedeemCodeRedemptionResponse>)[.. group.Select(x => x.Response)]);

        var result = codes
            .Select(code =>
            {
                recentStatsByCode.TryGetValue(code.Id, out var recentStats);
                return ToAdminRedeemCodeResponse(
                    code,
                    redemptionsByCode.GetValueOrDefault(code.Id) ?? [],
                    lastRedeemedAtByCode.GetValueOrDefault(code.Id),
                    recentStats?.UsesLast7d ?? 0,
                    recentStats?.GrantedLast7d ?? 0,
                    maxRedeemedBySingleUserByCode.GetValueOrDefault(code.Id));
            })
            .ToList();

        return Result.Success(new OffsetPagedResponse<AdminRedeemCodeResponse>(
            result,
            normalizedSkip,
            normalizedTake,
            pagedCodes.HasMore,
            totalCount));
    }

    public async Task<Result<AdminRedeemCodeMetricsResponse>> GetAdminRedeemCodeMetricsAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken)
    {
        var normalizedSearch = NormalizeListFilter(query.Search);
        var normalizedStatus = NormalizeListFilter(query.Status);
        var normalizedRewardKind = NormalizeListFilter(query.RewardKind);
        var now = DateTime.UtcNow;
        var sevenDaysAgo = now.AddDays(-7);

        var codesQuery = dbContext.RedeemCodes
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            codesQuery = codesQuery.Where(x =>
                x.Code.ToLower().Contains(normalizedSearch) ||
                x.CodePrefix.ToLower().Contains(normalizedSearch) ||
                x.Description.ToLower().Contains(normalizedSearch) ||
                (x.CampaignName != null && x.CampaignName.ToLower().Contains(normalizedSearch)) ||
                (x.CampaignChannel != null && x.CampaignChannel.ToLower().Contains(normalizedSearch)) ||
                (x.CreatedBy != null && x.CreatedBy.ToLower().Contains(normalizedSearch)));
        }

        if (!string.IsNullOrWhiteSpace(normalizedRewardKind) && normalizedRewardKind != "all")
        {
            codesQuery = codesQuery.Where(x => x.RewardKind == normalizedRewardKind);
        }

        var filteredCodes = (await codesQuery.ToListAsync(cancellationToken))
            .Where(code => MatchesRedeemCodeStatus(code, normalizedStatus, now))
            .ToList();

        if (filteredCodes.Count == 0)
        {
            return Result.Success(new AdminRedeemCodeMetricsResponse(0, 0, 0, 0, 0, 0, 0, 0));
        }

        var codeIds = filteredCodes.Select(x => x.Id).ToArray();
        var redemptionStats = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId))
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalUses = group.Count(),
                TotalGranted = group.Sum(x => x.RewardKind == RedeemCodeRewardKind.Spark ? x.RewardValue : 0),
                UsesLast7d = group.Count(x => x.RedeemedAtUtc >= sevenDaysAgo),
                GrantedLast7d = group.Sum(x =>
                    x.RedeemedAtUtc >= sevenDaysAgo && x.RewardKind == RedeemCodeRewardKind.Spark
                        ? x.RewardValue
                        : 0)
            })
            .FirstOrDefaultAsync(cancellationToken);

        return Result.Success(new AdminRedeemCodeMetricsResponse(
            filteredCodes.Count,
            filteredCodes.Count(code => GetRedeemCodeStatus(code, now) == "active"),
            redemptionStats?.TotalUses ?? 0,
            redemptionStats?.TotalGranted ?? 0,
            filteredCodes.Count(code => code.CreatedAtUtc >= sevenDaysAgo),
            filteredCodes.Count(code => GetRedeemCodeStatus(code, now) == "active" && code.UpdatedAtUtc >= sevenDaysAgo),
            redemptionStats?.UsesLast7d ?? 0,
            redemptionStats?.GrantedLast7d ?? 0));
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

        return Result.Success(ToAdminRedeemCodeResponse(code, [.. redemptions.Select(ToAdminRedeemCodeRedemptionResponse)]));
    }

    private static bool MatchesRedeemCodeStatus(RedeemCode code, string? status, DateTime now)
    {
        if (string.IsNullOrWhiteSpace(status) || status == "all")
        {
            return true;
        }

        return GetRedeemCodeStatus(code, now) == status;
    }

    private static string GetRedeemCodeStatus(RedeemCode code, DateTime now)
    {
        if (!code.IsActive && HasArchiveWindowMarker(code))
        {
            return "archived";
        }

        if (code.RedeemedCount >= code.MaxRedemptions)
        {
            return "exhausted";
        }

        if (code.ExpiresAtUtc.HasValue && code.ExpiresAtUtc.Value <= now)
        {
            return "expired";
        }

        if (!code.IsActive)
        {
            var isDraft =
                code.RedeemedCount == 0 &&
                !code.StartsAtUtc.HasValue &&
                !code.ExpiresAtUtc.HasValue &&
                string.IsNullOrWhiteSpace(code.Description);

            return isDraft ? "draft" : "paused";
        }

        if (code.StartsAtUtc.HasValue && code.StartsAtUtc.Value > now)
        {
            return "scheduled";
        }

        return "active";
    }

    private static bool HasArchiveWindowMarker(RedeemCode code)
    {
        if (!code.StartsAtUtc.HasValue || !code.ExpiresAtUtc.HasValue)
        {
            return false;
        }

        return Math.Abs((code.StartsAtUtc.Value - code.ExpiresAtUtc.Value).TotalSeconds) <= 60;
    }

    private static void SortRedeemCodes(List<RedeemCode> codes, string? sort)
    {
        codes.Sort((first, second) =>
        {
            var comparison = sort switch
            {
                "usage" => FirstNonZero(
                    CompareDescending(first.RedeemedCount, second.RedeemedCount),
                    CompareDescending(first.RewardValue, second.RewardValue)),
                "reward" => FirstNonZero(
                    CompareDescending(first.RewardValue, second.RewardValue),
                    CompareDescending(first.MaxRedemptions, second.MaxRedemptions)),
                "code" => FirstNonZero(
                    string.Compare(first.Code, second.Code, StringComparison.OrdinalIgnoreCase),
                    string.Compare(first.CodePrefix, second.CodePrefix, StringComparison.OrdinalIgnoreCase)),
                "expiry" => FirstNonZero(
                    CompareNullableDateAscending(first.ExpiresAtUtc, second.ExpiresAtUtc),
                    CompareDescending(first.UpdatedAtUtc, second.UpdatedAtUtc)),
                _ => FirstNonZero(
                    CompareDescending(first.UpdatedAtUtc, second.UpdatedAtUtc),
                    CompareDescending(first.CreatedAtUtc, second.CreatedAtUtc))
            };

            return comparison;
        });
    }

    private static int FirstNonZero(params int[] values)
    {
        return values.FirstOrDefault(value => value != 0);
    }

    private static int CompareDescending<T>(T first, T second)
        where T : IComparable<T>
    {
        return second.CompareTo(first);
    }

    private static int CompareNullableDateAscending(DateTime? first, DateTime? second)
    {
        if (first.HasValue && second.HasValue)
        {
            return first.Value.CompareTo(second.Value);
        }

        if (first.HasValue)
        {
            return -1;
        }

        if (second.HasValue)
        {
            return 1;
        }

        return 0;
    }

    private static string? NormalizeListFilter(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim().ToLowerInvariant();
        return normalized.Length > 120 ? normalized[..120] : normalized;
    }

    private static AdminRedeemCodeResponse ToAdminRedeemCodeResponse(
        RedeemCode code,
        IReadOnlyList<AdminRedeemCodeRedemptionResponse> redemptions,
        DateTime? lastRedeemedAtUtc = null,
        int? usesLast7d = null,
        int? grantedLast7d = null,
        int? maxRedeemedBySingleUser = null)
    {
        lastRedeemedAtUtc ??= redemptions
            .OrderByDescending(x => x.RedeemedAtUtc)
            .Select(x => (DateTime?)x.RedeemedAtUtc)
            .FirstOrDefault();
        var sevenDaysAgo = DateTime.UtcNow.AddDays(-7);
        usesLast7d ??= redemptions.Count(x => x.RedeemedAtUtc >= sevenDaysAgo);
        grantedLast7d ??= redemptions
            .Where(x => x.RedeemedAtUtc >= sevenDaysAgo && x.RewardKind == RedeemCodeRewardKind.Spark)
            .Sum(x => x.RewardValue);
        maxRedeemedBySingleUser ??= redemptions
            .GroupBy(x => x.UserId)
            .Select(group => group.Count())
            .DefaultIfEmpty(0)
            .Max();

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
            lastRedeemedAtUtc,
            usesLast7d.Value,
            grantedLast7d.Value,
            maxRedeemedBySingleUser.Value);
    }

    private sealed record AdminRedeemCodeRedemptionPreview(Guid RedeemCodeId, AdminRedeemCodeRedemptionResponse Response);

    private static System.Linq.Expressions.Expression<Func<RedeemCodeRedemption, AdminRedeemCodeRedemptionPreview>> ToAdminRedeemCodeRedemptionResponseProjection()
    {
        return redemption => new AdminRedeemCodeRedemptionPreview(
            redemption.RedeemCodeId,
            new AdminRedeemCodeRedemptionResponse(
                redemption.Id,
                redemption.UserId,
                redemption.RewardKind,
                redemption.RewardValue,
                redemption.WalletLedgerEntryId,
                redemption.PremiumExpiresAtUtc,
                redemption.RedeemedAtUtc));
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
        return WhitespaceRegex().Replace(rawCode.Trim().ToUpperInvariant(), string.Empty);
    }

    private static string NormalizeRewardKind(string rawRewardKind)
    {
        return rawRewardKind.Trim().ToLowerInvariant();
    }

    private static string HashRedeemCode(string normalizedCode)
    {
        var bytes = System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(normalizedCode));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string BuildRedeemCodePrefix(string normalizedCode)
    {
        return normalizedCode[..Math.Min(normalizedCode.Length, 4)];
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    [GeneratedRegex("\\s+", RegexOptions.CultureInvariant)]
    private static partial Regex WhitespaceRegex();
}
