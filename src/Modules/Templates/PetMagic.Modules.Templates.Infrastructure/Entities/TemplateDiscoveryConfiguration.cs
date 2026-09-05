namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateDiscoveryPage
{
    public const int HomeId = 1;
    public int Id { get; set; } = HomeId;
    public long Version { get; set; }
    public long LastRevisionNumber { get; set; }
    public Guid? PublishedRevisionId { get; set; }
    public Guid? DraftRevisionId { get; set; }
}

public sealed class TemplateDiscoveryRevision
{
    public Guid Id { get; set; }
    public long Number { get; set; }
    public long EditVersion { get; set; } = 1;
    public string State { get; set; } = "Draft";
    public string DocumentJson { get; set; } = string.Empty;
    public Guid? BasedOnRevisionId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public DateTime? PublishedAtUtc { get; set; }
    public Guid CreatedBy { get; set; }
    public Guid UpdatedBy { get; set; }
    public Guid? PublishedBy { get; set; }
    public string? Reason { get; set; }
}

public sealed class TemplateDiscoveryCommandReceipt
{
    public Guid ActorId { get; set; }
    public string IdempotencyKey { get; set; } = string.Empty;
    public string RequestHash { get; set; } = string.Empty;
    public Guid RevisionId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
