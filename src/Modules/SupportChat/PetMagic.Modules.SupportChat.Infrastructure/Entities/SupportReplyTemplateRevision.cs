namespace PetMagic.Modules.SupportChat.Infrastructure.Entities;

public sealed class SupportReplyTemplateRevision
{
    public Guid Id { get; set; }

    public Guid TemplateId { get; set; }

    public int Version { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public bool IsEnabled { get; set; }

    public int SortOrder { get; set; }

    public Guid ActorUserId { get; set; }

    public string? Reason { get; set; }

    public DateTime CapturedAtUtc { get; set; }

    public SupportReplyTemplate Template { get; set; } = null!;
}
