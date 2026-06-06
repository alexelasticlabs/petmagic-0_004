using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatDbContextIndexTests
{
    [Fact]
    public void SupportConversations_ShouldKeepAdminInboxPerformanceIndexes()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase($"support-chat-indexes-{Guid.NewGuid()}")
            .Options;

        using var dbContext = new SupportChatDbContext(options);

        var entity = dbContext.Model.FindEntityType(typeof(SupportConversation));

        Assert.NotNull(entity);
        AssertIndex(entity, ["Status", "UpdatedAtUtc"]);
        AssertIndex(entity, ["Status", "Priority", "UpdatedAtUtc"]);
        AssertIndex(entity, ["Source", "Status", "UpdatedAtUtc"]);
        AssertIndex(entity, ["AssignedAdminId", "Status", "UpdatedAtUtc"]);
    }

    private static void AssertIndex(Microsoft.EntityFrameworkCore.Metadata.IEntityType? entity, string[] properties)
    {
        Assert.NotNull(entity);
        Assert.Contains(
            entity.GetIndexes(),
            index => index.Properties.Select(property => property.Name).SequenceEqual(properties));
    }
}
