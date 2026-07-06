using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportPushTokenService(SupportChatDbContext dbContext) : ISupportPushTokenService
{
    private const int MinTokenLength = 20;
    private const int MaxTokenLength = 4096;
    private const int MaxActiveTokensPerUser = 10;

    public async Task<Result> RegisterAsync(RegisterSupportPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < MinTokenLength || token.Length > MaxTokenLength)
        {
            return Result.Failure(SupportChatErrors.InvalidPushToken);
        }

        var platform = Normalize(command.Platform, "unknown", 32);
        var now = DateTime.UtcNow;
        var existingTokens = await dbContext.SupportPushDeviceTokens
            .Where(x => x.Token == token)
            .OrderBy(x => x.DisabledAtUtc == null ? 0 : 1)
            .ThenByDescending(x => x.LastSeenAtUtc)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .ToListAsync(cancellationToken);
        var existing = existingTokens.FirstOrDefault();

        if (existing is null)
        {
            dbContext.SupportPushDeviceTokens.Add(new SupportPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = command.UserId,
                Token = token,
                Platform = platform,
                DeviceId = NormalizeDeviceId(command.DeviceId),
                AppVersion = NormalizeNullable(command.AppVersion, 64),
                Locale = NormalizeNullable(command.Locale, 16),
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
                LastSeenAtUtc = now
            });
        }
        else
        {
            existing.UserId = command.UserId;
            existing.Platform = platform;
            existing.DeviceId = NormalizeDeviceId(command.DeviceId);
            existing.AppVersion = NormalizeNullable(command.AppVersion, 64);
            existing.Locale = NormalizeNullable(command.Locale, 16);
            existing.UpdatedAtUtc = now;
            existing.LastSeenAtUtc = now;
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

    public async Task<Result> UnregisterAsync(UnregisterSupportPushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (token.Length < MinTokenLength || token.Length > MaxTokenLength)
        {
            return Result.Failure(SupportChatErrors.InvalidPushToken);
        }

        var existingTokens = await dbContext.SupportPushDeviceTokens
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
        var excessTokens = await dbContext.SupportPushDeviceTokens
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
        var normalized = string.IsNullOrWhiteSpace(value) ? fallback : value.Trim().ToLowerInvariant();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string? NormalizeNullable(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string? NormalizeDeviceId(string? value)
    {
        var normalized = NormalizeNullable(value, 128);
        return normalized is null ? null : SafeLogValues.StableHash(normalized);
    }
}
