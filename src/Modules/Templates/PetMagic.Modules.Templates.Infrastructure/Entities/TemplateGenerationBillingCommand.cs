namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationBillingCommand
{
    public Guid Id { get; set; }

    public Guid GenerationId { get; set; }

    public Guid UserId { get; set; }

    public int TokenCost { get; set; }

    public string Status { get; set; } = TemplateGenerationBillingCommandStatuses.Pending;

    public int AttemptCount { get; set; }

    public string? LastErrorCode { get; set; }

    public string? LastErrorMessage { get; set; }

    public DateTime? LastAttemptedAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public TemplateGenerationJob Generation { get; set; } = null!;
}

public static class TemplateGenerationBillingCommandStatuses
{
    public const string Pending = "pending";
    public const string Processing = "processing";
    public const string Succeeded = "succeeded";
    public const string Failed = "failed";
}
