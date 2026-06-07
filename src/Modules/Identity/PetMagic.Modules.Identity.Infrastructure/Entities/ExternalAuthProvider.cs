namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class ExternalAuthProvider
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string ProviderUserId { get; set; } = string.Empty;

    public string? Email { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime LastUsedAt { get; set; }

    public AppUser? User { get; set; }
}
