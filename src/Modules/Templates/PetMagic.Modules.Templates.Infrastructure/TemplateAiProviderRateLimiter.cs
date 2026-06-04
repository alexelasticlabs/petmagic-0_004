using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateAiProviderRateLimiter(
    TemplatesDbContext dbContext,
    TemplatesOptions options)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private static readonly object LocalLock = new();
    private static readonly Dictionary<(string Provider, DateTime BucketUtc), int> LocalPermitCounts = [];

    public async Task WaitForPermitAsync(string provider, CancellationToken cancellationToken)
    {
        var maxRequestsPerMinute = options.MaxAiProviderRequestsPerMinute;
        if (maxRequestsPerMinute <= 0)
        {
            return;
        }

        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var now = DateTime.UtcNow;
            var bucketUtc = TruncateToMinute(now);

            var acquired = string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
                ? await TryAcquirePostgresPermitAsync(provider, bucketUtc, maxRequestsPerMinute, now, cancellationToken)
                : TryAcquireLocalPermit(provider, bucketUtc, maxRequestsPerMinute);

            if (acquired)
            {
                return;
            }

            var nextBucketUtc = bucketUtc.AddMinutes(1);
            var delay = nextBucketUtc - now;
            if (delay <= TimeSpan.Zero || delay > TimeSpan.FromMinutes(1))
            {
                delay = TimeSpan.FromSeconds(1);
            }

            await Task.Delay(delay, cancellationToken);
        }
    }

    private async Task<bool> TryAcquirePostgresPermitAsync(
        string provider,
        DateTime bucketUtc,
        int maxRequestsPerMinute,
        DateTime now,
        CancellationToken cancellationToken)
    {
        await dbContext.Database.ExecuteSqlRawAsync(
            """
            DELETE FROM templates_ai_provider_request_permits
            WHERE "BucketUtc" < {0}
            """,
            [bucketUtc.AddMinutes(-2)],
            cancellationToken);

        var permitId = Guid.NewGuid();
        var acquiredPermitIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            WITH available AS (
                SELECT permit_number
                FROM generate_series(1, {2}) AS permits(permit_number)
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM templates_ai_provider_request_permits existing
                    WHERE existing."Provider" = {0}
                        AND existing."BucketUtc" = {1}
                        AND existing."PermitNumber" = permit_number
                )
                ORDER BY permit_number
                LIMIT 1
            ),
            inserted AS (
                INSERT INTO templates_ai_provider_request_permits (
                    "Id",
                    "Provider",
                    "BucketUtc",
                    "PermitNumber",
                    "CreatedAtUtc")
                SELECT {3}, {0}, {1}, permit_number, {4}
                FROM available
                ON CONFLICT ("Provider", "BucketUtc", "PermitNumber") DO NOTHING
                RETURNING "Id"
            )
            SELECT "Id" AS "Value"
            FROM inserted
            """,
            provider,
            bucketUtc,
            maxRequestsPerMinute,
            permitId,
            now)
            .ToListAsync(cancellationToken);

        return acquiredPermitIds.Count > 0;
    }

    private static bool TryAcquireLocalPermit(string provider, DateTime bucketUtc, int maxRequestsPerMinute)
    {
        lock (LocalLock)
        {
            foreach (var key in LocalPermitCounts.Keys.Where(x => x.BucketUtc < bucketUtc.AddMinutes(-2)).ToArray())
            {
                LocalPermitCounts.Remove(key);
            }

            var countKey = (provider, bucketUtc);
            LocalPermitCounts.TryGetValue(countKey, out var current);
            if (current >= maxRequestsPerMinute)
            {
                return false;
            }

            LocalPermitCounts[countKey] = current + 1;
            return true;
        }
    }

    private static DateTime TruncateToMinute(DateTime value)
    {
        return new DateTime(value.Year, value.Month, value.Day, value.Hour, value.Minute, 0, DateTimeKind.Utc);
    }
}
