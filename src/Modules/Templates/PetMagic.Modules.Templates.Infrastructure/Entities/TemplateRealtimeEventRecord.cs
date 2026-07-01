namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateRealtimeEventRecord
{
    public Guid Id { get; set; }

    public string Topic { get; set; } = string.Empty;

    public string? Data { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
