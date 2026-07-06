using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyPushTokenService(EconomyDbContext dbContext) : IEconomyPushTokenService
{
    private const int MaxTokenLength = 512;
    private const int MaxActiveTokensPerUser = 10;

    public async Task<Result> RegisterAsync(RegisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < 20 || token.Length > MaxTokenLength)
        {
            return Result.Failure(EconomyErrors.InvalidPushToken);
        }

        var now = DateTime.UtcNow;
        var existingTokens = await dbContext.EconomyPushDeviceTokens
            .Where(x => x.Token == token)
            .OrderBy(x => x.DisabledAtUtc == null ? 0 : 1)
            .ThenByDescending(x => x.LastSeenAtUtc)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .ToListAsync(cancellationToken);
        var existing = existingTokens.FirstOrDefault();

        if (existing is null)
        {
            dbContext.EconomyPushDeviceTokens.Add(new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = command.UserId,
                Token = token,
                Platform = Normalize(command.Platform, "unknown", 32),
                DeviceId = NormalizeDeviceId(command.DeviceId),
                AppVersion = NormalizeNullable(command.AppVersion, 64),
                Locale = NormalizeNullable(command.Locale, 32),
                LastSeenAtUtc = now,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
        }
        else
        {
            existing.UserId = command.UserId;
            existing.Platform = Normalize(command.Platform, existing.Platform, 32);
            existing.DeviceId = NormalizeDeviceId(command.DeviceId);
            existing.AppVersion = NormalizeNullable(command.AppVersion, 64);
            existing.Locale = NormalizeNullable(command.Locale, 32);
            existing.LastSeenAtUtc = now;
            existing.UpdatedAtUtc = now;
            existing.DisabledAtUtc = null;

            foreach (var duplicate in existingTokens.Skip(1))
            {
                duplicate.DisabledAtUtc = now;
                duplicate.UpdatedAtUtc = now;
            }
        }

        await DisableExcessActiveTokensAsync(command.UserId, token, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> UnregisterAsync(UnregisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < 20 || token.Length > MaxTokenLength)
        {
            return Result.Failure(EconomyErrors.InvalidPushToken);
        }

        var existingTokens = await dbContext.EconomyPushDeviceTokens
            .Where(x => x.UserId == command.UserId && x.Token == token)
            .ToListAsync(cancellationToken);

        if (existingTokens.Count == 0)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        foreach (var existing in existingTokens)
        {
            existing.DisabledAtUtc = now;
            existing.UpdatedAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    private async Task DisableExcessActiveTokensAsync(
        Guid userId,
        string currentToken,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var excessTokens = await dbContext.EconomyPushDeviceTokens
            .Where(x => x.UserId == userId && x.Token != currentToken && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .Skip(MaxActiveTokensPerUser - 1)
            .ToListAsync(cancellationToken);

        foreach (var excess in excessTokens)
        {
            excess.DisabledAtUtc = now;
            excess.UpdatedAtUtc = now;
        }
    }

    private static string Normalize(string? value, string fallback, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return fallback;
        }

        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }

    private static string? NormalizeNullable(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }

    private static string? NormalizeDeviceId(string? value)
    {
        var normalized = NormalizeNullable(value, 160);
        return normalized is null ? null : SafeLogValues.StableHash(normalized);
    }
}
