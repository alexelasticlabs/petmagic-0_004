using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyPushTokenService(EconomyDbContext dbContext) : IEconomyPushTokenService
{
    public async Task<Result> RegisterAsync(RegisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < 20)
        {
            return Result.Failure(EconomyErrors.InvalidPushToken);
        }

        var now = DateTime.UtcNow;
        var existing = await dbContext.EconomyPushDeviceTokens
            .FirstOrDefaultAsync(x => x.Token == token, cancellationToken);

        if (existing is null)
        {
            dbContext.EconomyPushDeviceTokens.Add(new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = command.UserId,
                Token = token,
                Platform = Normalize(command.Platform, "unknown", 32),
                DeviceId = NormalizeNullable(command.DeviceId, 160),
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
            existing.DeviceId = NormalizeNullable(command.DeviceId, 160);
            existing.AppVersion = NormalizeNullable(command.AppVersion, 64);
            existing.Locale = NormalizeNullable(command.Locale, 32);
            existing.LastSeenAtUtc = now;
            existing.UpdatedAtUtc = now;
            existing.DisabledAtUtc = null;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> UnregisterAsync(UnregisterEconomyPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < 20)
        {
            return Result.Success();
        }

        var existing = await dbContext.EconomyPushDeviceTokens
            .FirstOrDefaultAsync(x => x.Token == token, cancellationToken);

        if (existing is null)
        {
            return Result.Success();
        }

        existing.DisabledAtUtc = DateTime.UtcNow;
        existing.UpdatedAtUtc = existing.DisabledAtUtc.Value;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
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
}
