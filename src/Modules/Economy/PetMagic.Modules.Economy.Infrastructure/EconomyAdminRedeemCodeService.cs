using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyAdminRedeemCodeService(EconomyDbContext dbContext)
{
    public async Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken)
    {
        var codes = await dbContext.RedeemCodes
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var codeIds = codes.Select(x => x.Id).ToArray();
        var redemptions = await dbContext.RedeemCodeRedemptions
            .AsNoTracking()
            .Where(x => codeIds.Contains(x.RedeemCodeId))
            .OrderByDescending(x => x.RedeemedAtUtc)
            .ToListAsync(cancellationToken);

        var redemptionsByCode = redemptions
            .GroupBy(x => x.RedeemCodeId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<AdminRedeemCodeRedemptionResponse>)group
                    .Select(ToAdminRedeemCodeRedemptionResponse)
                    .ToList());

        var result = codes
            .Select(code => ToAdminRedeemCodeResponse(code, redemptionsByCode.GetValueOrDefault(code.Id) ?? []))
            .ToList();

        return Result.Success<IReadOnlyList<AdminRedeemCodeResponse>>(result);
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

        return Result.Success(ToAdminRedeemCodeResponse(code, redemptions.Select(ToAdminRedeemCodeRedemptionResponse).ToList()));
    }

    private static AdminRedeemCodeResponse ToAdminRedeemCodeResponse(
        RedeemCode code,
        IReadOnlyList<AdminRedeemCodeRedemptionResponse> redemptions)
    {
        var lastRedeemedAtUtc = redemptions
            .OrderByDescending(x => x.RedeemedAtUtc)
            .Select(x => (DateTime?)x.RedeemedAtUtc)
            .FirstOrDefault();

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
            lastRedeemedAtUtc);
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
        return Regex.Replace(rawCode.Trim().ToUpperInvariant(), "\\s+", string.Empty, RegexOptions.CultureInvariant);
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
}
