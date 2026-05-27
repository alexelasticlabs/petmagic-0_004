using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class ConversationMessage
{
    public Guid Id { get; set; }

    public Guid ConversationId { get; set; }

    public Guid SenderUserId { get; set; }

    public bool IsFromAdmin { get; set; }

    public SupportMessageSenderType SenderType { get; set; } = SupportMessageSenderType.User;

    public string Body { get; set; } = string.Empty;

    public string? AttachmentUrl { get; set; }

    public string? AttachmentFileName { get; set; }

    public string? AttachmentContentType { get; set; }

    public long? AttachmentFileSizeBytes { get; set; }

    public int? AttachmentUploadStatus { get; set; }

    public string? AttachmentUploadErrorCode { get; set; }

    public DateTime? ReadAtUtc { get; set; }

    public DateTime? DeliveredAtUtc { get; set; }

    public bool IsInternalNote { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public SupportConversation Conversation { get; set; } = null!;
}
