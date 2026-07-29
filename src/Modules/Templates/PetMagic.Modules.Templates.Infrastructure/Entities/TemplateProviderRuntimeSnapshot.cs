using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateProviderRuntimeSnapshot
{
    public Guid Id { get; set; }

    public string Provider { get; set; } = string.Empty;

    public TemplateProviderBalanceState BalanceState { get; set; }

    public DateTime StatusChangedAtUtc { get; set; }

    public decimal? CurrentBalanceUsd { get; set; }

    public DateTime? LastSuccessfulAtUtc { get; set; }

    public DateTime? CheckedAtUtc { get; set; }

    public int ConsecutiveFailures { get; set; }

    public string? LastErrorCode { get; set; }

    public Guid? RefreshLeaseId { get; set; }

    public DateTime? RefreshLeaseExpiresAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
