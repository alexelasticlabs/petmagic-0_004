using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminNotificationPostgresConcurrencyTests
{
    [Fact]
    public async Task ConcurrentReadAll_ShouldKeepThePersonalReceiptIdempotentOnPostgres()
    {
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        var userId = Guid.NewGuid();
        var deduplicationKey = $"read-all-concurrency:{Guid.NewGuid():N}";
        Guid notificationId;

        await using (var seedContext = new IdentityDbContext(options))
        {
            var service = new IdentityAdminNotificationService(seedContext);
            await service.PublishAsync(
                new AdminNotificationMessage(
                    "system.operator_action_required",
                    1,
                    JsonSerializer.SerializeToElement(new { key = "read-all-concurrency" }),
                    "system",
                    AdminNotificationPriorities.Normal,
                    ["Admin"],
                    "identity_tests",
                    deduplicationKey,
                    "/notifications",
                    TargetUserId: userId),
                CancellationToken.None);
            notificationId = await seedContext.AdminNotificationEvents
                .Where(x => x.Source == "identity_tests" && x.DeduplicationKey == deduplicationKey)
                .Select(x => x.Id)
                .SingleAsync();
        }

        try
        {
            var cutoffUtc = DateTime.UtcNow.AddMinutes(1);
            var requests = Enumerable.Range(0, 6).Select(async _ =>
            {
                await using var context = new IdentityDbContext(options);
                var service = new IdentityAdminNotificationService(context);
                return await service.MarkAllReadAsync(
                    userId,
                    ["Admin"],
                    cutoffUtc,
                    CancellationToken.None);
            });

            var results = await Task.WhenAll(requests);

            Assert.All(results, result => Assert.True(result.IsSuccess));
            await using var verificationContext = new IdentityDbContext(options);
            var receipt = await verificationContext.AdminNotificationReceipts
                .AsNoTracking()
                .SingleAsync(x => x.EventId == notificationId && x.UserId == userId);
            Assert.NotNull(receipt.ReadAtUtc);
        }
        finally
        {
            await using var cleanupContext = new IdentityDbContext(options);
            await cleanupContext.AdminNotificationEvents
                .Where(x => x.Id == notificationId)
                .ExecuteDeleteAsync();
        }
    }
}
