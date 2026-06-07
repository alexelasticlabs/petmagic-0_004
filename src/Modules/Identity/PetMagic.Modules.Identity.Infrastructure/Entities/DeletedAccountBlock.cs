namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class DeletedAccountBlock
{
    public Guid Id { get; set; }

    public string? Email { get; set; }

    public string? Provider { get; set; }

    public string? ProviderUserId { get; set; }

    public DateTime DeletedAtUtc { get; set; }
}
