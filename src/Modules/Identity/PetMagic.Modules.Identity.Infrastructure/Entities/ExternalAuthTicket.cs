namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class ExternalAuthTicket
{
    public string Ticket { get; set; } = string.Empty;

    public string Purpose { get; set; } = string.Empty;

    public string PayloadJson { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? ConsumedAtUtc { get; set; }
}
