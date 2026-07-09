using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService(
    SupportChatDbContext supportChatDbContext,
    IIdentityUserLookupService identityUserLookupService,
    ISupportChatRealtimeNotifier realtimeNotifier,
    ISupportChatPushNotificationSender pushNotificationSender,
    ISupportAttachmentStorage attachmentStorage,
    ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
    SupportAttachmentStorageOptions attachmentStorageOptions,
    ILogger<SupportChatService>? logger = null,
    IEconomyService? economyService = null,
    IAdminUserEconomyAnalyticsReader? adminUserEconomyAnalyticsReader = null,
    ITemplateGenerationService? templateGenerationService = null,
    IAdminUserTemplateAnalyticsReader? adminUserTemplateAnalyticsReader = null,
    IAdminAuditLog? adminAuditLog = null) : ISupportChatService
{
    private const int DefaultConversationMessagesTake = 60;
    private const int MaxConversationMessagesTake = 120;
    private static readonly Guid AutomatedAssistantUserId = Guid.Parse("2F1E3B3B-8A2E-4A8E-9EE5-97BF31B33218");
    private static readonly Error ConversationNotFound = new("support.conversation_not_found", "Support conversation was not found.");
    private static readonly Error MessageNotFound = new("support.message_not_found", "Support message was not found.");
    private static readonly Error Forbidden = new("support.forbidden", "You do not have access to this support conversation.");
    private static readonly Error InvalidStatus = new("support.status_invalid", "Support conversation status is not supported.");
    private static readonly Error InvalidSource = new("support.source_invalid", "Support conversation source is not supported.");
    private static readonly Error InvalidPriority = new("support.priority_invalid", "Support conversation priority is not supported.");
    private static readonly Error InvalidSort = new("support.sort_invalid", "Support inbox sort is not supported.");
    private static readonly Error InvalidQueue = new("support.queue_invalid", "Support inbox queue is not supported.");
    private static readonly Error InvalidStatusTransition = new("support.status_transition_invalid", "Support conversation status transition is not allowed.");
    private static readonly Error InvalidTags = new("support.tags_invalid", "Support conversation tags are invalid.");
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

    private static Error? ValidateAdminOwnership(Entities.SupportConversation conversation, Guid adminUserId)
    {
        return conversation.AssignedAdminId == adminUserId
            ? null
            : SupportChatErrors.ConversationNotOwned;
    }
}
