namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationControlPolicy
{
    public Guid Id { get; set; }

    public long Revision { get; set; }

    public bool AdmissionEnabled { get; set; }

    public int ConfirmedFalConcurrencyLimit { get; set; }

    public DateTime ConfirmedAtUtc { get; set; }

    public int ReservedHeadroom { get; set; }

    public int ApplicationHardCeiling { get; set; }

    public int BaseGlobalMaxConcurrentGenerations { get; set; }

    public int BaseImageReservedConcurrentGenerations { get; set; }

    public int BaseImageProtectedConcurrentGenerations { get; set; }

    public int BaseImageMaxConcurrentGenerations { get; set; }

    public int BaseVideoReservedConcurrentGenerations { get; set; }

    public int BaseVideoMaxConcurrentGenerations { get; set; }

    public int BaseVideoBorrowMaxConcurrentGenerations { get; set; }

    public int BaseVideoPreprocessingMaxConcurrentGenerations { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public Guid? UpdatedByAdminUserId { get; set; }

    public string? LastReason { get; set; }
}
