namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationControlPolicyCommandReceipt
{
    public Guid Id { get; set; }

    public Guid ActorUserId { get; set; }

    public string IdempotencyKey { get; set; } = string.Empty;

    public string RequestHash { get; set; } = string.Empty;

    public long PolicyRevision { get; set; }

    public string ResponseJson { get; set; } = "{}";

    public DateTime CreatedAtUtc { get; set; }
}
