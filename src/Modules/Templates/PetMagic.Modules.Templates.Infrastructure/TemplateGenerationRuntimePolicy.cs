using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationControlPolicyDefaults
{
    internal static readonly Guid PolicyId = Guid.Parse("4db56d66-a023-4a1c-a28d-174c46d23d61");
    internal static readonly Guid FalSnapshotId = Guid.Parse("5a829764-afcb-44dd-91f3-d9f374b8742d");

    internal const int ConfirmedFalConcurrencyLimit = 10;
    internal const int ReservedHeadroom = 2;
    internal const int ApplicationHardCeiling = 38;
    internal const int BaseGlobal = 8;
    internal const int BaseImageReserved = 3;
    internal const int BaseImageProtected = 3;
    internal const int BaseImageMax = 7;
    internal const int BaseVideoReserved = 2;
    internal const int BaseVideoMax = 4;
    internal const int BaseVideoBorrowMax = 2;
    internal const int BaseVideoPreprocessingMax = 1;

    internal static TemplateGenerationControlPolicy Create(DateTime now) => new()
    {
        Id = PolicyId,
        Revision = 1,
        AdmissionEnabled = true,
        ConfirmedFalConcurrencyLimit = ConfirmedFalConcurrencyLimit,
        ConfirmedAtUtc = now,
        ReservedHeadroom = ReservedHeadroom,
        ApplicationHardCeiling = ApplicationHardCeiling,
        BaseGlobalMaxConcurrentGenerations = BaseGlobal,
        BaseImageReservedConcurrentGenerations = BaseImageReserved,
        BaseImageProtectedConcurrentGenerations = BaseImageProtected,
        BaseImageMaxConcurrentGenerations = BaseImageMax,
        BaseVideoReservedConcurrentGenerations = BaseVideoReserved,
        BaseVideoMaxConcurrentGenerations = BaseVideoMax,
        BaseVideoBorrowMaxConcurrentGenerations = BaseVideoBorrowMax,
        BaseVideoPreprocessingMaxConcurrentGenerations = BaseVideoPreprocessingMax,
        UpdatedAtUtc = now
    };
}

internal sealed record TemplateGenerationConcurrencyProfile(
    int GlobalMaxConcurrentGenerations,
    int ImageReservedConcurrentGenerations,
    int ImageProtectedConcurrentGenerations,
    int ImageMaxConcurrentGenerations,
    int VideoReservedConcurrentGenerations,
    int VideoMaxConcurrentGenerations,
    int VideoBorrowMaxConcurrentGenerations,
    int VideoPreprocessingMaxConcurrentGenerations);

internal sealed record TemplateGenerationRuntimePolicySnapshot(
    long Revision,
    bool AdmissionEnabled,
    int ConfirmedFalConcurrencyLimit,
    DateTime ConfirmedAtUtc,
    int ReservedHeadroom,
    int ApplicationHardCeiling,
    TemplateGenerationConcurrencyProfile BaseProfile,
    TemplateGenerationConcurrencyProfile EffectiveProfile);

internal interface ITemplateGenerationRuntimePolicyProvider
{
    Task<TemplateGenerationRuntimePolicySnapshot> GetRuntimePolicyAsync(CancellationToken cancellationToken);
}

internal static class TemplateGenerationRuntimePolicyCalculator
{
    internal static TemplateGenerationRuntimePolicySnapshot Calculate(TemplateGenerationControlPolicy policy)
    {
        var effectiveGlobal = Math.Min(
            policy.ApplicationHardCeiling,
            Math.Max(0, policy.ConfirmedFalConcurrencyLimit - policy.ReservedHeadroom));
        var baseProfile = new TemplateGenerationConcurrencyProfile(
            policy.BaseGlobalMaxConcurrentGenerations,
            policy.BaseImageReservedConcurrentGenerations,
            policy.BaseImageProtectedConcurrentGenerations,
            policy.BaseImageMaxConcurrentGenerations,
            policy.BaseVideoReservedConcurrentGenerations,
            policy.BaseVideoMaxConcurrentGenerations,
            policy.BaseVideoBorrowMaxConcurrentGenerations,
            policy.BaseVideoPreprocessingMaxConcurrentGenerations);
        var effectiveProfile = Scale(baseProfile, effectiveGlobal);

        return new TemplateGenerationRuntimePolicySnapshot(
            policy.Revision,
            policy.AdmissionEnabled,
            policy.ConfirmedFalConcurrencyLimit,
            policy.ConfirmedAtUtc,
            policy.ReservedHeadroom,
            policy.ApplicationHardCeiling,
            baseProfile,
            effectiveProfile);
    }

    private static TemplateGenerationConcurrencyProfile Scale(
        TemplateGenerationConcurrencyProfile source,
        int effectiveGlobal)
    {
        if (effectiveGlobal <= 0)
        {
            return new TemplateGenerationConcurrencyProfile(0, 0, 0, 0, 0, 0, 0, 0);
        }

        var divisor = Math.Max(1, source.GlobalMaxConcurrentGenerations);
        var imageMax = Math.Min(effectiveGlobal, ScaleValue(source.ImageMaxConcurrentGenerations, effectiveGlobal, divisor));
        var videoMax = Math.Min(effectiveGlobal, ScaleValue(source.VideoMaxConcurrentGenerations, effectiveGlobal, divisor));
        var imageReserved = Math.Min(imageMax, ScaleValue(source.ImageReservedConcurrentGenerations, effectiveGlobal, divisor));
        var imageProtected = Math.Min(imageMax, ScaleValue(source.ImageProtectedConcurrentGenerations, effectiveGlobal, divisor));
        var videoReserved = Math.Min(videoMax, ScaleValue(source.VideoReservedConcurrentGenerations, effectiveGlobal, divisor));
        var videoBorrowMax = Math.Min(videoMax, ScaleValue(source.VideoBorrowMaxConcurrentGenerations, effectiveGlobal, divisor));
        var videoPreprocessingMax = Math.Min(
            Math.Max(1, videoMax),
            ScaleValue(source.VideoPreprocessingMaxConcurrentGenerations, effectiveGlobal, divisor));

        return new TemplateGenerationConcurrencyProfile(
            effectiveGlobal,
            imageReserved,
            imageProtected,
            imageMax,
            videoReserved,
            videoMax,
            videoBorrowMax,
            videoPreprocessingMax);
    }

    private static int ScaleValue(int baseValue, int effectiveGlobal, int divisor)
    {
        if (baseValue <= 0)
        {
            return 0;
        }

        return Math.Max(
            1,
            (int)Math.Round(
                (decimal)baseValue * effectiveGlobal / divisor,
                MidpointRounding.AwayFromZero));
    }
}
