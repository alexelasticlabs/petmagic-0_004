namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateAiProviderRequestPermit
{
    public Guid Id { get; set; }

    public string Provider { get; set; } = string.Empty;

    public DateTime BucketUtc { get; set; }

    public int PermitNumber { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
