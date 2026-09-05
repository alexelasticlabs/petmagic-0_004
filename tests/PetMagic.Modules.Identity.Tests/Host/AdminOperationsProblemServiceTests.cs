using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Host.Api.Observability;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class AdminOperationsProblemServiceTests
{
    [Fact]
    public async Task GetAsync_ShouldExcludeDismissedDeliveriesWithoutDeletingTheirHistory()
    {
        var services = new ServiceCollection();
        var prefix = Guid.NewGuid().ToString();
        services.AddDbContext<IdentityDbContext>(options => options.UseInMemoryDatabase(prefix + "identity"));
        services.AddDbContext<EconomyDbContext>(options => options.UseInMemoryDatabase(prefix + "economy"));
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(prefix + "templates"));
        services.AddDbContext<SupportChatDbContext>(options => options.UseInMemoryDatabase(prefix + "support"));
        await using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        var contexts = new DbContext[]
        {
            scope.ServiceProvider.GetRequiredService<EconomyDbContext>(),
            scope.ServiceProvider.GetRequiredService<TemplatesDbContext>(),
            scope.ServiceProvider.GetRequiredService<SupportChatDbContext>()
        };
        foreach (var context in contexts)
        {
            foreach (var status in Enum.GetValues<PushOutboxStatus>())
            {
                context.Set<PushOutboxMessage>().Add(new PushOutboxMessage
                {
                    Id = Guid.NewGuid(), DeduplicationKey = Guid.NewGuid().ToString(),
                    Kind = "generation_terminal", Status = status, AttemptCount = 8,
                    PayloadJson = "{\"private\":\"retained\"}", LastErrorCode = "fcm.transport_error",
                    CreatedAtUtc = DateTime.UtcNow.AddDays(-2), UpdatedAtUtc = DateTime.UtcNow
                });
            }
            await context.SaveChangesAsync();
        }

        var service = new AdminOperationsProblemService(provider.GetRequiredService<IServiceScopeFactory>());
        var result = await service.GetAsync("push");

        Assert.Equal(9, result.Items.Count);
        Assert.All(result.Items, item => Assert.Contains(item.Status, new[] { "Queued", "Processing", "DeadLetter" }));
        foreach (var context in contexts)
        {
            var dismissed = await context.Set<PushOutboxMessage>().SingleAsync(x => x.Status == PushOutboxStatus.Dismissed);
            Assert.Equal("{\"private\":\"retained\"}", dismissed.PayloadJson);
            Assert.Equal("fcm.transport_error", dismissed.LastErrorCode);
            Assert.Null(dismissed.SentAtUtc);
        }
    }
}
