namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public enum TemplateCatalogChangeType
{
    Upsert = 1,
    Delete = 2,
}

public sealed class TemplateCatalogChange
{
    public Guid Id { get; set; }

    public Guid TemplateId { get; set; }

    public long Version { get; set; }

    public TemplateCatalogChangeType ChangeType { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
