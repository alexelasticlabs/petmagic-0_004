using Microsoft.AspNetCore.Identity;

namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AppUser : IdentityUser<Guid>
{
    public string? DisplayName { get; set; }

    public bool IsPremium { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
