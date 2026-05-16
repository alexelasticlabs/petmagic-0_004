using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateMediaRecord
{
    public Guid Id { get; set; }

    public string Url { get; set; } = string.Empty;

    public string FileName { get; set; } = string.Empty;

    public string ContentType { get; set; } = string.Empty;

    public long? FileSizeBytes { get; set; }

    public TemplateMediaRole Role { get; set; }

    public TemplateMediaLifecycleState LifecycleState { get; set; }

    public Guid? TemplateId { get; set; }

    public Guid? GenerationJobId { get; set; }

    public DateTime UploadedAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }

    public DateTime? AttachedAtUtc { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public DateTime? LastCleanupAttemptAtUtc { get; set; }

    public string? FailureCode { get; set; }

    public string? FailureMessage { get; set; }

    public TemplateItem? Template { get; set; }

    public TemplateGenerationJob? GenerationJob { get; set; }
}
