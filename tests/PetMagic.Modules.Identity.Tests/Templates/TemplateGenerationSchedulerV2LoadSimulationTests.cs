using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationSchedulerV2LoadSimulationTests
{
    [Fact]
    public void OneWorkerSimulation_ShouldProcessFiftyUsersAndTwoHundredMixedJobsWithinLaneCaps()
    {
        var scaled38 = CalculateProfile(confirmedFalLimit: 40);
        var report = new SchedulerV2FakeProviderSimulation(scaled38).Run();

        Assert.Equal(50, report.CompletedUserCount);
        Assert.Equal(200, report.CompletedJobCount);
        Assert.Equal(200, report.ChargeCount);
        Assert.Equal(0, report.RefundCount);
        Assert.Equal(250, report.ProviderSubmissionCount);
        Assert.Equal(0, report.DuplicateSubmissionCount);
        Assert.Equal(38, report.MaxProviderConcurrency);
        Assert.True(report.MaxImageConcurrency <= scaled38.ImageMaxConcurrentGenerations);
        Assert.True(report.MaxVideoConcurrency <= scaled38.VideoMaxConcurrentGenerations);
        Assert.True(
            report.MaxVideoPreprocessingConcurrency
                <= scaled38.VideoPreprocessingMaxConcurrentGenerations);
        Assert.Equal(1, report.MaxImportConcurrency);
        Assert.True(report.ProviderProgressEventsWhileImportBusy > 0);
        Assert.True(report.DispatchEventsWhileImportBusy > 0);
        Assert.True(report.FullCapacitySnapshotCount > 0);
        Assert.Empty(report.CapacityViolationMessages);
    }

    [Fact]
    public void OneWorkerSimulation_ShouldGuaranteeTwoVideoSlotsAtEffectiveGlobalEight()
    {
        var scaled8 = CalculateProfile(confirmedFalLimit: 10);
        var report = new SchedulerV2FakeProviderSimulation(scaled8).Run();

        Assert.Equal(8, report.MaxProviderConcurrency);
        Assert.True(report.FullCapacitySnapshotCount > 0);
        Assert.True(report.MinVideoConcurrencyAtFullCapacityWithVideoBacklog >= 2);
        Assert.True(report.MaxImageConcurrency <= scaled8.ImageMaxConcurrentGenerations);
        Assert.True(report.MaxVideoConcurrency <= scaled8.VideoMaxConcurrentGenerations);
        Assert.True(
            report.MaxVideoPreprocessingConcurrency
                <= scaled8.VideoPreprocessingMaxConcurrentGenerations);
        Assert.Equal(1, report.MaxImportConcurrency);
        Assert.Equal(200, report.CompletedJobCount);
        Assert.Empty(report.CapacityViolationMessages);
    }

    private static TemplateGenerationConcurrencyProfile CalculateProfile(int confirmedFalLimit)
    {
        var policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);
        policy.AdmissionEnabled = true;
        policy.ConfirmedFalConcurrencyLimit = confirmedFalLimit;
        return TemplateGenerationRuntimePolicyCalculator.Calculate(policy).EffectiveProfile;
    }

    private sealed class SchedulerV2FakeProviderSimulation(TemplateGenerationConcurrencyProfile profile)
    {
        private const int ImageProviderSeconds = 90;
        private const int VideoPreprocessingSeconds = 90;
        private const int VideoProviderSeconds = 420;
        private const int ImageImportSeconds = 30;
        private const int VideoImportSeconds = 120;

        public SchedulerV2LoadReport Run()
        {
            var jobs = BuildLoad();
            var providerQueue = new List<SimJob>(jobs);
            var activeProvider = new List<ActiveProviderOperation>();
            var importQueue = new Queue<SimJob>();
            ActiveImportOperation? activeImport = null;
            var submissionKeys = new HashSet<string>(StringComparer.Ordinal);
            var chargedJobIds = jobs.Select(job => job.Id).ToHashSet();
            var completed = new List<SimJob>();
            var capacityViolations = new List<string>();
            var now = 0;
            var maxProvider = 0;
            var maxImage = 0;
            var maxVideo = 0;
            var maxPreprocessing = 0;
            var maxImport = 0;
            var duplicateSubmissions = 0;
            var providerProgressWhileImportBusy = 0;
            var dispatchWhileImportBusy = 0;
            var fullCapacitySnapshots = 0;
            var minVideoAtFullCapacityWithBacklog = int.MaxValue;
            var safetyIterations = 0;

            while (completed.Count < jobs.Count)
            {
                if (++safetyIterations > 100_000)
                {
                    throw new InvalidOperationException("Scheduler V2 simulation did not converge.");
                }

                foreach (var operation in activeProvider
                    .Where(operation => operation.CompletesAtSecond <= now)
                    .ToArray())
                {
                    activeProvider.Remove(operation);
                    if (activeImport is not null)
                    {
                        providerProgressWhileImportBusy++;
                    }

                    if (operation.Stage == SimStage.VideoPreprocessing)
                    {
                        operation.Job.Stage = SimStage.VideoGeneration;
                        providerQueue.Add(operation.Job);
                    }
                    else
                    {
                        operation.Job.Stage = SimStage.Import;
                        importQueue.Enqueue(operation.Job);
                    }
                }

                if (activeImport is not null && activeImport.CompletesAtSecond <= now)
                {
                    activeImport.Job.Stage = SimStage.Completed;
                    completed.Add(activeImport.Job);
                    activeImport = null;
                }

                if (activeImport is null && importQueue.TryDequeue(out var importJob))
                {
                    activeImport = new ActiveImportOperation(
                        importJob,
                        now + (importJob.IsVideo ? VideoImportSeconds : ImageImportSeconds));
                    maxImport = Math.Max(maxImport, 1);
                }

                while (activeProvider.Count < profile.GlobalMaxConcurrentGenerations)
                {
                    var next = SelectNextProviderOperation(providerQueue, activeProvider);
                    if (next is null)
                    {
                        break;
                    }

                    providerQueue.Remove(next);
                    var submissionKey = $"{next.Id}:{next.Stage}";
                    if (!submissionKeys.Add(submissionKey))
                    {
                        duplicateSubmissions++;
                    }

                    activeProvider.Add(new ActiveProviderOperation(
                        next,
                        next.Stage,
                        now + ResolveProviderDuration(next.Stage)));
                    if (activeImport is not null)
                    {
                        dispatchWhileImportBusy++;
                    }

                    CaptureCapacity(
                        activeProvider,
                        providerQueue,
                        ref maxProvider,
                        ref maxImage,
                        ref maxVideo,
                        ref maxPreprocessing,
                        ref fullCapacitySnapshots,
                        ref minVideoAtFullCapacityWithBacklog,
                        capacityViolations);
                }

                CaptureCapacity(
                    activeProvider,
                    providerQueue,
                    ref maxProvider,
                    ref maxImage,
                    ref maxVideo,
                    ref maxPreprocessing,
                    ref fullCapacitySnapshots,
                    ref minVideoAtFullCapacityWithBacklog,
                    capacityViolations);

                if (completed.Count == jobs.Count)
                {
                    break;
                }

                var nextProviderCompletion = activeProvider.Count == 0
                    ? int.MaxValue
                    : activeProvider.Min(operation => operation.CompletesAtSecond);
                var nextImportCompletion = activeImport?.CompletesAtSecond ?? int.MaxValue;
                var nextEvent = Math.Min(nextProviderCompletion, nextImportCompletion);
                if (nextEvent == int.MaxValue)
                {
                    throw new InvalidOperationException(
                        $"Scheduler V2 simulation stalled with {providerQueue.Count} provider and {importQueue.Count} import jobs queued.");
                }

                now = nextEvent;
            }

            return new SchedulerV2LoadReport(
                completed.Select(job => job.UserId).Distinct().Count(),
                completed.Count,
                chargedJobIds.Count,
                RefundCount: 0,
                submissionKeys.Count,
                duplicateSubmissions,
                maxProvider,
                maxImage,
                maxVideo,
                maxPreprocessing,
                maxImport,
                providerProgressWhileImportBusy,
                dispatchWhileImportBusy,
                fullCapacitySnapshots,
                minVideoAtFullCapacityWithBacklog == int.MaxValue
                    ? 0
                    : minVideoAtFullCapacityWithBacklog,
                capacityViolations);
        }

        private SimJob? SelectNextProviderOperation(
            IReadOnlyCollection<SimJob> queued,
            IReadOnlyCollection<ActiveProviderOperation> active)
        {
            var activeImages = active.Count(operation => operation.Stage == SimStage.ImageGeneration);
            var activeVideos = active.Count(operation => operation.Stage is
                SimStage.VideoPreprocessing or SimStage.VideoGeneration);
            var activePreprocessing = active.Count(operation =>
                operation.Stage == SimStage.VideoPreprocessing);
            var runnableVideo = queued
                .Where(job => job.Stage == SimStage.VideoGeneration
                    || (job.Stage == SimStage.VideoPreprocessing
                        && activePreprocessing < profile.VideoPreprocessingMaxConcurrentGenerations))
                .OrderBy(job => job.Id)
                .FirstOrDefault();
            if (activeVideos < profile.VideoReservedConcurrentGenerations
                && activeVideos < profile.VideoMaxConcurrentGenerations
                && runnableVideo is not null)
            {
                return runnableVideo;
            }

            var hasVideoBacklog = queued.Any(job => job.Stage is
                SimStage.VideoPreprocessing or SimStage.VideoGeneration);
            var missingReservedVideo = Math.Max(
                0,
                profile.VideoReservedConcurrentGenerations - activeVideos);
            var image = queued
                .Where(job => job.Stage == SimStage.ImageGeneration)
                .OrderBy(job => job.Id)
                .FirstOrDefault();
            if (image is not null
                && activeImages < profile.ImageMaxConcurrentGenerations
                && (!hasVideoBacklog
                    || profile.GlobalMaxConcurrentGenerations - (active.Count + 1)
                        >= missingReservedVideo))
            {
                return image;
            }

            if (runnableVideo is null || activeVideos >= profile.VideoMaxConcurrentGenerations)
            {
                return null;
            }

            var borrowedVideo = Math.Max(
                0,
                activeVideos - profile.VideoReservedConcurrentGenerations);
            var imageBacklog = queued.Any(job => job.Stage == SimStage.ImageGeneration);
            return !imageBacklog
                && borrowedVideo < profile.VideoBorrowMaxConcurrentGenerations
                    ? runnableVideo
                    : null;
        }

        private void CaptureCapacity(
            IReadOnlyCollection<ActiveProviderOperation> active,
            IReadOnlyCollection<SimJob> queued,
            ref int maxProvider,
            ref int maxImage,
            ref int maxVideo,
            ref int maxPreprocessing,
            ref int fullCapacitySnapshots,
            ref int minVideoAtFullCapacityWithBacklog,
            ICollection<string> violations)
        {
            var image = active.Count(operation => operation.Stage == SimStage.ImageGeneration);
            var video = active.Count(operation => operation.Stage is
                SimStage.VideoPreprocessing or SimStage.VideoGeneration);
            var preprocessing = active.Count(operation =>
                operation.Stage == SimStage.VideoPreprocessing);
            maxProvider = Math.Max(maxProvider, active.Count);
            maxImage = Math.Max(maxImage, image);
            maxVideo = Math.Max(maxVideo, video);
            maxPreprocessing = Math.Max(maxPreprocessing, preprocessing);
            if (active.Count > profile.GlobalMaxConcurrentGenerations)
            {
                violations.Add("global");
            }

            if (image > profile.ImageMaxConcurrentGenerations)
            {
                violations.Add("image");
            }

            if (video > profile.VideoMaxConcurrentGenerations)
            {
                violations.Add("video");
            }

            if (preprocessing > profile.VideoPreprocessingMaxConcurrentGenerations)
            {
                violations.Add("video_preprocessing");
            }

            var videoBacklog = queued.Any(job => job.Stage is
                SimStage.VideoPreprocessing or SimStage.VideoGeneration);
            if (active.Count == profile.GlobalMaxConcurrentGenerations)
            {
                fullCapacitySnapshots++;
                if (videoBacklog)
                {
                    minVideoAtFullCapacityWithBacklog = Math.Min(
                        minVideoAtFullCapacityWithBacklog,
                        video);
                    if (video < profile.VideoReservedConcurrentGenerations)
                    {
                        violations.Add("video_reserved");
                    }
                }
            }
        }

        private static int ResolveProviderDuration(SimStage stage) => stage switch
        {
            SimStage.ImageGeneration => ImageProviderSeconds,
            SimStage.VideoPreprocessing => VideoPreprocessingSeconds,
            SimStage.VideoGeneration => VideoProviderSeconds,
            _ => throw new ArgumentOutOfRangeException(nameof(stage), stage, null)
        };

        private static List<SimJob> BuildLoad()
        {
            var jobs = new List<SimJob>(capacity: 200);
            var id = 0;
            for (var userId = 1; userId <= 50; userId++)
            {
                for (var userJob = 0; userJob < 4; userJob++)
                {
                    var isVideo = userJob == 3;
                    jobs.Add(new SimJob(
                        ++id,
                        userId,
                        isVideo,
                        isVideo ? SimStage.VideoPreprocessing : SimStage.ImageGeneration));
                }
            }

            return jobs;
        }
    }

    private enum SimStage
    {
        ImageGeneration,
        VideoPreprocessing,
        VideoGeneration,
        Import,
        Completed
    }

    private sealed class SimJob(int id, int userId, bool isVideo, SimStage stage)
    {
        public int Id { get; } = id;

        public int UserId { get; } = userId;

        public bool IsVideo { get; } = isVideo;

        public SimStage Stage { get; set; } = stage;
    }

    private sealed record ActiveProviderOperation(
        SimJob Job,
        SimStage Stage,
        int CompletesAtSecond);

    private sealed record ActiveImportOperation(SimJob Job, int CompletesAtSecond);

    private sealed record SchedulerV2LoadReport(
        int CompletedUserCount,
        int CompletedJobCount,
        int ChargeCount,
        int RefundCount,
        int ProviderSubmissionCount,
        int DuplicateSubmissionCount,
        int MaxProviderConcurrency,
        int MaxImageConcurrency,
        int MaxVideoConcurrency,
        int MaxVideoPreprocessingConcurrency,
        int MaxImportConcurrency,
        int ProviderProgressEventsWhileImportBusy,
        int DispatchEventsWhileImportBusy,
        int FullCapacitySnapshotCount,
        int MinVideoConcurrencyAtFullCapacityWithVideoBacklog,
        IReadOnlyCollection<string> CapacityViolationMessages);
}
