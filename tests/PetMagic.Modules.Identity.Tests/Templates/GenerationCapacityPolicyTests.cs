using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class GenerationCapacityPolicyTests
{
    [Fact]
    public void ResolveEffectiveImageMax_ShouldAllowSevenImages_WhenVideoHasNoDemand()
    {
        Assert.Equal(7, TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(TargetSettings(), 0, 0));
    }

    [Fact]
    public void ResolveEffectiveImageMax_ShouldReserveTwoGlobalSlots_WhenTwoVideosAreWaiting()
    {
        Assert.Equal(6, TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(TargetSettings(), 0, 2));
    }

    [Fact]
    public void ResolveEffectiveImageMax_ShouldReserveOnlyObservedDemand_UpToGuarantee()
    {
        Assert.Equal(7, TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(TargetSettings(), 0, 1));
        Assert.Equal(6, TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(TargetSettings(), 1, 1));
        Assert.Equal(6, TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(TargetSettings(), 2, 50));
    }

    [Fact]
    public void CanBorrowVideo_ShouldRequireEmptyImageQueue()
    {
        var allowed = TemplateGenerationCapacityPolicy.CanBorrowVideo(
            TargetSettings(),
            elasticBorrowingEnabled: true,
            allowWhenImageQueueEmpty: true,
            activeImage: 0,
            activeVideo: 2,
            queuedImage: 1,
            out var deniedReason);

        Assert.False(allowed);
        Assert.Equal("image_waiting", deniedReason);
    }

    [Fact]
    public void CanBorrowVideo_ShouldAllowTwoBorrowedSlots_WithoutImageDemand()
    {
        Assert.True(TemplateGenerationCapacityPolicy.CanBorrowVideo(
            TargetSettings(), true, true, 0, 2, 0, out var firstReason));
        Assert.Null(firstReason);
        Assert.True(TemplateGenerationCapacityPolicy.CanBorrowVideo(
            TargetSettings(), true, true, 0, 3, 0, out var secondReason));
        Assert.Null(secondReason);
        Assert.False(TemplateGenerationCapacityPolicy.CanBorrowVideo(
            TargetSettings(), true, true, 0, 4, 0, out var maxReason));
        Assert.Equal("video_max", maxReason);
    }

    [Fact]
    public void FalSnapshotFreshness_ShouldBeBasedOnLastSuccessfulRefresh()
    {
        var now = new DateTime(2026, 7, 28, 12, 0, 0, DateTimeKind.Utc);

        Assert.True(FalProviderHealthPolicy.IsSnapshotCurrent(now.AddSeconds(-179), now));
        Assert.False(FalProviderHealthPolicy.IsSnapshotCurrent(now.AddSeconds(-181), now));
        Assert.False(FalProviderHealthPolicy.IsSnapshotCurrent(null, now));
    }

    private static TemplateGenerationRuntimeSnapshot TargetSettings() => new(
        Version: 1,
        GlobalMaxConcurrent: 8,
        ImageMaxConcurrent: 7,
        ImageProtectedConcurrent: 3,
        VideoGuaranteedConcurrent: 2,
        VideoMaxConcurrent: 4,
        VideoBorrowMaxConcurrent: 2,
        WorkerLoopsPerInstance: 2,
        FalConfiguredConcurrency: 10,
        FalReservedConcurrency: 2,
        FalBalanceLowThresholdUsd: 10,
        FalBalanceCriticalThresholdUsd: 5,
        NewClaimsPaused: false,
        DrainOperationId: null,
        UpdatedAtUtc: DateTime.UtcNow);
}
