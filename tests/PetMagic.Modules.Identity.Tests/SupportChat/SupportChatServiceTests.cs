using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatServiceTests
{
    [Fact]
    public async Task OpenConversationAsync_ShouldCreateNormalPriorityConversationAndInitialUnreadState()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using var scope = await store.CreateScopeAsync();
        var service = scope.CreateService();

        var result = await service.OpenConversationAsync(
            new OpenSupportConversationCommand(userId, "  Help, please  ", SupportConversationPriority.Normal),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("New", result.Value.Status);
        Assert.Equal("Normal", result.Value.Priority);
        var userMessage = Assert.Single(result.Value.Messages, message => message.SenderType == "User");
        Assert.Equal("Help, please", userMessage.Body);
        Assert.False(userMessage.IsFromAdmin);
        Assert.Equal(2, result.Value.Messages.Count(message => message.SenderType == "System"));
        Assert.Equal(1, result.Value.AdminUnreadCount);
        Assert.Equal(0, result.Value.UserUnreadCount);

        var conversation = await scope.SupportDbContext.SupportConversations.Include(x => x.Messages).SingleAsync();
        Assert.Equal(userId, conversation.InitiatorUserId);
        Assert.Equal(SupportConversationStatus.New, conversation.Status);
        Assert.Equal(SupportConversationPriority.Normal, conversation.Priority);
        Assert.Equal(3, conversation.Messages.Count);
    }

    [Fact]
    public async Task OpenConversationAsync_ShouldSucceedWhenRealtimeNotifierFails()
    {
        var logger = new CapturingLogger<SupportChatService>();
        var store = CreateStore(
            realtimeNotifier: new ThrowingSupportChatRealtimeNotifier(),
            logger: logger);

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
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Support chat notification fan-out failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("conversation_update", entry.Properties["Operation"]);
        Assert.Equal("realtime", entry.Properties["Channel"]);
        Assert.Equal(SafeLogValues.StableHash(conversation.Id.ToString("D")), entry.Properties["ConversationIdHash"]);
        Assert.Equal(SafeLogValues.StableHash(userId.ToString("D")), entry.Properties["InitiatorUserIdHash"]);
        Assert.False(entry.Properties.ContainsKey("ConversationId"));
        Assert.False(entry.Properties.ContainsKey("InitiatorUserId"));
        Assert.Equal("InvalidOperationException", entry.Properties["ExceptionType"]);
        Assert.Null(entry.Exception);
    }

    [Fact]
    public async Task SendMessageAsync_ByAdmin_ShouldNotPersistReplyWhenDurablePushEnqueueFails()
    {
        var store = CreateStore(
            pushNotificationSender: new ThrowingSupportChatPushNotificationSender());

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        await using var sendScope = await store.CreateScopeAsync();
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(conversationId, adminId, "We are on it", true),
                CancellationToken.None));
        Assert.Equal("push provider is unavailable", exception.Message);

        await using var verificationScope = await store.CreateScopeAsync();
        var persistedConversation = await verificationScope.SupportDbContext.SupportConversations
            .Include(x => x.Messages)
            .SingleAsync(x => x.Id == conversationId);
        Assert.DoesNotContain(persistedConversation.Messages, message => message.Body == "We are on it");
    }

    [Fact]
    public async Task SendMessageAsync_ByAdmin_ShouldAssignConversationAndMoveToWaitingForUser()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);

            conversationId = openResult.Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

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
    public async Task SendMessageAsync_ByAdmin_ShouldReturnExistingMessageForSameIdempotencyKey()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        const string idempotencyKey = "admin-support-reply:retry-safe";
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        SupportMessageResponse firstMessage;
        await using (var firstScope = await store.CreateScopeAsync())
        {
            var firstResult = await firstScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(
                    conversationId,
                    adminId,
                    "We are investigating",
                    IsAdmin: true,
                    IdempotencyKey: $"  {idempotencyKey}  "),
                CancellationToken.None);

            Assert.True(firstResult.IsSuccess);
            Assert.False(firstResult.Value.IsIdempotencyReplay);
            firstMessage = firstResult.Value;
        }

        await using (var replayScope = await store.CreateScopeAsync())
        {
            var replayResult = await replayScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(
                    conversationId,
                    adminId,
                    "We are investigating",
                    IsAdmin: true,
                    IdempotencyKey: idempotencyKey),
                CancellationToken.None);

            Assert.True(replayResult.IsSuccess);
            Assert.True(replayResult.Value.IsIdempotencyReplay);
            Assert.Equal(firstMessage.MessageId, replayResult.Value.MessageId);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var persistedMessages = await verificationScope.SupportDbContext.ConversationMessages
            .Where(message => message.ConversationId == conversationId)
            .ToListAsync();
        var persistedReply = Assert.Single(persistedMessages, message => message.SenderType == SupportMessageSenderType.SupportAgent);
        Assert.Equal(idempotencyKey, persistedReply.ClientIdempotencyKey);
        Assert.Single(persistedMessages, message => message.SenderType == SupportMessageSenderType.System && message.Body == "Support replied");
    }

    [Fact]
    public async Task SendMessageAsync_ByAdmin_ShouldRejectInvalidIdempotencyKeyBeforePersistingReply()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(
                    conversationId,
                    adminId,
                    "We are investigating",
                    IsAdmin: true,
                    IdempotencyKey: "   "),
                CancellationToken.None);

            Assert.True(sendResult.IsFailure);
            Assert.Equal("support.idempotency_key_invalid", sendResult.Error.Code);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        Assert.DoesNotContain(
            await verificationScope.SupportDbContext.ConversationMessages
                .Where(message => message.ConversationId == conversationId)
                .ToListAsync(),
            message => message.SenderType == SupportMessageSenderType.SupportAgent);
    }

    [Fact]
    public async Task CreateAttachmentMessageAsync_ByAdmin_ShouldReturnExistingMessageForSameIdempotencyKey()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        const string idempotencyKey = "admin-support-attachment:retry-safe";
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need attachment review", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        SupportMessageResponse firstMessage;
        await using (var firstScope = await store.CreateScopeAsync())
        {
            var firstResult = await firstScope.CreateService().CreateAttachmentMessageAsync(
                new CreateSupportAttachmentMessageCommand(
                    conversationId,
                    adminId,
                    "Screenshot attached",
                    IsAdmin: true,
                    AttachmentFileName: "issue.png",
                    AttachmentContentType: "image/png",
                    IdempotencyKey: idempotencyKey),
                CancellationToken.None);

            Assert.True(firstResult.IsSuccess);
            Assert.False(firstResult.Value.IsIdempotencyReplay);
            firstMessage = firstResult.Value;
        }

        await using (var replayScope = await store.CreateScopeAsync())
        {
            var replayResult = await replayScope.CreateService().CreateAttachmentMessageAsync(
                new CreateSupportAttachmentMessageCommand(
                    conversationId,
                    adminId,
                    "Screenshot attached",
                    IsAdmin: true,
                    AttachmentFileName: "issue.png",
                    AttachmentContentType: "image/png",
                    IdempotencyKey: idempotencyKey),
                CancellationToken.None);

            Assert.True(replayResult.IsSuccess);
            Assert.True(replayResult.Value.IsIdempotencyReplay);
            Assert.Equal(firstMessage.MessageId, replayResult.Value.MessageId);
            Assert.Equal("Uploading", replayResult.Value.AttachmentUploadStatus);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var persistedMessages = await verificationScope.SupportDbContext.ConversationMessages
            .Where(message => message.ConversationId == conversationId)
            .ToListAsync();
        var persistedReply = Assert.Single(persistedMessages, message => message.SenderType == SupportMessageSenderType.SupportAgent);
        Assert.Equal(idempotencyKey, persistedReply.ClientIdempotencyKey);
        Assert.Single(persistedMessages, message => message.SenderType == SupportMessageSenderType.System && message.Body == "Support replied");
    }

    [Fact]
    public async Task AssignConversationAsync_ForNewConversation_ShouldMoveToInProgress()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need billing help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using var assignScope = await store.CreateScopeAsync();
        var assignResult = await assignScope.CreateService().AssignConversationAsync(
            new AssignSupportConversationCommand(
                conversationId,
                adminId,
                adminId,
                "Assign support operator.",
                ExpectedVersion: 1),
            CancellationToken.None);

        Assert.True(assignResult.IsSuccess);
        Assert.Equal("InProgress", assignResult.Value.Status);
        Assert.Equal(adminId, assignResult.Value.AssignedAdminId);
        Assert.Equal("Support Admin", assignResult.Value.AssignedAdminDisplayName);
        Assert.Equal(new[] { "close", "unassign" }, assignResult.Value.AvailableActions);
        Assert.Contains(
            assignResult.Value.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket assigned to operator");
        Assert.Contains(
            assignResult.Value.Messages,
            message => message.SenderType == "System" && message.Body == "Status changed: New -> InProgress");
    }

    [Fact]
    public async Task AssignConversationAsync_ShouldRejectNonSupportUserAssignee()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var regularUserId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);
        await SeedUserAsync(store, regularUserId, "other@petmagic.test", "Regular User", SystemRoles.User);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need billing help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using var assignScope = await store.CreateScopeAsync();
        var assignResult = await assignScope.CreateService().AssignConversationAsync(
            new AssignSupportConversationCommand(
                conversationId,
                adminId,
                regularUserId,
                "Validate support operator role.",
                ExpectedVersion: 1),
            CancellationToken.None);

        Assert.True(assignResult.IsFailure);
        Assert.Equal("support.assigned_admin_invalid", assignResult.Error.Code);
    }

    [Fact]
    public async Task UnassignedConversation_ShouldRejectAdminReplyStatusAndMetadataMutations()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Ownership required", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using var mutationScope = await store.CreateScopeAsync();
        var service = mutationScope.CreateService();
        var reply = await service.SendMessageAsync(
            new SendSupportMessageCommand(conversationId, adminId, "Reply", true),
            CancellationToken.None);
        var status = await service.UpdateConversationStatusAsync(
            new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
            CancellationToken.None);
        var metadata = await service.UpdateConversationMetadataAsync(
            new UpdateSupportConversationMetadataCommand(
                conversationId,
                adminId,
                SupportConversationPriority.High,
                ["ownership"]),
            CancellationToken.None);

        Assert.Equal("support.conversation_not_owned", reply.Error.Code);
        Assert.Equal("support.conversation_not_owned", status.Error.Code);
        Assert.Equal("support.conversation_not_owned", metadata.Error.Code);
    }

    [Fact]
    public async Task UpdateConversationMetadataAsync_ShouldAcceptPublishedTagLimits()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Metadata limits", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);
        var tags = Enumerable.Range(0, SupportConversationMetadataLimits.MaxTagCount)
            .Select(index => $"{index:D2}-{new string('x', SupportConversationMetadataLimits.MaxTagLength - 3)}")
            .ToArray();

        await using var metadataScope = await store.CreateScopeAsync();
        var updateResult = await metadataScope.CreateService().UpdateConversationMetadataAsync(
            new UpdateSupportConversationMetadataCommand(
                conversationId,
                adminId,
                SupportConversationPriority.High,
                tags),
            CancellationToken.None);

        Assert.True(updateResult.IsSuccess);
        Assert.Equal(tags, updateResult.Value.Tags);
    }

    [Fact]
    public async Task SendMessageWithAttachmentsAsync_WithAttachment_ShouldPersistAttachmentMetadata()
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
        var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
            new SendSupportAttachmentsCommand(
                conversationId,
                userId,
                "Screenshot from the broken screen",
                false,
                [
                    new SupportMessageAttachmentInput(
                        attachmentUrl,
                        "image/png",
                        "broken-screen.png",
                        2048)
                ]),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        Assert.Null(sendResult.Value.PendingAttachment);
        var attachment = Assert.Single(sendResult.Value.Attachments);
        AssertSignedSupportAttachmentUrl(attachment.FileUrl);
        Assert.Equal("broken-screen.png", attachment.FileName);
        Assert.Equal("image/png", attachment.MimeType);
        Assert.Equal(2048, attachment.SizeBytes);
    }

    [Fact]
    public async Task UpdateAttachmentMessageAsync_ShouldSanitizeFailedUploadErrorCode()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        Guid conversationId;
        Guid messageId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var createScope = await store.CreateScopeAsync())
        {
            var createResult = await createScope.CreateService().CreateAttachmentMessageAsync(
                new CreateSupportAttachmentMessageCommand(
                    conversationId,
                    userId,
                    "Uploading screenshot",
                    IsAdmin: false,
                    AttachmentFileName: "issue.png",
                    AttachmentContentType: "image/png"),
                CancellationToken.None);

            Assert.True(createResult.IsSuccess);
            messageId = createResult.Value.MessageId;
        }

        await using var updateScope = await store.CreateScopeAsync();
        var failedResult = await updateScope.CreateService().UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                AttachmentUploadErrorCode: "support.attachment_storage_failed token=attachment-service-secret"),
            CancellationToken.None);

        Assert.True(failedResult.IsSuccess);
        Assert.Equal("Failed", failedResult.Value.AttachmentUploadStatus);
        Assert.Equal("support.attachment_storage_failed", failedResult.Value.AttachmentUploadErrorCode);
        Assert.DoesNotContain("attachment-service-secret", failedResult.Value.AttachmentUploadErrorCode, StringComparison.OrdinalIgnoreCase);

        var persisted = await updateScope.SupportDbContext.ConversationMessages
            .AsNoTracking()
            .SingleAsync(message => message.Id == messageId);
        Assert.Equal("support.attachment_storage_failed", persisted.AttachmentUploadErrorCode);
        Assert.DoesNotContain("attachment-service-secret", persisted.AttachmentUploadErrorCode, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task SendMessageWithAttachmentsAsync_WithLegacySignedManagedAttachmentUrl_ShouldReturnFreshReadUrl()
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
        var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
            new SendSupportAttachmentsCommand(
                conversationId,
                userId,
                "Screenshot from the broken screen",
                false,
                [
                    new SupportMessageAttachmentInput(
                        "http://localhost:5000/support-attachments/2026/05/test-image.png?token=raw&signature=legacy#viewer",
                        "image/png",
                        "broken-screen.png",
                        2048)
                ]),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        var attachment = Assert.Single(sendResult.Value.Attachments);
        AssertSignedSupportAttachmentUrl(attachment.FileUrl);
        Assert.DoesNotContain("token=raw", attachment.FileUrl, StringComparison.Ordinal);
        Assert.DoesNotContain("signature=legacy", attachment.FileUrl, StringComparison.Ordinal);
        Assert.DoesNotContain("#viewer", attachment.FileUrl, StringComparison.Ordinal);
    }

    [Fact]
    public async Task SendMessageWithAttachmentsAsync_WithExternalAttachmentUrl_ShouldSuppressReturnedFileUrl()
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
        var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
            new SendSupportAttachmentsCommand(
                conversationId,
                userId,
                "Screenshot from the broken screen",
                false,
                [
                    new SupportMessageAttachmentInput(
                        "https://tracker.example.com/broken-screen.png",
                        "image/png",
                        "broken-screen.png",
                        2048)
                ]),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        var attachment = Assert.Single(sendResult.Value.Attachments);
        Assert.Equal(string.Empty, attachment.FileUrl);
        Assert.Equal("broken-screen.png", attachment.FileName);
    }

    [Fact]
    public async Task GetUserConversationAsync_WithDeletedAttachment_ShouldSuppressOriginalAttachmentMetadata()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        Guid conversationId;
        Guid messageId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
                new SendSupportAttachmentsCommand(
                    conversationId,
                    userId,
                    "Screenshot from the broken screen",
                    false,
                    [
                        new SupportMessageAttachmentInput(
                            "http://localhost:5000/support-attachments/2026/05/private-invoice.png",
                            "image/png",
                            "alice-private-invoice.png",
                            4096,
                            DurationSeconds: null,
                            Width: 640,
                            Height: 480)
                    ]),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
            messageId = sendResult.Value.MessageId;

            var persistedAttachment = await sendScope.SupportDbContext.SupportMessageAttachments.SingleAsync();
            persistedAttachment.IsDeleted = true;
            persistedAttachment.DeletedAtUtc = DateTime.UtcNow;
            await sendScope.SupportDbContext.SaveChangesAsync();
        }

        await using var detailScope = await store.CreateScopeAsync();
        var detail = await detailScope.CreateService().GetUserConversationAsync(userId, CancellationToken.None);

        Assert.True(detail.IsSuccess);
        var message = Assert.Single(detail.Value.Messages, x => x.MessageId == messageId);
        var attachment = Assert.Single(message.Attachments);
        Assert.True(attachment.IsDeleted);
        Assert.Equal(string.Empty, attachment.FileUrl);
        Assert.Equal("file", attachment.Type);
        Assert.Equal(string.Empty, attachment.MimeType);
        Assert.Equal("attachment", attachment.FileName);
        Assert.Equal(0, attachment.SizeBytes);
        Assert.Null(attachment.DurationSeconds);
        Assert.Null(attachment.Width);
        Assert.Null(attachment.Height);
        Assert.Null(attachment.ExpiresAtUtc);
        Assert.NotNull(attachment.DeletedAtUtc);
    }

    [Fact]
    public async Task CleanupExpiredBatchAsync_ShouldClearDeletedAttachmentMetadata()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using var scope = await store.CreateScopeAsync();
        var conversationId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var attachmentId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        scope.SupportDbContext.SupportConversations.Add(new SupportConversation
        {
            Id = conversationId,
            InitiatorUserId = userId,
            Status = SupportConversationStatus.New,
            Priority = SupportConversationPriority.Normal,
            Source = SupportConversationSource.MobileChat,
            CreatedAtUtc = now.AddHours(-2),
            UpdatedAtUtc = now.AddHours(-2),
            LastMessagePreview = "Attachment",
            LastMessageAtUtc = now.AddHours(-2),
            LastMessageSenderType = SupportMessageSenderType.User
        });
        scope.SupportDbContext.ConversationMessages.Add(new ConversationMessage
        {
            Id = messageId,
            ConversationId = conversationId,
            SenderUserId = userId,
            SenderType = SupportMessageSenderType.User,
            Body = "Attachment",
            CreatedAtUtc = now.AddHours(-2)
        });
        scope.SupportDbContext.SupportMessageAttachments.Add(new SupportMessageAttachment
        {
            Id = attachmentId,
            MessageId = messageId,
            FileUrl = "http://localhost:5000/support-attachments/2026/05/private-invoice.png",
            MimeType = "image/png",
            FileName = "alice-private-invoice.png",
            SizeBytes = 4096,
            DurationSeconds = 3.5,
            Width = 640,
            Height = 480,
            StorageKey = "support-attachments/2026/05/private-invoice.png",
            ExpiresAtUtc = now.AddMinutes(-1),
            SortOrder = 0,
            IsDeleted = false
        });
        await scope.SupportDbContext.SaveChangesAsync();

        var processor = new SupportAttachmentCleanupProcessor(
            scope.SupportDbContext,
            new NoopSupportAttachmentStorage(),
            new SupportAttachmentStorageOptions { CleanupBatchSize = 10 },
            new CapturingLogger<SupportAttachmentCleanupProcessor>());

        var processed = await processor.CleanupExpiredBatchAsync(CancellationToken.None);

        Assert.True(processed);
        var attachment = await scope.SupportDbContext.SupportMessageAttachments.SingleAsync(x => x.Id == attachmentId);
        Assert.True(attachment.IsDeleted);
        Assert.NotNull(attachment.DeletedAtUtc);
        Assert.Equal(string.Empty, attachment.FileUrl);
        Assert.Equal("attachment", attachment.FileName);
        Assert.Equal(string.Empty, attachment.MimeType);
        Assert.Equal(0, attachment.SizeBytes);
        Assert.Null(attachment.DurationSeconds);
        Assert.Null(attachment.Width);
        Assert.Null(attachment.Height);
        Assert.Null(attachment.StorageKey);
        Assert.True(attachment.ExpiresAtUtc <= now);
    }

    [Fact]
    public async Task CleanupExpiredBatchAsync_ShouldSanitizeStorageFailureLogCode()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using var scope = await store.CreateScopeAsync();
        var conversationId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var attachmentId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        scope.SupportDbContext.SupportConversations.Add(new SupportConversation
        {
            Id = conversationId,
            InitiatorUserId = userId,
            Status = SupportConversationStatus.New,
            Priority = SupportConversationPriority.Normal,
            Source = SupportConversationSource.MobileChat,
            CreatedAtUtc = now.AddHours(-2),
            UpdatedAtUtc = now.AddHours(-2),
            LastMessagePreview = "Attachment",
            LastMessageAtUtc = now.AddHours(-2),
            LastMessageSenderType = SupportMessageSenderType.User
        });
        scope.SupportDbContext.ConversationMessages.Add(new ConversationMessage
        {
            Id = messageId,
            ConversationId = conversationId,
            SenderUserId = userId,
            SenderType = SupportMessageSenderType.User,
            Body = "Attachment",
            CreatedAtUtc = now.AddHours(-2)
        });
        scope.SupportDbContext.SupportMessageAttachments.Add(new SupportMessageAttachment
        {
            Id = attachmentId,
            MessageId = messageId,
            FileUrl = "http://localhost:5000/support-attachments/2026/05/private-invoice.png",
            MimeType = "image/png",
            FileName = "alice-private-invoice.png",
            SizeBytes = 4096,
            StorageKey = "support-attachments/2026/05/private-invoice.png",
            ExpiresAtUtc = now.AddMinutes(-1),
            SortOrder = 0,
            IsDeleted = false
        });
        await scope.SupportDbContext.SaveChangesAsync();

        var logger = new CapturingLogger<SupportAttachmentCleanupProcessor>();
        var processor = new SupportAttachmentCleanupProcessor(
            scope.SupportDbContext,
            new FailingSupportAttachmentStorage("storage.delete_failed token=support-cleanup-secret"),
            new SupportAttachmentStorageOptions { CleanupBatchSize = 10 },
            logger);

        var processed = await processor.CleanupExpiredBatchAsync(CancellationToken.None);

        var attachment = await scope.SupportDbContext.SupportMessageAttachments.SingleAsync(x => x.Id == attachmentId);
        Assert.True(processed);
        Assert.False(attachment.IsDeleted);
        Assert.Contains(
            logger.Entries,
            entry => entry.LogLevel == LogLevel.Warning
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && errorCode == SupportChatErrors.AttachmentStorageFailed.Code
                && !errorCode.Contains("support-cleanup-secret", StringComparison.OrdinalIgnoreCase));
    }

    [Theory]
    [InlineData("http://localhost:5000support-attachments/2026/05/test-image.png")]
    [InlineData("http://localhost:5000/support-attachments/2026/../private.png")]
    [InlineData("http://localhost:5000/support-attachments/2026/%2e%2e/private.png")]
    [InlineData("http://localhost:5000/support-attachments/2026%2f..%2fprivate.png")]
    [InlineData("http://localhost:5000/support-attachments/2026%5c..%5cprivate.png")]
    [InlineData("http://localhost:5000/support-attachments/2026/%zz/private.png")]
    public async Task SendMessageWithAttachmentsAsync_WithUnsafeManagedAttachmentUrl_ShouldSuppressReturnedFileUrl(
        string attachmentUrl)
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
        var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
            new SendSupportAttachmentsCommand(
                conversationId,
                userId,
                "Screenshot from the broken screen",
                false,
                [
                    new SupportMessageAttachmentInput(
                        attachmentUrl,
                        "image/png",
                        "broken-screen.png",
                        2048)
                ]),
            CancellationToken.None);

        Assert.True(sendResult.IsSuccess);
        var attachment = Assert.Single(sendResult.Value.Attachments);
        Assert.Equal(string.Empty, attachment.FileUrl);
        Assert.Equal("broken-screen.png", attachment.FileName);
    }

    [Fact]
    public async Task LegacyNullAttachmentMimeType_ShouldNotCrashConversationOrReplyPreview()
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

        Guid attachmentMessageId;
        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
                new SendSupportAttachmentsCommand(
                    conversationId,
                    userId,
                    string.Empty,
                    false,
                    [
                        new SupportMessageAttachmentInput(
                            "http://localhost:5000/support-attachments/2026/05/legacy.png",
                            "image/png",
                            "legacy.png",
                            2048)
                    ]),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
            attachmentMessageId = sendResult.Value.MessageId;

            var persistedAttachment = await sendScope.SupportDbContext.SupportMessageAttachments.SingleAsync();
            persistedAttachment.MimeType = null!;
            await sendScope.SupportDbContext.SaveChangesAsync();
        }

        await using (var detailScope = await store.CreateScopeAsync())
        {
            var detail = await detailScope.CreateService().GetUserConversationAsync(userId, CancellationToken.None);

            Assert.True(detail.IsSuccess);
            var attachmentMessage = Assert.Single(detail.Value.Messages, message => message.MessageId == attachmentMessageId);
            var attachment = Assert.Single(attachmentMessage.Attachments);
            Assert.Equal("file", attachment.Type);
            Assert.Equal(string.Empty, attachment.MimeType);
            Assert.Equal("legacy.png", attachment.FileName);
        }

        await using var replyScope = await store.CreateScopeAsync();
        var replyResult = await replyScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(
                conversationId,
                userId,
                "Still broken",
                false,
                ReplyToMessageId: attachmentMessageId),
            CancellationToken.None);

        Assert.True(replyResult.IsSuccess);
        Assert.Equal(attachmentMessageId, replyResult.Value.ReplyToMessageId);
        Assert.Equal("legacy.png", replyResult.Value.ReplyToPreview);
    }

    [Fact]
    public async Task LegacyNullAttachmentMessageBody_ShouldReturnEmptyBodyAndKeepReplyPreview()
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

        Guid attachmentMessageId;
        await using (var sendScope = await store.CreateScopeAsync())
        {
            var sendResult = await sendScope.CreateService().SendMessageWithAttachmentsAsync(
                new SendSupportAttachmentsCommand(
                    conversationId,
                    userId,
                    string.Empty,
                    false,
                    [
                        new SupportMessageAttachmentInput(
                            "http://localhost:5000/support-attachments/2026/05/legacy-photo.png",
                            "image/png",
                            "legacy-photo.png",
                            2048)
                    ]),
                CancellationToken.None);

            Assert.True(sendResult.IsSuccess);
            attachmentMessageId = sendResult.Value.MessageId;

            var persistedMessage = await sendScope.SupportDbContext.ConversationMessages
                .Include(message => message.Attachments)
                .SingleAsync(message => message.Id == attachmentMessageId);
            persistedMessage.Body = null!;
            await sendScope.SupportDbContext.SaveChangesAsync();
        }

        await using (var detailScope = await store.CreateScopeAsync())
        {
            var detail = await detailScope.CreateService().GetUserConversationAsync(userId, CancellationToken.None);

            Assert.True(detail.IsSuccess);
            var attachmentMessage = Assert.Single(detail.Value.Messages, message => message.MessageId == attachmentMessageId);
            Assert.Equal(string.Empty, attachmentMessage.Body);
            Assert.Single(attachmentMessage.Attachments);
        }

        await using var replyScope = await store.CreateScopeAsync();
        var replyResult = await replyScope.CreateService().SendMessageAsync(
            new SendSupportMessageCommand(
                conversationId,
                userId,
                "Still broken",
                false,
                ReplyToMessageId: attachmentMessageId),
            CancellationToken.None);

        Assert.True(replyResult.IsSuccess);
        Assert.Equal(attachmentMessageId, replyResult.Value.ReplyToMessageId);
        Assert.Equal("Photo", replyResult.Value.ReplyToPreview);
    }

    [Fact]
    public async Task SendMessageAsync_WithReplyToMessage_ShouldPersistReplyMetadata()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

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

        await AssignConversationForTestAsync(store, conversationId, adminId);

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
    public async Task AssignConversationAsync_ShouldRejectStealingAnotherOperatorsTicket()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminAId = Guid.NewGuid();
        var adminBId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminAId, "admin-a@petmagic.test", "Support Admin A", SystemRoles.Admin);
        await SeedUserAsync(store, adminBId, "admin-b@petmagic.test", "Support Admin B", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);
            conversationId = openResult.Value.ConversationId;
        }

        await using (var claimScope = await store.CreateScopeAsync())
        {
            var claimResult = await claimScope.CreateService().AssignConversationAsync(
                new AssignSupportConversationCommand(
                    conversationId,
                    adminAId,
                    adminAId,
                    "First operator claims the ticket.",
                    ExpectedVersion: 1),
                CancellationToken.None);

            Assert.True(claimResult.IsSuccess);
        }

        await using var assignScope = await store.CreateScopeAsync();
        var assignResult = await assignScope.CreateService().AssignConversationAsync(
            new AssignSupportConversationCommand(
                conversationId,
                adminBId,
                adminBId,
                "Second operator attempts to claim.",
                ExpectedVersion: 2),
            CancellationToken.None);

        Assert.True(assignResult.IsFailure);
        Assert.Equal("support.conversation_already_assigned", assignResult.Error.Code);
    }

    [Fact]
    public async Task AssignConversationAsync_ShouldCommitAndQueueAuditWhenImmediateAuditSinkFails()
    {
        var store = CreateStore(adminAuditLog: new ThrowingAdminAuditLog());
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "audit-user@petmagic.test", "Audit User");
        await SeedUserAsync(store, adminId, "audit-admin@petmagic.test", "Audit Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Audit durability", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using (var assignmentScope = await store.CreateScopeAsync())
        {
            var result = await assignmentScope.CreateService().AssignConversationAsync(
                new AssignSupportConversationCommand(
                    conversationId,
                    adminId,
                    adminId,
                    "Assign operator before audit delivery.",
                    ExpectedVersion: 1),
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal(adminId, result.Value.AssignedAdminId);
        }

        var retryAuditLog = new CapturingAdminAuditLog();
        await using var retryScope = await store.CreateScopeAsync();
        var queued = await retryScope.SupportDbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(SupportChatPushNotificationOutbox.AdminAuditKind, queued.Kind);
        Assert.Equal(PushOutboxStatus.Queued, queued.Status);
        var processor = new SupportChatPushOutboxProcessor(
            retryScope.SupportDbContext,
            new NoopPushDeliverySender(),
            Microsoft.Extensions.Logging.Abstractions.NullLogger<SupportChatPushOutboxProcessor>.Instance,
            retryAuditLog);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        Assert.Equal(PushOutboxStatus.Sent, queued.Status);
        var retriedAudit = Assert.Single(retryAuditLog.Entries);
        Assert.Equal("admin.support.ticket.assigned", retriedAudit.Action);
        Assert.Equal(adminId, retriedAudit.ActorUserId);
        Assert.Equal(userId, retriedAudit.SubjectUserId);
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
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

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

        await AssignConversationForTestAsync(store, assignedConversationId, adminId);

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
        Assert.Single(mineResult.Value.Items);
        Assert.Single(unassignedResult.Value.Items);
        Assert.Equal(1, mineResult.Value.TotalCount);
        Assert.Equal(1, unassignedResult.Value.TotalCount);
        Assert.False(mineResult.Value.HasMore);
        Assert.False(unassignedResult.Value.HasMore);
        Assert.Equal(assignedConversationId, mineResult.Value.Items[0].ConversationId);
        Assert.Equal(unassignedConversationId, unassignedResult.Value.Items[0].ConversationId);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldApplyMultiStatusPriorityAndSortOnBackend()
    {
        var store = CreateStore();

        var normalUserId = Guid.NewGuid();
        var highUserId = Guid.NewGuid();
        var waitingUserId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, normalUserId, "normal@petmagic.test", "Normal User");
        await SeedUserAsync(store, highUserId, "high@petmagic.test", "High User");
        await SeedUserAsync(store, waitingUserId, "waiting@petmagic.test", "Waiting User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid normalConversationId;
        Guid highConversationId;
        Guid waitingConversationId;

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            normalConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(normalUserId, "Normal case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            highConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(highUserId, "High case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            waitingConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(waitingUserId, "Waiting case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using (var priorityScope = await store.CreateScopeAsync())
        {
            var highConversation = await priorityScope.SupportDbContext.SupportConversations
                .SingleAsync(x => x.Id == highConversationId);
            highConversation.Priority = SupportConversationPriority.High;
            await priorityScope.SupportDbContext.SaveChangesAsync();
        }

        await AssignConversationForTestAsync(store, waitingConversationId, adminId);

        await using (var replyScope = await store.CreateScopeAsync())
        {
            var replyResult = await replyScope.CreateService().SendMessageAsync(
                new SendSupportMessageCommand(waitingConversationId, adminId, "Waiting on user", true),
                CancellationToken.None);

            Assert.True(replyResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var result = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Priority: null,
                PageSize: 10,
                Sort: "priority",
                Statuses: ["New", "WaitingForUser"]),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(3, result.Value.TotalCount);
        Assert.Equal(highConversationId, result.Value.Items[0].ConversationId);
        Assert.Equal("High", result.Value.Items[0].Priority);
        Assert.Contains(result.Value.Items, item => item.ConversationId == normalConversationId && item.Status == "New");
        Assert.Contains(result.Value.Items, item => item.ConversationId == waitingConversationId && item.Status == "WaitingForUser");

        var highOnly = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Priority: "High",
                PageSize: 10,
                Sort: "priority",
                Statuses: ["New", "WaitingForUser"]),
            CancellationToken.None);

        Assert.True(highOnly.IsSuccess);
        var highItem = Assert.Single(highOnly.Value.Items);
        Assert.Equal(highConversationId, highItem.ConversationId);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldFilterWaitingForSupportQueueOnBackend()
    {
        var store = CreateStore();

        var newUserId = Guid.NewGuid();
        var assignedUserId = Guid.NewGuid();
        var waitingUserId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, newUserId, "new-queue@petmagic.test", "New Queue User");
        await SeedUserAsync(store, assignedUserId, "assigned-queue@petmagic.test", "Assigned Queue User");
        await SeedUserAsync(store, waitingUserId, "waiting-user@petmagic.test", "Waiting User");
        await SeedUserAsync(store, adminId, "admin-queue@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid newConversationId;
        Guid assignedConversationId;
        Guid waitingConversationId;

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            newConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(newUserId, "Needs triage", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            assignedConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(assignedUserId, "Assigned but not answered", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            waitingConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(waitingUserId, "Waiting on user", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using (var stateScope = await store.CreateScopeAsync())
        {
            var service = stateScope.CreateService();
            var assignResult = await service.AssignConversationAsync(
                new AssignSupportConversationCommand(
                    assignedConversationId,
                    adminId,
                    adminId,
                    "Assign waiting support ticket.",
                    ExpectedVersion: 1),
                CancellationToken.None);
            await AssignConversationForTestAsync(store, waitingConversationId, adminId);
            var replyResult = await service.SendMessageAsync(
                new SendSupportMessageCommand(waitingConversationId, adminId, "Please send details", true),
                CancellationToken.None);

            Assert.True(assignResult.IsSuccess);
            Assert.Equal("InProgress", assignResult.Value.Status);
            Assert.True(replyResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var result = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, PageSize: 10, Queue: "waiting_for_support"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.TotalCount);
        Assert.Contains(result.Value.Items, item => item.ConversationId == newConversationId && item.Status == "New");
        Assert.Contains(result.Value.Items, item => item.ConversationId == assignedConversationId && item.Status == "InProgress");
        Assert.DoesNotContain(result.Value.Items, item => item.ConversationId == waitingConversationId);
    }

    [Fact]
    public async Task ListAdminInboxAsync_UnreadQueue_ShouldOnlyReturnConversationsUnreadForAdmin()
    {
        var store = CreateStore();

        var unreadUserId = Guid.NewGuid();
        var readUserId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, unreadUserId, "unread@petmagic.test", "Unread User");
        await SeedUserAsync(store, readUserId, "read@petmagic.test", "Read User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid unreadConversationId;
        Guid readConversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            unreadConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(unreadUserId, "Unread case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            readConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(readUserId, "Read case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await using (var markReadScope = await store.CreateScopeAsync())
        {
            var markRead = await markReadScope.CreateService().MarkConversationReadAsync(
                new MarkSupportConversationReadCommand(readConversationId, adminId, true),
                CancellationToken.None);
            Assert.True(markRead.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var result = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, PageSize: 10, Queue: "unread"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.TotalCount);
        Assert.Contains(result.Value.Items, item => item.ConversationId == unreadConversationId);
        Assert.DoesNotContain(result.Value.Items, item => item.ConversationId == readConversationId);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldRejectLegacyStatusAndSourceAliases()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "legacy@petmagic.test", "Legacy User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            conversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Legacy alias case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        await using (var closeScope = await store.CreateScopeAsync())
        {
            var closeResult = await closeScope.CreateService().UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(conversationId, adminId, SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(closeResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var serviceForVerification = verificationScope.CreateService();

        var byLegacyStatus = await serviceForVerification.ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Statuses: ["Resolved"]),
            CancellationToken.None);

        var byLegacySource = await serviceForVerification.ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Source: "Direct"),
            CancellationToken.None);

        Assert.True(byLegacyStatus.IsFailure);
        Assert.Equal("support.status_invalid", byLegacyStatus.Error.Code);
        Assert.True(byLegacySource.IsFailure);
        Assert.Equal("support.source_invalid", byLegacySource.Error.Code);
    }

    [Theory]
    [InlineData(null, "not-a-source", null, null, "support.source_invalid")]
    [InlineData(null, "1", null, null, "support.source_invalid")]
    [InlineData(null, "-1", null, null, "support.source_invalid")]
    [InlineData(null, null, "not-a-priority", null, "support.priority_invalid")]
    [InlineData(null, null, "1", null, "support.priority_invalid")]
    [InlineData(null, null, "-1", null, "support.priority_invalid")]
    [InlineData("not-a-sort", null, null, null, "support.sort_invalid")]
    [InlineData(null, null, null, "not-a-queue", "support.queue_invalid")]
    public async Task ListAdminInboxAsync_ShouldReturnFieldSpecificFilterErrors(
        string? sort,
        string? source,
        string? priority,
        string? queue,
        string expectedErrorCode)
    {
        var store = CreateStore();

        await using var scope = await store.CreateScopeAsync();
        var result = await scope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Source: source,
                Priority: priority,
                Sort: sort,
                Queue: queue),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(expectedErrorCode, result.Error.Code);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldRejectNumericStatusFilters()
    {
        var store = CreateStore();

        await using var scope = await store.CreateScopeAsync();
        var result = await scope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                null,
                Statuses: ["1", "-1"]),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("support.status_invalid", result.Error.Code);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldReturnEmptyPageForOverflowSizedPage()
    {
        var store = CreateStore();

        var userId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");

        await using (var openScope = await store.CreateScopeAsync())
        {
            var openResult = await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Need help", SupportConversationPriority.Normal),
                CancellationToken.None);

            Assert.True(openResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var result = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, Page: int.MaxValue, PageSize: 100),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(result.Value.Items);
        Assert.Equal(int.MaxValue, result.Value.Page);
        Assert.Equal(100, result.Value.PageSize);
        Assert.Equal(1, result.Value.TotalCount);
        Assert.False(result.Value.HasMore);
    }

    [Fact]
    public async Task ListAdminInboxAsync_ShouldUseDefaultPageSizeForNonPositivePageSize()
    {
        var store = CreateStore();

        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        await SeedUserAsync(store, firstUserId, "first@petmagic.test", "First User");
        await SeedUserAsync(store, secondUserId, "second@petmagic.test", "Second User");

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            var firstOpenResult = await service.OpenConversationAsync(
                new OpenSupportConversationCommand(firstUserId, "Need help one", SupportConversationPriority.Normal),
                CancellationToken.None);
            var secondOpenResult = await service.OpenConversationAsync(
                new OpenSupportConversationCommand(secondUserId, "Need help two", SupportConversationPriority.Normal),
                CancellationToken.None);

            Assert.True(firstOpenResult.IsSuccess);
            Assert.True(secondOpenResult.IsSuccess);
        }

        await using var verificationScope = await store.CreateScopeAsync();
        var result = await verificationScope.CreateService().ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(null, Page: 0, PageSize: 0),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.Page);
        Assert.Equal(50, result.Value.PageSize);
        Assert.Equal(2, result.Value.Items.Count);
        Assert.Equal(2, result.Value.TotalCount);
        Assert.False(result.Value.HasMore);
    }

    [Fact]
    public async Task GetAdminInboxMetricsAsync_ShouldReturnBackendAggregatedQueueCounts()
    {
        var store = CreateStore();

        var userA = Guid.NewGuid();
        var userB = Guid.NewGuid();
        var userC = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userA, "user-a@petmagic.test", "Pet User A");
        await SeedUserAsync(store, userB, "user-b@petmagic.test", "Pet User B");
        await SeedUserAsync(store, userC, "user-c@petmagic.test", "Pet User C");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin");

        Guid readConversationId;
        Guid assignedConversationId;
        Guid closedConversationId;

        await using (var openScope = await store.CreateScopeAsync())
        {
            var service = openScope.CreateService();
            readConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userA, "Read case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            assignedConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userB, "Assigned unread case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
            closedConversationId = (await service.OpenConversationAsync(
                new OpenSupportConversationCommand(userC, "Closed unread case", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, assignedConversationId, adminId);

        await using (var mutateScope = await store.CreateScopeAsync())
        {
            var service = mutateScope.CreateService();
            var markRead = await service.MarkConversationReadAsync(
                new MarkSupportConversationReadCommand(readConversationId, adminId, true),
                CancellationToken.None);
            var assign = await service.SendMessageAsync(
                new SendSupportMessageCommand(assignedConversationId, adminId, "We are checking this", true),
                CancellationToken.None);
            var close = await service.CloseConversationAsync(
                new CloseSupportConversationCommand(closedConversationId, adminId, true),
                CancellationToken.None);

            Assert.True(markRead.IsSuccess);
            Assert.True(assign.IsSuccess);
            Assert.True(close.IsSuccess);
        }

        await using var metricsScope = await store.CreateScopeAsync();
        var metrics = await metricsScope.CreateService().GetAdminInboxMetricsAsync(CancellationToken.None);

        Assert.True(metrics.IsSuccess);
        Assert.Equal(3, metrics.Value.TotalConversations);
        Assert.Equal(2, metrics.Value.OpenConversations);
        Assert.Equal(1, metrics.Value.ClosedConversations);
        Assert.Equal(2, metrics.Value.UnassignedConversations);
        Assert.Equal(2, metrics.Value.UnreadForAdminConversations);
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

        await AssignConversationForTestAsync(store, conversationId, adminId);

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

        await AssignConversationForTestAsync(store, conversationId, adminId);

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

        await AssignConversationForTestAsync(store, conversationId, adminId);

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

        await AssignConversationForTestAsync(store, conversationId, adminId);

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
    public async Task SubmitConversationFeedbackAsync_WhenAlreadySubmitted_ShouldRejectAndPreserveInitialFeedback()
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

            var resolveResult = await openScope.CreateService().ResolveConversationAsync(
                new ResolveSupportConversationCommand(conversationId, userId, IsAdmin: false),
                CancellationToken.None);

            Assert.True(resolveResult.IsSuccess);
        }

        DateTime? submittedAtUtc;
        await using (var initialFeedbackScope = await store.CreateScopeAsync())
        {
            var initialResult = await initialFeedbackScope.CreateService().SubmitConversationFeedbackAsync(
                new SubmitSupportConversationFeedbackCommand(conversationId, userId, 5, "Thanks"),
                CancellationToken.None);

            Assert.True(initialResult.IsSuccess);
            submittedAtUtc = initialResult.Value.FeedbackSubmittedAtUtc;
            Assert.NotNull(submittedAtUtc);
        }

        await using var duplicateFeedbackScope = await store.CreateScopeAsync();
        var duplicateResult = await duplicateFeedbackScope.CreateService().SubmitConversationFeedbackAsync(
            new SubmitSupportConversationFeedbackCommand(conversationId, userId, 1, "Changed"),
            CancellationToken.None);

        Assert.True(duplicateResult.IsFailure);
        Assert.Equal(SupportChatErrors.FeedbackNotAllowed.Code, duplicateResult.Error.Code);

        var persisted = await duplicateFeedbackScope.SupportDbContext.SupportConversations
            .SingleAsync(x => x.Id == conversationId);
        Assert.Equal(5, persisted.FeedbackRating);
        Assert.Equal("Thanks", persisted.FeedbackComment);
        Assert.Equal(submittedAtUtc, persisted.FeedbackSubmittedAtUtc);
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

            var assignedConversation = await openScope.SupportDbContext.SupportConversations
                .SingleAsync(x => x.Id == conversationId);
            assignedConversation.AssignedAdminId = adminId;
            await openScope.SupportDbContext.SaveChangesAsync();

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
    public async Task UpdateConversationStatusAsync_WhenAlreadyClosed_ShouldNotAppendDuplicateSystemEvents()
    {
        var store = CreateStore();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        await SeedUserAsync(store, userId, "user@petmagic.test", "Pet User");
        await SeedUserAsync(store, adminId, "admin@petmagic.test", "Support Admin", SystemRoles.Admin);

        Guid conversationId;
        await using (var openScope = await store.CreateScopeAsync())
        {
            conversationId = (await openScope.CreateService().OpenConversationAsync(
                new OpenSupportConversationCommand(userId, "Idempotent close", SupportConversationPriority.Normal),
                CancellationToken.None)).Value.ConversationId;
        }

        await AssignConversationForTestAsync(store, conversationId, adminId);

        await using (var closeScope = await store.CreateScopeAsync())
        {
            var closeResult = await closeScope.CreateService().UpdateConversationStatusAsync(
                new UpdateSupportConversationStatusCommand(
                    conversationId,
                    adminId,
                    SupportConversationStatus.Closed),
                CancellationToken.None);

            Assert.True(closeResult.IsSuccess);
        }

        await using var retryScope = await store.CreateScopeAsync();
        var beforeRetrySystemEventCount = retryScope.SupportDbContext.ConversationMessages.Count(
            message => message.ConversationId == conversationId && message.SenderType == SupportMessageSenderType.System);
        var retryResult = await retryScope.CreateService().UpdateConversationStatusAsync(
            new UpdateSupportConversationStatusCommand(
                conversationId,
                adminId,
                SupportConversationStatus.Closed),
            CancellationToken.None);
        var afterRetrySystemEventCount = retryScope.SupportDbContext.ConversationMessages.Count(
            message => message.ConversationId == conversationId && message.SenderType == SupportMessageSenderType.System);

        Assert.True(retryResult.IsSuccess);
        Assert.Equal("Closed", retryResult.Value.Status);
        Assert.Equal(beforeRetrySystemEventCount, afterRetrySystemEventCount);
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
        var userMessage = Assert.Single(detail.Value.Messages, message => message.SenderType == "User");
        Assert.Equal("Necesito ayuda", userMessage.Body);
        var botReply = Assert.Single(detail.Value.Messages, message => message.SenderType == "Bot");
        Assert.Equal(
            "Mensaje recibido. Soporte responderá en este chat.",
            botReply.Body);
        Assert.True(botReply.IsFromAdmin);
        Assert.True(botReply.IsRead);
        Assert.Equal(1, detail.Value.AdminUnreadCount);
        Assert.Equal(0, detail.Value.UserUnreadCount);
    }

    private static TestStore CreateStore(
        ISupportChatRealtimeNotifier? realtimeNotifier = null,
        ISupportChatPushNotificationSender? pushNotificationSender = null,
        ILogger<SupportChatService>? logger = null,
        IAdminAuditLog? adminAuditLog = null)
    {
        return new TestStore(
            $"support-chat-tests-{Guid.NewGuid():N}",
            $"support-chat-identity-tests-{Guid.NewGuid():N}",
            realtimeNotifier,
            pushNotificationSender,
            logger,
            adminAuditLog);
    }

    private static async Task SeedUserAsync(
        TestStore store,
        Guid userId,
        string email,
        string displayName,
        params string[] roles)
    {
        await using var scope = await store.CreateScopeAsync();

        foreach (var role in roles.Distinct(StringComparer.Ordinal))
        {
            if (!await scope.IdentityDbContext.Roles.AnyAsync(existing => existing.Name == role))
            {
                scope.IdentityDbContext.Roles.Add(new IdentityRole<Guid>
                {
                    Id = Guid.NewGuid(),
                    Name = role,
                    NormalizedName = role.ToUpperInvariant(),
                });
            }
        }

        await scope.IdentityDbContext.SaveChangesAsync();

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

        if (roles.Length > 0)
        {
            var normalizedRoles = roles
                .Distinct(StringComparer.Ordinal)
                .Select(role => role.ToUpperInvariant())
                .ToArray();
            var roleIds = await scope.IdentityDbContext.Roles
                .Where(role => normalizedRoles.Contains(role.NormalizedName!))
                .Select(role => role.Id)
                .ToListAsync();

            foreach (var roleId in roleIds)
            {
                scope.IdentityDbContext.UserRoles.Add(new IdentityUserRole<Guid>
                {
                    UserId = userId,
                    RoleId = roleId,
                });
            }

            await scope.IdentityDbContext.SaveChangesAsync();
        }
    }

    private static async Task AssignConversationForTestAsync(
        TestStore store,
        Guid conversationId,
        Guid adminId)
    {
        await using var scope = await store.CreateScopeAsync();
        var conversation = await scope.SupportDbContext.SupportConversations
            .SingleAsync(x => x.Id == conversationId);
        conversation.AssignedAdminId = adminId;
        conversation.UpdatedAtUtc = DateTime.UtcNow;
        await scope.SupportDbContext.SaveChangesAsync();
    }

    private sealed class TestStore(
        string supportDatabaseName,
        string identityDatabaseName,
        ISupportChatRealtimeNotifier? realtimeNotifier = null,
        ISupportChatPushNotificationSender? pushNotificationSender = null,
        ILogger<SupportChatService>? logger = null,
        IAdminAuditLog? adminAuditLog = null)
    {
        private readonly ISupportChatRealtimeNotifier notifier = realtimeNotifier ?? new FakeSupportChatRealtimeNotifier();
        private readonly ISupportChatPushNotificationSender pushNotifier = pushNotificationSender ?? new NoopSupportChatPushNotificationSender();
        private readonly ILogger<SupportChatService>? supportLogger = logger;
        private readonly IAdminAuditLog? auditLog = adminAuditLog;

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

            return new TestScope(supportDbContext, identityDbContext, notifier, pushNotifier, supportLogger, auditLog);
        }
    }

    private sealed class TestScope(
        SupportChatDbContext supportDbContext,
        IdentityDbContext identityDbContext,
        ISupportChatRealtimeNotifier realtimeNotifier,
        ISupportChatPushNotificationSender pushNotificationSender,
        ILogger<SupportChatService>? logger,
        IAdminAuditLog? adminAuditLog) : IAsyncDisposable
    {
        public SupportChatDbContext SupportDbContext { get; } = supportDbContext;

        public IdentityDbContext IdentityDbContext { get; } = identityDbContext;

        public SupportChatService CreateService()
        {
            return new SupportChatService(
                SupportDbContext,
                new IdentityUserLookupService(IdentityDbContext),
                realtimeNotifier,
                pushNotificationSender,
                new NoopSupportAttachmentStorage(),
                new SupportAttachmentReadUrlSigner(
                    new SupportAttachmentStorageOptions
                    {
                        PublicBaseUrl = "http://localhost:5000"
                    },
                    new SupportAttachmentReadUrlSigningOptions
                    {
                        SigningKey = new string('s', 64),
                        ReadUrlTtlMinutes = 30
                    }),
                new SupportAttachmentStorageOptions
                {
                    PublicBaseUrl = "http://localhost:5000"
                },
                logger,
                adminAuditLog: adminAuditLog);
        }

        public async ValueTask DisposeAsync()
        {
            await SupportDbContext.DisposeAsync();
            await IdentityDbContext.DisposeAsync();
        }
    }

    private static void AssertSignedSupportAttachmentUrl(string fileUrl)
    {
        var uri = new Uri(fileUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.StartsWith("/support-attachments/", uri.AbsolutePath, StringComparison.OrdinalIgnoreCase);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
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

    private sealed class ThrowingSupportChatPushNotificationSender : ISupportChatPushNotificationSender
    {
        public Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("push provider is unavailable");
        }
    }

    private sealed class NoopPushDeliverySender : ISupportChatPushDeliverySender
    {
        public Task<PushDeliveryResult> DeliverUserAsync(
            SupportChatPushNotification notification,
            CancellationToken cancellationToken) => Task.FromResult(PushDeliveryResult.Delivered);
    }

    private sealed class ThrowingAdminAuditLog : IAdminAuditLog
    {
        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("audit sink unavailable");
    }

    private sealed class CapturingAdminAuditLog : IAdminAuditLog
    {
        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            Entries.Add(entry);
            return Task.CompletedTask;
        }
    }

    private sealed class NoopSupportAttachmentStorage : ISupportAttachmentStorage
    {
        public long? ResolveMaxFileSizeBytes(string declaredContentType)
        {
            if (declaredContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
            {
                return 50L * 1024 * 1024;
            }

            if (declaredContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                return 10L * 1024 * 1024;
            }

            return null;
        }

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
                    FileSizeBytes: attachment.Content?.LongLength ?? attachment.ContentLengthBytes ?? 0,
                    LocalPath: null)));
        }

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }
    }

    private sealed class FailingSupportAttachmentStorage(string deleteErrorCode) : ISupportAttachmentStorage
    {
        public long? ResolveMaxFileSizeBytes(string declaredContentType)
        {
            return declaredContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
                ? 50L * 1024 * 1024
                : 10L * 1024 * 1024;
        }

        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                SupportChatErrors.AttachmentStorageFailed));
        }

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure(new Error(deleteErrorCode, "Delete failed.")));
        }
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values.ToDictionary(x => x.Key, x => x.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel LogLevel,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
