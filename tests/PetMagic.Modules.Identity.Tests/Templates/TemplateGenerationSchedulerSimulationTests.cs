using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationSchedulerSimulationTests
{
    [Fact]
    public void SchedulerSimulation_ShouldIsolateMediaCapacityPrioritizePremiumAndAvoidFreeStarvation()
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "https://example.test/templates",
            LocalMediaRootPath = "temp/templates-media",
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "generate",
            AllowedImageModels = ["fake-image-model"],
            AllowedPreprocessingModels = ["fake-preprocess-model"],
            AllowedKlingModels = ["fake-video-model"],
            SupportedLocalizationLocales = ["en"],
            GlobalMaxConcurrentGenerations = 3,
            ImageMaxConcurrentGenerations = 2,
            VideoMaxConcurrentGenerations = 1,
            EstimatedImageGenerationSeconds = 90,
            EstimatedVideoGenerationSeconds = 420,
            FreeQueuePriorityScore = 1_000,
            PremiumQueuePriorityScore = 4_000,
            PrivilegedQueuePriorityScore = 8_000,
            AdminQueuePriorityScore = 10_000,
            QueuePriorityAgingIntervalSeconds = 60,
            QueuePriorityAgingBoost = 500
        };
        var simulator = new SchedulerSimulator(options);
        var arrivals = BuildLoad(options).ToArray();

        var report = simulator.Run(arrivals);

        Assert.True(report.AcceptedCount > 0);
        Assert.True(report.RejectedCount > 0);
        Assert.True(report.MaxGlobalConcurrency <= options.GlobalMaxConcurrentGenerations);
        Assert.True(report.MaxImageConcurrency <= options.ImageMaxConcurrentGenerations);
        Assert.True(report.MaxVideoConcurrency <= options.VideoMaxConcurrentGenerations);
        Assert.True(report.AverageWait(TemplateGenerationQueue.MediaTypeImage, TemplateGenerationQueue.TierPremium)
            < report.AverageWait(TemplateGenerationQueue.MediaTypeImage, TemplateGenerationQueue.TierFree));
        Assert.True(report.AverageWait(TemplateGenerationQueue.MediaTypeVideo, TemplateGenerationQueue.TierPremium)
            < report.AverageWait(TemplateGenerationQueue.MediaTypeVideo, TemplateGenerationQueue.TierFree));
        Assert.True(report.CompletedFreeJobs > 0);
        Assert.True(report.FreeP99WaitSeconds <= 3_600);
        Assert.True(report.P99WaitSeconds >= report.P95WaitSeconds);
        Assert.Empty(report.StarvedJobIds);
    }

    [Fact]
    public void SchedulerSimulation_ShouldBoundFreeVideoStarvationDuringVideoOverload()
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "https://example.test/templates",
            LocalMediaRootPath = "temp/templates-media",
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "generate",
            AllowedImageModels = ["fake-image-model"],
            AllowedPreprocessingModels = ["fake-preprocess-model"],
            AllowedKlingModels = ["fake-video-model"],
            SupportedLocalizationLocales = ["en"],
            GlobalMaxConcurrentGenerations = 3,
            ImageMaxConcurrentGenerations = 2,
            VideoMaxConcurrentGenerations = 1,
            EstimatedImageGenerationSeconds = 90,
            EstimatedVideoGenerationSeconds = 420,
            FreeQueuePriorityScore = 1_000,
            PremiumQueuePriorityScore = 4_000,
            PrivilegedQueuePriorityScore = 8_000,
            AdminQueuePriorityScore = 10_000,
            QueuePriorityAgingIntervalSeconds = 60,
            QueuePriorityAgingBoost = 500
        };
        var simulator = new SchedulerSimulator(options);
        var arrivals = BuildVideoOverload(options).ToArray();

        var report = simulator.Run(arrivals);

        Assert.True(report.RejectedCount > 0);
        Assert.True(report.RejectedCountFor(TemplateGenerationQueue.MediaTypeVideo, TemplateGenerationQueue.TierFree) > 0);
        Assert.True(report.AcceptedCountFor(TemplateGenerationQueue.MediaTypeImage) > 0);
        Assert.True(report.AverageWaitForMedia(TemplateGenerationQueue.MediaTypeImage)
            < report.AverageWaitForMedia(TemplateGenerationQueue.MediaTypeVideo));
        Assert.True(report.AverageWait(TemplateGenerationQueue.MediaTypeVideo, TemplateGenerationQueue.TierPremium)
            < report.AverageWait(TemplateGenerationQueue.MediaTypeVideo, TemplateGenerationQueue.TierFree));
        Assert.True(report.MaxGlobalConcurrency <= options.GlobalMaxConcurrentGenerations);
        Assert.True(report.MaxImageConcurrency <= options.ImageMaxConcurrentGenerations);
        Assert.True(report.MaxVideoConcurrency <= options.VideoMaxConcurrentGenerations);
        Assert.True(report.FreeVideoP99WaitSeconds <= options.FreeVideoMaxEstimatedWaitSeconds + options.EstimatedVideoGenerationSeconds);
        Assert.Empty(report.CapViolationMessages);
    }

    [Fact]
    public void SchedulerSimulation_ShouldIncreaseVideoThroughput_WhenImageQueueIsEmpty()
    {
        var options = CreateElasticOptions();
        var simulator = new SchedulerSimulator(options);
        var arrivals = Enumerable.Range(0, 1_000)
            .Select(i => new SimJob(
                Id: i + 1,
                ArrivedAtSecond: i,
                MediaType: TemplateGenerationQueue.MediaTypeVideo,
                Tier: i % 10 == 0 ? TemplateGenerationQueue.TierPremium : TemplateGenerationQueue.TierFree,
                DurationSeconds: options.EstimatedVideoGenerationSeconds,
                MaxEstimatedWaitSeconds: 24 * 60 * 60))
            .ToArray();

        var report = simulator.Run(arrivals);

        Assert.True(report.MaxVideoConcurrency > options.VideoReservedConcurrentGenerations);
        Assert.True(report.MaxVideoConcurrency <= options.VideoMaxConcurrentGenerations);
        Assert.True(report.MaxBorrowedVideoConcurrency <= options.VideoBorrowMaxConcurrentGenerations);
        Assert.Empty(report.CapViolationMessages);
    }

    [Fact]
    public void SchedulerSimulation_ShouldStopNewBorrowing_WhenImageBurstArrives()
    {
        var options = CreateElasticOptions();
        var simulator = new SchedulerSimulator(options);
        var videoArrivals = Enumerable.Range(0, 160)
            .Select(i => new SimJob(
                Id: i + 1,
                ArrivedAtSecond: i * 5,
                MediaType: TemplateGenerationQueue.MediaTypeVideo,
                Tier: i % 12 == 0 ? TemplateGenerationQueue.TierPremium : TemplateGenerationQueue.TierFree,
                DurationSeconds: options.EstimatedVideoGenerationSeconds,
                MaxEstimatedWaitSeconds: 24 * 60 * 60));
        var imageBurst = Enumerable.Range(0, 100)
            .Select(i => new SimJob(
                Id: 10_000 + i,
                ArrivedAtSecond: 180 + i,
                MediaType: TemplateGenerationQueue.MediaTypeImage,
                Tier: TemplateGenerationQueue.TierFree,
                DurationSeconds: options.EstimatedImageGenerationSeconds,
                MaxEstimatedWaitSeconds: options.FreeImageMaxEstimatedWaitSeconds));

        var report = simulator.Run(videoArrivals.Concat(imageBurst).ToArray());

        Assert.True(report.MaxBorrowedVideoConcurrency <= options.VideoBorrowMaxConcurrentGenerations);
        Assert.Equal(0, report.BorrowedVideoStartsWhileImageBacklogged);
        Assert.True(report.P95WaitForMedia(TemplateGenerationQueue.MediaTypeImage)
            <= Math.Ceiling(100 * options.EstimatedImageGenerationSeconds / (double)options.ImageProtectedConcurrentGenerations));
        Assert.Empty(report.CapViolationMessages);
    }

    private static TemplatesOptions CreateElasticOptions()
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "https://example.test/templates",
            LocalMediaRootPath = "temp/templates-media",
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "generate",
            AllowedImageModels = ["fake-image-model"],
            AllowedPreprocessingModels = ["fake-preprocess-model"],
            AllowedKlingModels = ["fake-video-model"],
            SupportedLocalizationLocales = ["en"],
            GlobalMaxConcurrentGenerations = 32,
            ImageReservedConcurrentGenerations = 12,
            ImageProtectedConcurrentGenerations = 8,
            ImageMaxConcurrentGenerations = 28,
            VideoReservedConcurrentGenerations = 8,
            VideoMaxConcurrentGenerations = 20,
            VideoBorrowMaxConcurrentGenerations = 12,
            EnableElasticLaneBorrowing = true,
            AllowVideoBorrowWhenImageQueueEmpty = true,
            AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds = 120,
            EstimatedImageGenerationSeconds = 90,
            EstimatedVideoGenerationSeconds = 420,
            FreeQueuePriorityScore = 1_000,
            PremiumQueuePriorityScore = 4_000,
            PrivilegedQueuePriorityScore = 8_000,
            AdminQueuePriorityScore = 10_000,
            QueuePriorityAgingIntervalSeconds = 60,
            QueuePriorityAgingBoost = 500
        };
    }

    private static IEnumerable<SimJob> BuildLoad(TemplatesOptions options)
    {
        for (var i = 0; i < 90; i++)
        {
            var tier = i % 6 == 0 ? TemplateGenerationQueue.TierPremium : TemplateGenerationQueue.TierFree;
            yield return new SimJob(
                Id: i + 1,
                ArrivedAtSecond: i * 15,
                MediaType: TemplateGenerationQueue.MediaTypeImage,
                Tier: tier,
                DurationSeconds: options.EstimatedImageGenerationSeconds,
                MaxEstimatedWaitSeconds: tier == TemplateGenerationQueue.TierPremium ? 360 : 900);
        }

        for (var i = 0; i < 45; i++)
        {
            var tier = i % 5 == 0 ? TemplateGenerationQueue.TierPremium : TemplateGenerationQueue.TierFree;
            yield return new SimJob(
                Id: 10_000 + i,
                ArrivedAtSecond: i * 45,
                MediaType: TemplateGenerationQueue.MediaTypeVideo,
                Tier: tier,
                DurationSeconds: options.EstimatedVideoGenerationSeconds,
                MaxEstimatedWaitSeconds: tier == TemplateGenerationQueue.TierPremium ? 900 : 2_400);
        }
    }

    private static IEnumerable<SimJob> BuildVideoOverload(TemplatesOptions options)
    {
        for (var i = 0; i < 260; i++)
        {
            var tier = i % 12 == 0 ? TemplateGenerationQueue.TierPremium : TemplateGenerationQueue.TierFree;
            yield return new SimJob(
                Id: i + 1,
                ArrivedAtSecond: i * 20,
                MediaType: TemplateGenerationQueue.MediaTypeVideo,
                Tier: tier,
                DurationSeconds: options.EstimatedVideoGenerationSeconds,
                MaxEstimatedWaitSeconds: tier == TemplateGenerationQueue.TierPremium
                    ? options.PremiumVideoMaxEstimatedWaitSeconds
                    : options.FreeVideoMaxEstimatedWaitSeconds);
        }

        for (var i = 0; i < 120; i++)
        {
            yield return new SimJob(
                Id: 10_000 + i,
                ArrivedAtSecond: 600 + i * 20,
                MediaType: TemplateGenerationQueue.MediaTypeImage,
                Tier: TemplateGenerationQueue.TierFree,
                DurationSeconds: options.EstimatedImageGenerationSeconds,
                MaxEstimatedWaitSeconds: options.FreeImageMaxEstimatedWaitSeconds);
        }
    }

    private sealed class SchedulerSimulator(TemplatesOptions options)
    {
        public SimulationReport Run(IReadOnlyCollection<SimJob> arrivals)
        {
            var pendingArrivals = arrivals.OrderBy(x => x.ArrivedAtSecond).ToList();
            var queued = new List<SimJob>();
            var running = new List<RunningJob>();
            var completed = new List<CompletedJob>();
            var rejected = new List<RejectedJob>();
            var maxGlobalConcurrency = 0;
            var maxImageConcurrency = 0;
            var maxVideoConcurrency = 0;
            var maxBorrowedVideoConcurrency = 0;
            var borrowedVideoStartsWhileImageBacklogged = 0;
            var capViolationMessages = new List<string>();
            var now = 0;

            while (pendingArrivals.Count > 0 || queued.Count > 0 || running.Count > 0)
            {
                var nextArrival = pendingArrivals.Count > 0 ? pendingArrivals[0].ArrivedAtSecond : int.MaxValue;
                var nextCompletion = running.Count > 0 ? running.Min(x => x.EndsAtSecond) : int.MaxValue;
                now = Math.Min(nextArrival, nextCompletion);

                foreach (var completedJob in running.Where(x => x.EndsAtSecond <= now).ToArray())
                {
                    running.Remove(completedJob);
                    completed.Add(new CompletedJob(
                        completedJob.Job,
                        completedJob.StartedAtSecond,
                        completedJob.EndsAtSecond));
                }

                foreach (var arrival in pendingArrivals.Where(x => x.ArrivedAtSecond <= now).ToArray())
                {
                    pendingArrivals.Remove(arrival);
                    var estimatedWait = EstimateWaitSeconds(arrival, queued, running);
                    if (estimatedWait > arrival.MaxEstimatedWaitSeconds)
                    {
                        rejected.Add(new RejectedJob(arrival, estimatedWait));
                        continue;
                    }

                    queued.Add(arrival);
                }

                var claimedAny = true;
                while (claimedAny)
                {
                    claimedAny = false;
                    if (running.Count >= options.GlobalMaxConcurrentGenerations)
                    {
                        break;
                    }

                    var next = queued
                        .Where(job => HasMediaSlot(job.MediaType, running, queued))
                        .OrderByDescending(job => PriorityScore(job, now))
                        .ThenBy(job => job.ArrivedAtSecond)
                        .ThenBy(job => job.Id)
                        .FirstOrDefault();
                    if (next is null)
                    {
                        break;
                    }

                    queued.Remove(next);
                    var activeVideoBeforeStart = running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo);
                    if (next.MediaType == TemplateGenerationQueue.MediaTypeVideo
                        && activeVideoBeforeStart >= ResolveVideoReservedConcurrency()
                        && queued.Any(x => x.MediaType == TemplateGenerationQueue.MediaTypeImage))
                    {
                        borrowedVideoStartsWhileImageBacklogged++;
                    }

                    running.Add(new RunningJob(next, now, now + next.DurationSeconds));
                    maxGlobalConcurrency = Math.Max(maxGlobalConcurrency, running.Count);
                    maxImageConcurrency = Math.Max(
                        maxImageConcurrency,
                        running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeImage));
                    maxVideoConcurrency = Math.Max(
                        maxVideoConcurrency,
                        running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo));
                    maxBorrowedVideoConcurrency = Math.Max(
                        maxBorrowedVideoConcurrency,
                        Math.Max(0, running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo) - ResolveVideoReservedConcurrency()));
                    if (running.Count > options.GlobalMaxConcurrentGenerations)
                    {
                        capViolationMessages.Add("global");
                    }

                    if (running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeImage) > options.ImageMaxConcurrentGenerations)
                    {
                        capViolationMessages.Add("image");
                    }

                    if (running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo) > options.VideoMaxConcurrentGenerations)
                    {
                        capViolationMessages.Add("video");
                    }

                    if (Math.Max(0, running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo) - ResolveVideoReservedConcurrency())
                        > Math.Max(0, options.VideoBorrowMaxConcurrentGenerations))
                    {
                        capViolationMessages.Add("video_borrow");
                    }

                    claimedAny = true;
                }
            }

            return new SimulationReport(
                completed,
                rejected,
                maxGlobalConcurrency,
                maxImageConcurrency,
                maxVideoConcurrency,
                maxBorrowedVideoConcurrency,
                borrowedVideoStartsWhileImageBacklogged,
                capViolationMessages);
        }

        private int EstimateWaitSeconds(SimJob job, IReadOnlyCollection<SimJob> queued, IReadOnlyCollection<RunningJob> running)
        {
            var queuedAhead = queued.Count(x => x.MediaType == job.MediaType
                && PriorityScore(x, job.ArrivedAtSecond) >= TemplateGenerationQueue.ResolveTierBaseScore(job.Tier, options));
            var runningSameMedia = running.Count(x => x.Job.MediaType == job.MediaType);
            var effectiveSlots = job.MediaType == TemplateGenerationQueue.MediaTypeVideo
                ? ResolveVideoEffectiveSlots(running, queued)
                : ResolveImageEffectiveSlots(running);

            return (int)Math.Ceiling(Math.Max(0, runningSameMedia + queuedAhead) * job.DurationSeconds / (double)Math.Max(1, effectiveSlots));
        }

        private bool HasMediaSlot(string mediaType, IReadOnlyCollection<RunningJob> running, IReadOnlyCollection<SimJob> queued)
        {
            if (mediaType == TemplateGenerationQueue.MediaTypeImage)
            {
                return running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeImage) < ResolveImageEffectiveSlots(running);
            }

            return running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo) < ResolveVideoEffectiveSlots(running, queued);
        }

        private int ResolveImageEffectiveSlots(IReadOnlyCollection<RunningJob> running)
        {
            var borrowedVideo = Math.Max(0, running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo) - ResolveVideoReservedConcurrency());
            return Math.Max(1, Math.Min(
                options.ImageMaxConcurrentGenerations,
                Math.Max(ResolveImageProtectedConcurrency(), options.GlobalMaxConcurrentGenerations - borrowedVideo)));
        }

        private int ResolveVideoEffectiveSlots(IReadOnlyCollection<RunningJob> running, IReadOnlyCollection<SimJob> queued)
        {
            var reserved = ResolveVideoReservedConcurrency();
            if (!CanBorrowVideo(running, queued))
            {
                return reserved;
            }

            return Math.Max(1, Math.Min(options.VideoMaxConcurrentGenerations, reserved + Math.Max(0, options.VideoBorrowMaxConcurrentGenerations)));
        }

        private bool CanBorrowVideo(IReadOnlyCollection<RunningJob> running, IReadOnlyCollection<SimJob> queued)
        {
            if (!options.EnableElasticLaneBorrowing || options.VideoBorrowMaxConcurrentGenerations <= 0)
            {
                return false;
            }

            var activeVideo = running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo);
            if (activeVideo >= options.VideoMaxConcurrentGenerations)
            {
                return false;
            }

            if (Math.Max(0, activeVideo - ResolveVideoReservedConcurrency()) >= options.VideoBorrowMaxConcurrentGenerations)
            {
                return false;
            }

            var activeImage = running.Count(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeImage);
            if (activeImage + ResolveImageProtectedConcurrency() > options.ImageMaxConcurrentGenerations)
            {
                return false;
            }

            var queuedImage = queued.Count(x => x.MediaType == TemplateGenerationQueue.MediaTypeImage);
            if (queuedImage == 0)
            {
                return options.AllowVideoBorrowWhenImageQueueEmpty;
            }

            var protectedSlots = Math.Max(1, ResolveImageProtectedConcurrency());
            var imageEstimatedWait = (int)Math.Ceiling(Math.Max(0, activeImage + queuedImage - protectedSlots)
                * Math.Max(1, options.EstimatedImageGenerationSeconds)
                / (double)protectedSlots);
            return imageEstimatedWait <= options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds;
        }

        private int ResolveImageProtectedConcurrency()
        {
            return options.ImageProtectedConcurrentGenerations > 0
                ? options.ImageProtectedConcurrentGenerations
                : options.ImageMaxConcurrentGenerations;
        }

        private int ResolveVideoReservedConcurrency()
        {
            return options.VideoReservedConcurrentGenerations > 0
                ? options.VideoReservedConcurrentGenerations
                : options.VideoMaxConcurrentGenerations;
        }

        private int PriorityScore(SimJob job, int now)
        {
            var baseScore = TemplateGenerationQueue.ResolveTierBaseScore(job.Tier, options);
            var waitedSeconds = Math.Max(0, now - job.ArrivedAtSecond);
            var agingSteps = waitedSeconds / Math.Max(1, options.QueuePriorityAgingIntervalSeconds);
            return baseScore + agingSteps * Math.Max(0, options.QueuePriorityAgingBoost);
        }
    }

    private sealed record SimJob(
        int Id,
        int ArrivedAtSecond,
        string MediaType,
        string Tier,
        int DurationSeconds,
        int MaxEstimatedWaitSeconds);

    private sealed record RunningJob(SimJob Job, int StartedAtSecond, int EndsAtSecond);

    private sealed record CompletedJob(SimJob Job, int StartedAtSecond, int CompletedAtSecond)
    {
        public int WaitSeconds => StartedAtSecond - Job.ArrivedAtSecond;
    }

    private sealed record RejectedJob(SimJob Job, int EstimatedWaitSeconds);

    private sealed record SimulationReport(
        IReadOnlyCollection<CompletedJob> Completed,
        IReadOnlyCollection<RejectedJob> Rejected,
        int MaxGlobalConcurrency,
        int MaxImageConcurrency,
        int MaxVideoConcurrency,
        int MaxBorrowedVideoConcurrency,
        int BorrowedVideoStartsWhileImageBacklogged,
        IReadOnlyCollection<string> CapViolationMessages)
    {
        public int AcceptedCount => Completed.Count;

        public int RejectedCount => Rejected.Count;

        public int CompletedFreeJobs => Completed.Count(x => x.Job.Tier == TemplateGenerationQueue.TierFree);

        public double P95WaitSeconds => Percentile(Completed.Select(x => x.WaitSeconds), 0.95);

        public double P99WaitSeconds => Percentile(Completed.Select(x => x.WaitSeconds), 0.99);

        public double FreeP99WaitSeconds => Percentile(
            Completed.Where(x => x.Job.Tier == TemplateGenerationQueue.TierFree).Select(x => x.WaitSeconds),
            0.99);

        public double FreeVideoP99WaitSeconds => Percentile(
            Completed
                .Where(x => x.Job.MediaType == TemplateGenerationQueue.MediaTypeVideo
                    && x.Job.Tier == TemplateGenerationQueue.TierFree)
                .Select(x => x.WaitSeconds),
            0.99);

        public IReadOnlyCollection<int> StarvedJobIds => Completed
            .Where(x => x.Job.Tier == TemplateGenerationQueue.TierFree
                && x.WaitSeconds > x.Job.MaxEstimatedWaitSeconds + x.Job.DurationSeconds)
            .Select(x => x.Job.Id)
            .ToArray();

        public double AverageWait(string mediaType, string tier)
        {
            var waits = Completed
                .Where(x => x.Job.MediaType == mediaType && x.Job.Tier == tier)
                .Select(x => x.WaitSeconds)
                .ToArray();

            Assert.NotEmpty(waits);
            return waits.Average();
        }

        public int AcceptedCountFor(string mediaType)
        {
            return Completed.Count(x => x.Job.MediaType == mediaType);
        }

        public int RejectedCountFor(string mediaType, string tier)
        {
            return Rejected.Count(x => x.Job.MediaType == mediaType && x.Job.Tier == tier);
        }

        public double AverageWaitForMedia(string mediaType)
        {
            var waits = Completed
                .Where(x => x.Job.MediaType == mediaType)
                .Select(x => x.WaitSeconds)
                .ToArray();

            Assert.NotEmpty(waits);
            return waits.Average();
        }

        public double P95WaitForMedia(string mediaType)
        {
            return Percentile(
                Completed.Where(x => x.Job.MediaType == mediaType).Select(x => x.WaitSeconds),
                0.95);
        }

        private static double Percentile(IEnumerable<int> source, double percentile)
        {
            var values = source.OrderBy(x => x).ToArray();
            Assert.NotEmpty(values);
            var index = (int)Math.Ceiling(percentile * values.Length) - 1;
            return values[Math.Clamp(index, 0, values.Length - 1)];
        }
    }
}
