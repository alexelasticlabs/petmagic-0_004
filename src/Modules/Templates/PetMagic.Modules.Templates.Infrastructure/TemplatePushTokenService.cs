using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePushTokenService(TemplatesDbContext dbContext) : ITemplatePushTokenService
{
    private const int MaxTokenLength = 4096;

    public async Task<Result> RegisterAsync(RegisterTemplatePushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (string.IsNullOrWhiteSpace(token) || token.Length > MaxTokenLength)
        {
            return Result.Failure(TemplatesErrors.InvalidPushToken);
        }

        var platform = Normalize(command.Platform, "unknown", 32);
        var now = DateTime.UtcNow;
        var existing = await dbContext.TemplatePushDeviceTokens
            .SingleOrDefaultAsync(x => x.Token == token, cancellationToken);

        if (existing is null)
        {
            dbContext.TemplatePushDeviceTokens.Add(new TemplatePushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = command.UserId,
                Token = token,
                Platform = platform,
                DeviceId = NormalizeNullable(command.DeviceId, 128),
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
            existing.DeviceId = NormalizeNullable(command.DeviceId, 128);
            existing.AppVersion = NormalizeNullable(command.AppVersion, 64);
            existing.Locale = NormalizeNullable(command.Locale, 16);
            existing.UpdatedAtUtc = now;
            existing.LastSeenAtUtc = now;
            existing.DisabledAtUtc = null;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> UnregisterAsync(UnregisterTemplatePushTokenCommand command, CancellationToken cancellationToken)
    {
        var token = command.Token.Trim();
        if (string.IsNullOrWhiteSpace(token))
        {
            return Result.Success();
        }

        var existing = await dbContext.TemplatePushDeviceTokens
            .SingleOrDefaultAsync(x => x.UserId == command.UserId && x.Token == token, cancellationToken);
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
}
