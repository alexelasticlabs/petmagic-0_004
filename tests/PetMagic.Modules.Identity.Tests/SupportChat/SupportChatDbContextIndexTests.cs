using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.SupportChat.Application.Contracts;
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

    [Fact]
    public void ConversationMessages_ShouldKeepUniqueAdminIdempotencyIndex()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase($"support-chat-idempotency-index-{Guid.NewGuid()}")
            .Options;

        using var dbContext = new SupportChatDbContext(options);

        var entity = dbContext.Model.FindEntityType(typeof(ConversationMessage));

        Assert.NotNull(entity);
        Assert.Contains(
            entity.GetIndexes(),
            index => index.IsUnique
                && index.Properties.Select(property => property.Name).SequenceEqual(
                    ["ConversationId", "SenderUserId", "ClientIdempotencyKey"]));
    }

    [Fact]
    public void SupportMessages_ShouldUseSharedIdempotencyKeyConstraints()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase($"support-chat-idempotency-{Guid.NewGuid()}")
            .Options;

        using var dbContext = new SupportChatDbContext(options);

        var entity = dbContext.Model.FindEntityType(typeof(ConversationMessage));

        Assert.NotNull(entity);
        Assert.Equal(
            SupportMessageIdempotency.MaxKeyLength,
            entity.FindProperty(nameof(ConversationMessage.ClientIdempotencyKey))?.GetMaxLength());
        AssertIndex(entity, ["ConversationId", "SenderUserId", "ClientIdempotencyKey"]);
    }

    private static void AssertIndex(Microsoft.EntityFrameworkCore.Metadata.IEntityType? entity, string[] properties)
    {
        Assert.NotNull(entity);
        Assert.Contains(
            entity.GetIndexes(),
            index => index.Properties.Select(property => property.Name).SequenceEqual(properties));
    }
}
