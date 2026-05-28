namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class SupportMessageAttachment
{
    public Guid Id { get; set; }

    public Guid MessageId { get; set; }

    public string FileUrl { get; set; } = string.Empty;

    public string MimeType { get; set; } = string.Empty;

    public string FileName { get; set; } = string.Empty;

    public long SizeBytes { get; set; }

    public string? StorageKey { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public bool IsDeleted { get; set; }

    public double? DurationSeconds { get; set; }

    public int? Width { get; set; }

    public int? Height { get; set; }

    public int SortOrder { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public ConversationMessage Message { get; set; } = null!;
}
