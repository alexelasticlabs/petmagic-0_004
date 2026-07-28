using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationCapacityPolicy
{
    public static int ResolveEffectiveImageMax(
        TemplateGenerationRuntimeSnapshot settings,
        long activeVideo,
        long queuedVideo)
    {
        var videoDemand = Math.Min(
            settings.VideoGuaranteedConcurrent,
            checked((int)Math.Min(int.MaxValue, activeVideo + queuedVideo)));
        return Math.Max(
            0,
            Math.Min(settings.ImageMaxConcurrent, settings.GlobalMaxConcurrent - videoDemand));
    }

    public static bool CanBorrowVideo(
        TemplateGenerationRuntimeSnapshot settings,
        bool elasticBorrowingEnabled,
        bool allowWhenImageQueueEmpty,
        long activeImage,
        long activeVideo,
        long queuedImage,
        out string? deniedReason)
    {
        deniedReason = null;
        if (!elasticBorrowingEnabled || settings.VideoBorrowMaxConcurrent <= 0)
        {
            deniedReason = "borrowing_disabled";
            return false;
        }

        if (activeVideo >= settings.VideoMaxConcurrent)
        {
            deniedReason = "video_max";
            return false;
        }

        if (Math.Max(0, activeVideo - settings.VideoGuaranteedConcurrent) >= settings.VideoBorrowMaxConcurrent)
        {
            deniedReason = "borrow_max";
            return false;
        }

        if (activeImage + settings.ImageProtectedConcurrent > settings.ImageMaxConcurrent)
        {
            deniedReason = "image_protected";
            return false;
        }

        if (queuedImage > 0)
        {
            deniedReason = "image_waiting";
            return false;
        }

        if (!allowWhenImageQueueEmpty)
        {
            deniedReason = "image_queue_empty_disabled";
            return false;
        }

        return true;
    }
}

internal static class FalProviderHealthPolicy
{
    public static bool IsSnapshotCurrent(DateTime? lastSuccessAtUtc, DateTime nowUtc) =>
        lastSuccessAtUtc is not null
        && nowUtc - lastSuccessAtUtc.Value <= GenerationOperationalAlertService.ProviderStaleAfter;
}
