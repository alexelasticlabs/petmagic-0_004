namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateFalProviderHealthSnapshot
{
    public Guid Id { get; set; }

    public decimal? BalanceUsd { get; set; }

    public string Status { get; set; } = "unknown";

    public string? LastErrorCode { get; set; }

    public int ConsecutiveFailures { get; set; }

    public DateTime CheckedAtUtc { get; set; }

    public DateTime? LastSuccessAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
