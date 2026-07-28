namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationRuntimeSettings
{
    public Guid Id { get; set; }

    public long Version { get; set; }

    public int GlobalMaxConcurrent { get; set; }

    public int ImageMaxConcurrent { get; set; }

    public int ImageProtectedConcurrent { get; set; }

    public int VideoGuaranteedConcurrent { get; set; }

    public int VideoMaxConcurrent { get; set; }

    public int VideoBorrowMaxConcurrent { get; set; }

    public int WorkerLoopsPerInstance { get; set; }

    public int FalConfiguredConcurrency { get; set; }

    public int FalReservedConcurrency { get; set; }

    public decimal FalBalanceLowThresholdUsd { get; set; }

    public decimal FalBalanceCriticalThresholdUsd { get; set; }

    public bool NewClaimsPaused { get; set; }

    public Guid? DrainOperationId { get; set; }

    public string? LastChangeReason { get; set; }

    public Guid? UpdatedByAdminId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
