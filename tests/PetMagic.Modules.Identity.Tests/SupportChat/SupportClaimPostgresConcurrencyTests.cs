using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportClaimPostgresConcurrencyTests
{
    [Fact]
    public async Task ConcurrentClaim_ShouldAllowExactlyOneOperatorOnPostgres()
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        var conversationId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var firstAdminId = Guid.NewGuid();
        var secondAdminId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        await using (var seedContext = new SupportChatDbContext(options))
        {
            seedContext.SupportConversations.Add(new SupportConversation
            {
                Id = conversationId,
                InitiatorUserId = userId,
                Status = SupportConversationStatus.New,
                Priority = SupportConversationPriority.Normal,
                Source = SupportConversationSource.MobileChat,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
                WaitingSinceUtc = now,
            });
            await seedContext.SaveChangesAsync();
        }

        try
        {
            await using var firstContext = new SupportChatDbContext(options);
            await using var secondContext = new SupportChatDbContext(options);
            var users = new SupportOperatorsLookup(firstAdminId, secondAdminId);
            var firstService = CreateService(firstContext, users);
            var secondService = CreateService(secondContext, users);

            var results = await Task.WhenAll(
                firstService.AssignConversationAsync(
                    new AssignSupportConversationCommand(conversationId, firstAdminId, firstAdminId),
                    CancellationToken.None),
                secondService.AssignConversationAsync(
                    new AssignSupportConversationCommand(conversationId, secondAdminId, secondAdminId),
                    CancellationToken.None));

            Assert.Single(results, result => result.IsSuccess);
            var rejected = Assert.Single(results, result => result.IsFailure);
            Assert.Equal(SupportChatErrors.ConversationAlreadyAssigned.Code, rejected.Error.Code);

            await using var verificationContext = new SupportChatDbContext(options);
            var persisted = await verificationContext.SupportConversations
                .AsNoTracking()
                .SingleAsync(x => x.Id == conversationId);
            Assert.True(persisted.AssignedAdminId == firstAdminId || persisted.AssignedAdminId == secondAdminId);
        }
        finally
        {
            await using var cleanupContext = new SupportChatDbContext(options);
            await cleanupContext.SupportConversations
                .Where(x => x.Id == conversationId)
                .ExecuteDeleteAsync();
        }
    }

    private static SupportChatService CreateService(
        SupportChatDbContext dbContext,
        IIdentityUserLookupService users)
    {
        var storageOptions = new SupportAttachmentStorageOptions
        {
            PublicBaseUrl = "http://localhost:5000"
        };
        return new SupportChatService(
            dbContext,
            users,
            new NoopRealtimeNotifier(),
            new NoopPushSender(),
            new NoopAttachmentStorage(),
            new SupportAttachmentReadUrlSigner(
                storageOptions,
                new SupportAttachmentReadUrlSigningOptions
                {
                    SigningKey = new string('s', 64),
                    ReadUrlTtlMinutes = 30
                }),
            storageOptions);
    }

    private sealed class SupportOperatorsLookup(params Guid[] operatorIds) : IIdentityUserLookupService
    {
        private readonly IReadOnlyDictionary<Guid, IdentityUserLookup> users = operatorIds.ToDictionary(
            id => id,
            id => new IdentityUserLookup(id, $"{id:N}@petmagic.test", "Support Operator", [SystemRoles.Admin]));

        public Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
            IReadOnlyCollection<Guid> userIds,
            CancellationToken cancellationToken)
        {
            IReadOnlyDictionary<Guid, IdentityUserLookup> result = users
                .Where(pair => userIds.Contains(pair.Key))
                .ToDictionary();
            return Task.FromResult(result);
        }

        public Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
        {
            users.TryGetValue(userId, out var user);
            return Task.FromResult(user);
        }
    }

    private sealed class NoopRealtimeNotifier : ISupportChatRealtimeNotifier
    {
        public Task NotifyConversationUpdatedAsync(
            SupportConversationRealtimeEvent notification,
            CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class NoopPushSender : ISupportChatPushNotificationSender
    {
        public Task NotifyUserAsync(
            SupportChatPushNotification notification,
            CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class NoopAttachmentStorage : ISupportAttachmentStorage
    {
        public long? ResolveMaxFileSizeBytes(string declaredContentType) => null;

        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken) => throw new NotSupportedException();

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken) =>
            Task.FromResult(Result.Success());
    }
}
