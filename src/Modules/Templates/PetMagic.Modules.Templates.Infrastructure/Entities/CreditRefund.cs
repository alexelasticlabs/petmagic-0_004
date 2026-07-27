namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class CreditRefund
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid? FeedbackId { get; set; }

    public Guid? GenerationId { get; set; }

    public int Amount { get; set; }

    public string Reason { get; set; } = string.Empty;

    public Guid AdminId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    // Existing rows predate the durable refund intent and are settled refunds.
    public string SettlementStatus { get; set; } = CreditRefundSettlementStatus.Completed;

    public TemplateGenerationFeedback? Feedback { get; set; }

    public TemplateGenerationJob? Generation { get; set; }
}

internal static class CreditRefundSettlementStatus
{
    public const string Pending = "Pending";
    public const string Completed = "Completed";
}
