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

    public TemplateGenerationFeedback? Feedback { get; set; }

    public TemplateGenerationJob? Generation { get; set; }
}
