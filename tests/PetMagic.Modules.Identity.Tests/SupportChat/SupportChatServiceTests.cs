using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatServiceTests
{
    [Fact]
    public async Task OpenConversationAsync_ShouldCreateConversationAndInitialUnreadState()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using var scope = await store.CreateScopeAsync();
        var service = scope.CreateService();

        var result = await service.OpenConversationAsync(
            new OpenSupportConversationCommand(userId, "  Help, please  ", SupportConversationPriority.High),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("New", result.Value.Status);
        Assert.Equal("High", result.Value.Priority);
        var userMessage = Assert.Single(result.Value.Messages.Where(message => message.SenderType == "User"));
        Assert.Equal("Help, please", userMessage.Body);
        Assert.False(userMessage.IsFromAdmin);
        Assert.Equal(2, result.Value.Messages.Count(message => message.SenderType == "System"));
        Assert.Equal(1, result.Value.AdminUnreadCount);
        Assert.Equal(0, result.Value.UserUnreadCount);

        var conversation = await scope.SupportDbContext.SupportConversations.Include(x => x.Messages).SingleAsync();
        Assert.Equal(userId, conversation.InitiatorUserId);
        Assert.Equal(SupportConversationStatus.New, conversation.Status);
        Assert.Equal(SupportConversationPriority.High, conversation.Priority);
        Assert.Equal(3, conversation.Messages.Count);
    }

    [Fact]
    public async Task OpenConversationAsync_ShouldSucceedWhenRealtimeNotifierFails()
    {
        var store = CreateStore(new ThrowingSupportChatRealtimeNotifier());

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using var scope = await store.CreateScopeAsync();
        var service = scope.CreateService();

        var result = await service.OpenConversationAsync(
            new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("New", result.Value.Status);

        var conversation = await scope.SupportDbContext.SupportConversations.Include(x => x.Messages).SingleAsync();
        Assert.Equal(userId, conversation.InitiatorUserId);
        Assert.Equal(3, conversation.Messages.Count);
    }

    [Fact]
    public async Task SendMessageAsync_ByAdmin_ShouldAssignConversationAndMoveToWaitingForUser()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);

            conversationId = openResult.Value.ConversationId;
        }

        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, adminId, "We are on it", true),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
            Assert.True(sendResult.Value.IsFromAdmin);
            Assert.Equal("Support Admin", sendResult.Value.SenderDisplayName);
        }

        await using var detailScope = await store.CreateScopeAsync();
        var detail = await detailScope.CreateService().GetAdminConversationAsync(conversationId, CancellationToken.None);

        Assert.True(detail.IsSuccess);
        Assert.Equal("WaitingForUser", detail.Value.Status);
        Assert.Equal(adminId, detail.Value.AssignedAdminId);
        Assert.Equal("Support Admin", detail.Value.AssignedAdminDisplayName);
        Assert.Equal(1, detail.Value.UserUnreadCount);
        Assert.Equal(1, detail.Value.AdminUnreadCount);
        Assert.Equal(1, detail.Value.Messages.Count(message => message.SenderType == "SupportAgent"));
        Assert.Contains(detail.Value.Messages, message => message.SenderType == "System" && message.Body == "Support replied");
        Assert.Contains(store.Notifications, x => x.ConversationId == conversationId);
    }

    [Fact]
    public async Task SendMessageAsync_WithAttachment_ShouldPersistAttachmentMetadata()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        const string attachmentUrl = "http://localhost:5000/support-attachments/2026/05/test-image.png";

        await using var sendScope = await store.CreateScopeAsync();
        var sendResult = await sendScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(
                conversationId,
                userId,
                "Screenshot from the broken screen",
                false,
                attachmentUrl,
                "broken-screen.png",
                "image/png",
                2048),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        Assert.Equal(attachmentUrl, sendResult.Value.AttachmentUrl);
        Assert.Equal("broken-screen.png", sendResult.Value.AttachmentFileName);
        Assert.Equal("image/png", sendResult.Value.AttachmentContentType);
        Assert.Equal(2048, sendResult.Value.AttachmentFileSizeBytes);
    }

    [Fact]
    public async Task SendMessageAsync_WithReplyToMessage_ShouldPersistReplyMetadata()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        Guid replyTargetMessageId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help with premium", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
            replyTargetMessageId = openResult.Value.Messages
                .Single(message => message.SenderType == "User")
                .MessageId;
        }

        await using var sendScope = await store.CreateScopeAsync();
        var sendResult = await sendScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(
                conversationId,
                adminId,
                "Got it, checking now",
                true,
                ReplyToMessageId: replyTargetMessageId),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        Assert.Equal(replyTargetMessageId, sendResult.Value.ReplyToMessageId);
        Assert.Equal("Need help with premium", sendResult.Value.ReplyToPreview);

        var persisted = await sendScope.SupportDbContext.ConversationMessages
            .AsNoTracking()
            .SingleAsync(message => message.Id == sendResult.Value.MessageId);
        Assert.Equal(replyTargetMessageId, persisted.ReplyToMessageId);
        Assert.Equal("Need help with premium", persisted.ReplyToPreview);
    }

    [Fact]
    public async Task SendMessageAsync_WithMissingReplyTarget_ShouldFail()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using var sendScope = await store.CreateScopeAsync();
        var sendResult = await sendScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(
                conversationId,
                userId,
                "Replying to missing message",
                false,
                ReplyToMessageId: Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(sendResult.IsFailure);
        Assert.Equal("support.message_not_found", sendResult.Error.Code);
    }

    [Fact]
    public async Task AssignConversationAsync_ShouldUpdateAssignedAdmin()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminAId = Guid.NewGuid();
        var adminBId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminAId, "admin-a@petmagic.test", "Support Admin A");
        await SeedUserAsync(store, adminBId, "admin-b@petmagic.test", "Support Admin B");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, adminAId, "Taking this case", true),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
        }

        await using var assignScope = await store.CreateScopeAsync();
        var assignResult = await assignScope.CreateService().AssignConversationAsync(
            new AssignSupportConversationCommand(conversationId, adminAId, adminBId),
            CancellationToken.None);

        Assert.True(assignResult.IsSuccess);
        Assert.Equal(adminBId, assignResult.Value.AssignedAdminId);
        Assert.Equal("Support Admin B", assignResult.Value.AssignedAdminDisplayName);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldFilterByAssignmentState()
    {
        var store = CreateStore();

        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userA, "user-a@petmagic.test", "Pet User A");
        await SeedUserAsync(store, userB, "user-b@petmagic.test", "Pet User B");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid assignedConversationId;
        Guid unassignedConversationId;

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            assignedConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userA, "Assigned issue", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;

            unassignedConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userB, "Unassigned issue", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using (var replyScope = await store.CreateScopeAsync())
        {
            var replyResult = await replyScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(assignedConversationId, adminId, "Assigned via first reply", true),
                CancellationToken.None);

            Assert.True(replyResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var serviceForVerification = verificationScope.CreateService();

        var mineResult = await serviceForVerification.ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, AssignedAdminId: adminId),
            CancellationToken.None);

        var unassignedResult = await serviceForVerification.ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, UnassignedOnly: true),
            CancellationToken.None);

        Assert.True(mineResult.IsSuccess);
        Assert.True(unassignedResult.IsSuccess);
        Assert.Single(mineResult.Value);
        Assert.Single(unassignedResult.Value);
        Assert.Equal(assignedConversationId, mineResult.Value[0].ConversationId);
        Assert.Equal(unassignedConversationId, unassignedResult.Value[0].ConversationId);
    }

    [Fact]
    public async Task MarkConversationReadAsync_ByUser_ShouldOnlyMarkAdminMessagesAsRead()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var sendScope = await store.CreateScopeAsync())
        {
            await sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, adminId, "We are on it", true),
                CancellationToken.None);
        }

        await using (var markScope = await store.CreateScopeAsync())
        {
            var markResult = await markScope.CreateService().MarkConversationReadAsync(
                new MarkSupportConversationReadCommand(conversationId, userId, false),
                CancellationToken.None);

            Assert.True(markResult.IsSuccess);
        }

        await using var detailScope = await store.CreateScopeAsync();
        var detail = await detailScope.CreateService().GetUserConversationAsync(userId, CancellationToken.None);
        Assert.True(detail.IsSuccess);
        Assert.Equal(0, detail.Value.UserUnreadCount);
        Assert.Equal(1, detail.Value.AdminUnreadCount);
        Assert.True(detail.Value.Messages.Single(x => x.SenderType == "SupportAgent").IsRead);
        Assert.False(detail.Value.Messages.Single(x => !x.IsFromAdmin).IsRead);
    }

    [Fact]
    public async Task SendMessageAsync_ByUserAfterResolved_ShouldReopenConversation()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var outsiderId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");
        await SeedUserAsync(store, outsiderId, "outsider@petmagic.test", "Outsider");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var updateScope = await store.CreateScopeAsync())
        {
            var updateResult = await updateScope.CreateService().UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(updateResult.IsSuccess);
            Assert.Equal("Closed", updateResult.Value.Status);
        }

        await using (var reopenScope = await store.CreateScopeAsync())
        {
            var reopenResult = await reopenScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, userId, "Issue is back", false),
                CancellationToken.None);

            Assert.True(reopenResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var conversation = await verificationScope.SupportDbContext.SupportConversations.SingleAsync();
        Assert.Equal(SupportConversationStatus.New, conversation.Status);
        Assert.Null(conversation.ResolvedAtUtc);

        var forbiddenResult = await verificationScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(conversationId, outsiderId, "Let me in", false),
            CancellationToken.None);

        Assert.True(forbiddenResult.IsFailure);
        Assert.Equal("support.forbidden", forbiddenResult.Error.Code);
    }

    [Fact]
    public async Task SendMessageAsync_ByUserAfterClosed_ShouldReopenConversation()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var closeScope = await store.CreateScopeAsync())
        {
            var closeResult = await closeScope.CreateService().UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(closeResult.IsSuccess);
            Assert.Equal("Closed", closeResult.Value.Status);
            Assert.True(closeResult.Value.IsReadOnly);
        }

        await using (var reopenScope = await store.CreateScopeAsync())
        {
            var reopenResult = await reopenScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, userId, "I still need help", false),
                CancellationToken.None);

            Assert.True(reopenResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var conversation = await verificationScope.SupportDbContext.SupportConversations.SingleAsync();
        Assert.Equal(SupportConversationStatus.New, conversation.Status);
        Assert.Null(conversation.ClosedAtUtc);
        Assert.Null(conversation.ResolvedAtUtc);
    }

    [Fact]
    public async Task SendMessageAsync_AfterClosed_ShouldSucceed()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var resolveScope = await store.CreateScopeAsync())
        {
            var resolveResult = await resolveScope.CreateService().UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(resolveResult.IsSuccess);
        }

        await using var sendScope = await store.CreateScopeAsync();
        var sendResult = await sendScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(conversationId, userId, "Issue is back", false),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
    }

    [Fact]
    public async Task SubmitConversationFeedbackAsync_AfterClosed_ShouldPersistRating()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var resolveScope = await store.CreateScopeAsync())
        {
            var resolveResult = await resolveScope.CreateService().ResolveConversationAsync(
                new ResolveSupportConversationCommand(conversationId, userId, IsAdmin: false),
                CancellationToken.None);

            Assert.True(resolveResult.IsSuccess);
            Assert.Equal("Closed", resolveResult.Value.Status);
            Assert.True(resolveResult.Value.CanReopen);
            Assert.True(resolveResult.Value.IsReadOnly);
            Assert.Null(resolveResult.Value.ReopenUntilUtc);
        }

        await using var feedbackScope = await store.CreateScopeAsync();
        var feedbackResult = await feedbackScope.CreateService().SubmitConversationFeedbackAsync(
            new SubmitSupportConversationFeedbackCommand(conversationId, userId, 5, "Thanks"),
            CancellationToken.None);

        Assert.True(feedbackResult.IsSuccess);
        Assert.Equal(5, feedbackResult.Value.FeedbackRating);
        Assert.Equal("Thanks", feedbackResult.Value.FeedbackComment);
        Assert.NotNull(feedbackResult.Value.FeedbackSubmittedAtUtc);
    }

    [Fact]
    public async Task UpdateConversationStatusAsync_FromClosedToWaitingForUser_ShouldFail()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            conversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;

            var closeResult = await service.UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(closeResult.IsSuccess);
            Assert.Equal("Closed", closeResult.Value.Status);
        }

        await using var invalidScope = await store.CreateScopeAsync();
        var invalidResult = await invalidScope.CreateService().UpdateConversationStatusAsync(
            new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.WaitingForUser),
            CancellationToken.None);

        Assert.True(invalidResult.IsFailure);
        Assert.Equal("support.status_transition_invalid", invalidResult.Error.Code);

        var conversation = await invalidScope.SupportDbContext.SupportConversations.SingleAsync();
        Assert.Equal(SupportConversationStatus.Closed, conversation.Status);
    }

    [Fact]
    public async Task SendMessageAsync_FirstUserMessage_ShouldAppendLocalizedAutomaticReply()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, null, SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, userId, "Necesito ayuda", false, Locale: "es-ES"),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
            Assert.False(sendResult.Value.IsFromAdmin);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var detail = await verificationScope.CreateService().GetUserConversationAsync(userId, CancellationToken.None);

        Assert.True(detail.IsSuccess);
        Assert.Equal("New", detail.Value.Status);
        Assert.Null(detail.Value.AssignedAdminId);
        var userMessage = Assert.Single(detail.Value.Messages.Where(message => message.SenderType == "User"));
        Assert.Equal("Necesito ayuda", userMessage.Body);
        var botReply = Assert.Single(detail.Value.Messages.Where(message => message.SenderType == "Bot"));
        Assert.Equal(
            "Mensaje recibido. Soporte respondera en este chat.",
            botReply.Body);
        Assert.True(botReply.IsFromAdmin);
        Assert.True(botReply.IsRead);
        Assert.Equal(1, detail.Value.AdminUnreadCount);
        Assert.Equal(0, detail.Value.UserUnreadCount);
    }

    private static TestStore CreateStore(ISupportChatRealtimeNotifier? realtimeNotifier = null)
    {
        return new TestStore(
            $"support-chat-tests-{Guid.NewGuid():N}",
            $"support-chat-identity-tests-{Guid.NewGuid():N}",
            realtimeNotifier);
    }

    private static async Task SeedUserAsync(TestStore store, Guid userId, string email, string displayName)
    {
        await using var scope = await store.CreateScopeAsync();

        scope.IdentityDbContext.Users.Add(new AppUser
        {
            Id = userId,
            UserName = email,
            NormalizedUserName = email.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = true,
            DisplayName = displayName,
            IsActive = true,
            IsPremium = false
        });

        await scope.IdentityDbContext.SaveChangesAsync();
    }

    private sealed class TestStore(string supportDatabaseName, string identityDatabaseName, ISupportChatRealtimeNotifier? realtimeNotifier = null)
    {
        private readonly ISupportChatRealtimeNotifier notifier = realtimeNotifier ?? new FakeSupportChatRealtimeNotifier();

        public IReadOnlyList<SupportConversationRealtimeEvent> Notifications => notifier is FakeSupportChatRealtimeNotifier fakeNotifier
            ? fakeNotifier.Events
            : [];

        public async Task<TestScope> CreateScopeAsync()
        {
            var supportOptions = new DbContextOptionsBuilder<SupportChatDbContext>()
                .UseInMemoryDatabase(supportDatabaseName)
                .Options;
            var identityOptions = new DbContextOptionsBuilder<IdentityDbContext>()
                .UseInMemoryDatabase(identityDatabaseName)
                .Options;

            var supportDbContext = new SupportChatDbContext(supportOptions);
            var identityDbContext = new IdentityDbContext(identityOptions);
            await identityDbContext.Database.EnsureCreatedAsync();
            await supportDbContext.Database.EnsureCreatedAsync();

            return new TestScope(supportDbContext, identityDbContext, notifier);
        }
    }

    private sealed class TestScope(
        SupportChatDbContext supportDbContext,
        IdentityDbContext identityDbContext,
        ISupportChatRealtimeNotifier realtimeNotifier) : IAsyncDisposable
    {
        public SupportChatDbContext SupportDbContext { get; } = supportDbContext;

        public IdentityDbContext IdentityDbContext { get; } = identityDbContext;

        public SupportChatService CreateService()
        {
            return new SupportChatService(
                SupportDbContext,
                new IdentityUserLookupService(IdentityDbContext),
                realtimeNotifier,
                new NoopSupportChatPushNotificationSender(),
                new NoopSupportAttachmentStorage(),
                new SupportAttachmentStorageOptions());
        }

        public async ValueTask DisposeAsync()
        {
            await SupportDbContext.DisposeAsync();
            await IdentityDbContext.DisposeAsync();
        }
    }

    private sealed class FakeSupportChatRealtimeNotifier : ISupportChatRealtimeNotifier
    {
        private readonly List<SupportConversationRealtimeEvent> events = [];

        public IReadOnlyList<SupportConversationRealtimeEvent> Events => events;

        public Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken)
        {
            events.Add(notification);
            return Task.CompletedTask;
        }
    }

    private sealed class ThrowingSupportChatRealtimeNotifier : ISupportChatRealtimeNotifier
    {
        public Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("realtime hub is unavailable");
        }
    }

    private sealed class NoopSupportChatPushNotificationSender : ISupportChatPushNotificationSender
    {
        public Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private sealed class NoopSupportAttachmentStorage : ISupportAttachmentStorage
    {
        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken)
        {
            var fileName = string.IsNullOrWhiteSpace(attachment.FileName) ? "attachment.bin" : attachment.FileName;
            var contentType = string.IsNullOrWhiteSpace(attachment.ContentType) ? "application/octet-stream" : attachment.ContentType;
            var storageKey = $"support-attachments/test/{Guid.NewGuid():N}";
            return Task.FromResult(Result.Success(
                new StoredSupportAttachmentResponse(
                    Url: $"https://example.test/{storageKey}",
                    StorageKey: storageKey,
                    FileName: fileName,
                    ContentType: contentType,
                    FileSizeBytes: attachment.Content.LongLength,
                    LocalPath: null)));
        }

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }
    }
}
