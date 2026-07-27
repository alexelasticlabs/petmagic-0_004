using System.Text.Json;
using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed partial class EconomyAdminRedeemCodeService(
    EconomyDbContext dbContext,
    EconomyAdminAuditOutbox? auditOutbox = null)
{
    private const int AdminRedeemCodeRedemptionsPreviewLimit = 5;

    private readonly EconomyAdminAuditOutbox _auditOutbox = auditOutbox ?? new EconomyAdminAuditOutbox(dbContext);

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
                (x.Code ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CodePrefix ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.Description ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CampaignName ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CampaignChannel ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CreatedBy ?? string.Empty).ToLower().Contains(normalizedSearch));
        }

        if (!string.IsNullOrWhiteSpace(normalizedRewardKind) && normalizedRewardKind != "all")
        {
            codesQuery = codesQuery.Where(x => x.RewardKind == normalizedRewardKind);
        }

        codesQuery = ApplyRedeemCodeStatusFilter(codesQuery, normalizedStatus, now);

        var totalCount = await codesQuery.CountAsync(cancellationToken);
        var pageCodes = await ApplyRedeemCodeSort(codesQuery, normalizedSort)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

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
                (x.Code ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CodePrefix ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.Description ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CampaignName ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CampaignChannel ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.CreatedBy ?? string.Empty).ToLower().Contains(normalizedSearch));
        }

        if (!string.IsNullOrWhiteSpace(normalizedRewardKind) && normalizedRewardKind != "all")
        {
            codesQuery = codesQuery.Where(x => x.RewardKind == normalizedRewardKind);
        }

        codesQuery = ApplyRedeemCodeStatusFilter(codesQuery, normalizedStatus, now);

        var codeStats = await codesQuery
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalCodes = group.Count(),
                ActiveCodes = group.Count(code =>
                    code.IsActive &&
                    code.RedeemedCount < code.MaxRedemptions &&
                    (!code.ExpiresAtUtc.HasValue || code.ExpiresAtUtc.Value > now) &&
                    (!code.StartsAtUtc.HasValue || code.StartsAtUtc.Value <= now)),
                CreatedLast7d = group.Count(code => code.CreatedAtUtc >= sevenDaysAgo),
                ActiveTouchedLast7d = group.Count(code =>
                    code.IsActive &&
                    code.RedeemedCount < code.MaxRedemptions &&
                    (!code.ExpiresAtUtc.HasValue || code.ExpiresAtUtc.Value > now) &&
                    (!code.StartsAtUtc.HasValue || code.StartsAtUtc.Value <= now) &&
                    code.UpdatedAtUtc >= sevenDaysAgo)
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (codeStats is null)
        {
            return Result.Success(new AdminRedeemCodeMetricsResponse(0, 0, 0, 0, 0, 0, 0, 0));
        }

        var codeIds = codesQuery.Select(x => x.Id);
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
            codeStats.TotalCodes,
            codeStats.ActiveCodes,
            redemptionStats?.TotalUses ?? 0,
            redemptionStats?.TotalGranted ?? 0,
            codeStats.CreatedLast7d,
            codeStats.ActiveTouchedLast7d,
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
        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.redeem_code.created",
            "redeem_code",
            code.Id.ToString("D"),
            null,
            DescribeRedeemCode(code),
            "Redeem code created."));
        await dbContext.SaveChangesAsync(cancellationToken);

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

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

        var oldValue = DescribeRedeemCode(code);
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

        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.redeem_code.updated",
            "redeem_code",
            code.Id.ToString("D"),
            oldValue,
            DescribeRedeemCode(code),
            "Redeem code updated."));
        await dbContext.SaveChangesAsync(cancellationToken);

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        var redemptions = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => x.RedeemCodeId == code.Id)
            .OrderByDescending(x => x.RedeemedAtUtc)
            .ToListAsync(cancellationToken);

        return Result.Success(ToAdminRedeemCodeResponse(code, [.. redemptions.Select(ToAdminRedeemCodeRedemptionResponse)]));
    }

    private static IQueryable<RedeemCode> ApplyRedeemCodeStatusFilter(
        IQueryable<RedeemCode> query,
        string? status,
        DateTime now)
    {
        return status switch
        {
            "active" => query.Where(code =>
                code.IsActive &&
                code.RedeemedCount < code.MaxRedemptions &&
                (!code.ExpiresAtUtc.HasValue || code.ExpiresAtUtc.Value > now) &&
                (!code.StartsAtUtc.HasValue || code.StartsAtUtc.Value <= now)),
            "scheduled" => query.Where(code =>
                code.IsActive &&
                code.RedeemedCount < code.MaxRedemptions &&
                (!code.ExpiresAtUtc.HasValue || code.ExpiresAtUtc.Value > now) &&
                code.StartsAtUtc.HasValue &&
                code.StartsAtUtc.Value > now),
            "expired" => query.Where(code =>
                !(!code.IsActive &&
                    code.StartsAtUtc.HasValue &&
                    code.ExpiresAtUtc.HasValue &&
                    code.StartsAtUtc.Value <= code.ExpiresAtUtc.Value.AddSeconds(60) &&
                    code.StartsAtUtc.Value >= code.ExpiresAtUtc.Value.AddSeconds(-60)) &&
                code.RedeemedCount < code.MaxRedemptions &&
                code.ExpiresAtUtc.HasValue &&
                code.ExpiresAtUtc.Value <= now),
            "exhausted" => query.Where(code =>
                !(!code.IsActive &&
                    code.StartsAtUtc.HasValue &&
                    code.ExpiresAtUtc.HasValue &&
                    code.StartsAtUtc.Value <= code.ExpiresAtUtc.Value.AddSeconds(60) &&
                    code.StartsAtUtc.Value >= code.ExpiresAtUtc.Value.AddSeconds(-60)) &&
                code.RedeemedCount >= code.MaxRedemptions),
            "draft" => query.Where(code =>
                !(!code.IsActive &&
                    code.StartsAtUtc.HasValue &&
                    code.ExpiresAtUtc.HasValue &&
                    code.StartsAtUtc.Value <= code.ExpiresAtUtc.Value.AddSeconds(60) &&
                    code.StartsAtUtc.Value >= code.ExpiresAtUtc.Value.AddSeconds(-60)) &&
                !code.IsActive &&
                code.RedeemedCount < code.MaxRedemptions &&
                !code.StartsAtUtc.HasValue &&
                !code.ExpiresAtUtc.HasValue &&
                code.Description == string.Empty),
            "paused" => query.Where(code =>
                !(!code.IsActive &&
                    code.StartsAtUtc.HasValue &&
                    code.ExpiresAtUtc.HasValue &&
                    code.StartsAtUtc.Value <= code.ExpiresAtUtc.Value.AddSeconds(60) &&
                    code.StartsAtUtc.Value >= code.ExpiresAtUtc.Value.AddSeconds(-60)) &&
                !code.IsActive &&
                code.RedeemedCount < code.MaxRedemptions &&
                (!code.ExpiresAtUtc.HasValue || code.ExpiresAtUtc.Value > now) &&
                (code.StartsAtUtc.HasValue || code.ExpiresAtUtc.HasValue || code.Description != string.Empty)),
            "archived" => query.Where(code =>
                !code.IsActive &&
                code.StartsAtUtc.HasValue &&
                code.ExpiresAtUtc.HasValue &&
                code.StartsAtUtc.Value <= code.ExpiresAtUtc.Value.AddSeconds(60) &&
                code.StartsAtUtc.Value >= code.ExpiresAtUtc.Value.AddSeconds(-60)),
            _ => query
        };
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

    private static IOrderedQueryable<RedeemCode> ApplyRedeemCodeSort(IQueryable<RedeemCode> query, string? sort)
    {
        return sort switch
        {
            "usage" => query
                .OrderByDescending(code => code.RedeemedCount)
                .ThenByDescending(code => code.RewardValue)
                .ThenByDescending(code => code.Id),
            "reward" => query
                .OrderByDescending(code => code.RewardValue)
                .ThenByDescending(code => code.MaxRedemptions)
                .ThenByDescending(code => code.Id),
            "code" => query
                .OrderBy(code => code.Code)
                .ThenBy(code => code.CodePrefix)
                .ThenByDescending(code => code.Id),
            "expiry" => query
                .OrderBy(code => code.ExpiresAtUtc == null)
                .ThenBy(code => code.ExpiresAtUtc)
                .ThenByDescending(code => code.UpdatedAtUtc)
                .ThenByDescending(code => code.Id),
            _ => query
                .OrderByDescending(code => code.UpdatedAtUtc)
                .ThenByDescending(code => code.CreatedAtUtc)
                .ThenByDescending(code => code.Id)
        };
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
        var codePrefix = code.CodePrefix ?? string.Empty;
        var description = code.Description ?? string.Empty;
        var rewardKind = code.RewardKind ?? RedeemCodeRewardKind.Spark;
        var displayCode = string.IsNullOrWhiteSpace(code.Code) ? $"{codePrefix}..." : code.Code;

        return new AdminRedeemCodeResponse(
            code.Id,
            displayCode,
            codePrefix,
            description,
            rewardKind,
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

    private static string DescribeRedeemCode(RedeemCode code)
    {
        return JsonSerializer.Serialize(new
        {
            DescriptionConfigured = !string.IsNullOrWhiteSpace(code.Description),
            CampaignNameConfigured = !string.IsNullOrWhiteSpace(code.CampaignName),
            CampaignChannelConfigured = !string.IsNullOrWhiteSpace(code.CampaignChannel),
            code.MinimumSuccessfulPurchases,
            CreatedByConfigured = !string.IsNullOrWhiteSpace(code.CreatedBy),
            code.RewardKind,
            code.RewardValue,
            code.MaxRedemptions,
            code.MaxRedemptionsPerUser,
            code.RedeemedCount,
            code.IsActive,
            code.StartsAtUtc,
            code.ExpiresAtUtc,
        });
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
