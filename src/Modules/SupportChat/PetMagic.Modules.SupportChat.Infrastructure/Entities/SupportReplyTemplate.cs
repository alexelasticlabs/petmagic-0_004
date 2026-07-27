namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class SupportReplyTemplate
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public bool IsEnabled { get; set; }

    public int Version { get; set; } = 1;

    public DateTime? DisabledAtUtc { get; set; }

    public Guid LastModifiedByUserId { get; set; }

    public int SortOrder { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public List<SupportReplyTemplateRevision> Revisions { get; set; } = [];
}
