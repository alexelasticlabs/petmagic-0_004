using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class SupportConversation
{
    public Guid Id { get; set; }

    public Guid InitiatorUserId { get; set; }

    public Guid? AssignedAdminId { get; set; }

    public SupportConversationStatus Status { get; set; } = SupportConversationStatus.New;

    public SupportConversationPriority Priority { get; set; } = SupportConversationPriority.Normal;

    public SupportConversationSource Source { get; set; } = SupportConversationSource.MobileChat;

    public string? TagsJson { get; set; }

    public string? AssistantScenario { get; set; }

    public Guid? RelatedGenerationId { get; set; }

    public Guid? RelatedPaymentId { get; set; }

    public Guid? RelatedSubscriptionId { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? LastMessageAtUtc { get; set; }

    public string? LastMessagePreview { get; set; }

    public SupportMessageSenderType? LastMessageSenderType { get; set; }

    public DateTime? WaitingSinceUtc { get; set; }

    public DateTime? ResolvedAtUtc { get; set; }

    public DateTime? ReopenUntilUtc { get; set; }

    public DateTime? ClosedAtUtc { get; set; }

    public Guid? ClosedByUserId { get; set; }

    public DateTime? ReopenedAtUtc { get; set; }

    public Guid? ReopenedByUserId { get; set; }

    public int? FeedbackRating { get; set; }

    public string? FeedbackComment { get; set; }

    public DateTime? FeedbackSubmittedAtUtc { get; set; }

    public List<ConversationMessage> Messages { get; set; } = [];
}
