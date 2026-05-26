using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class SupportConversation
{
    public Guid Id { get; set; }

    public Guid InitiatorUserId { get; set; }

    public Guid? AssignedAdminId { get; set; }

    public SupportConversationStatus Status { get; set; } = SupportConversationStatus.Open;

    public SupportConversationPriority Priority { get; set; } = SupportConversationPriority.Normal;

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? LastMessageAtUtc { get; set; }

    public DateTime? ResolvedAtUtc { get; set; }

    public List<ConversationMessage> Messages { get; set; } = [];
}
