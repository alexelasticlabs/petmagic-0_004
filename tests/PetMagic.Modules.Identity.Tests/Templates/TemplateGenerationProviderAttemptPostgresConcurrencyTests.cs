using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed class TemplateGenerationProviderAttemptPostgresConcurrencyTests
{
    private static readonly TemplateGenerationProviderAttemptState[] ActiveStates =
    [
        TemplateGenerationProviderAttemptState.SubmitReserved,
        TemplateGenerationProviderAttemptState.Submitting,
        TemplateGenerationProviderAttemptState.ProviderQueued,
        TemplateGenerationProviderAttemptState.ProviderProcessing,
        TemplateGenerationProviderAttemptState.SubmissionUnknown
    ];

    [Fact]
    public async Task ConcurrentReservation_ShouldNeverExceedEffectiveCapacityOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        var templateId = Guid.NewGuid();
        Guid[] jobIds = [];
        try
        {
            int baselineActive;
            int baselineImages;
            await using (var seedContext = new TemplatesDbContext(options))
            {
                baselineActive = await seedContext.TemplateGenerationProviderAttempts.CountAsync(
                    attempt => ActiveStates.Contains(attempt.State));
                baselineImages = await seedContext.TemplateGenerationProviderAttempts.CountAsync(
                    attempt => ActiveStates.Contains(attempt.State)
                        && attempt.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration);
                jobIds = await SeedJobsAsync(seedContext, templateId, count: 12);
            }

            const int testCapacity = 8;
            var effectiveGlobal = baselineActive + testCapacity;
            var effectiveImageMax = baselineImages + testCapacity;
            var profile = new TemplateGenerationConcurrencyProfile(
                effectiveGlobal,
                effectiveImageMax,
                effectiveImageMax,
                effectiveImageMax,
                VideoReservedConcurrentGenerations: 0,
                VideoMaxConcurrentGenerations: effectiveGlobal,
                VideoBorrowMaxConcurrentGenerations: effectiveGlobal,
                VideoPreprocessingMaxConcurrentGenerations: effectiveGlobal);
            var policy = new TemplateGenerationRuntimePolicySnapshot(
                Revision: 1,
                AdmissionEnabled: true,
                ConfirmedFalConcurrencyLimit: effectiveGlobal + 2,
                ConfirmedAtUtc: DateTime.UtcNow,
                ReservedHeadroom: 2,
                ApplicationHardCeiling: effectiveGlobal,
                BaseProfile: profile,
                EffectiveProfile: profile);
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var workers = jobIds.Select(async (jobId, index) =>
            {
                await using var workerContext = new TemplatesDbContext(options);
                var store = new TemplateGenerationProviderAttemptStore(
                    workerContext,
                    new StaticRuntimePolicyProvider(policy),
                    new StaticRuntimeSnapshotService(CreateFreshBalanceSnapshot()),
                    CreateStoreOptions());
                await start.Task;
                return await store.TryReserveAsync(
                    CreateReservation(jobId, $"{templateId:N}:{index}"),
                    CancellationToken.None);
            }).ToArray();

            start.TrySetResult();
            var results = await Task.WhenAll(workers);

            Assert.Equal(testCapacity, results.Count(attempt => attempt is not null));
            await using var verificationContext = new TemplatesDbContext(options);
            var totalActive = await verificationContext.TemplateGenerationProviderAttempts.CountAsync(
                attempt => ActiveStates.Contains(attempt.State));
            var ownActive = await verificationContext.TemplateGenerationProviderAttempts.CountAsync(
                attempt => jobIds.Contains(attempt.GenerationJobId)
                    && ActiveStates.Contains(attempt.State));
            Assert.Equal(testCapacity, ownActive);
            Assert.True(
                totalActive <= effectiveGlobal,
                $"Active provider attempts {totalActive} exceeded effective capacity {effectiveGlobal}.");
        }
        finally
        {
            await CleanupAsync(options, templateId, jobIds);
        }
    }

    [Fact]
    public async Task FiftyUsersAndTwoHundredMixedJobs_ShouldUseRealDurableCapacityWithoutDuplicateAttemptsOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        Assert.True(
            await HasIsolatedProviderCapacityAsync(options),
            "PostgreSQL load acceptance requires an isolated database without active provider attempts.");

        var fixture = await SeedMixedLoadAsync(options, imageJobs: 150, videoJobs: 50);
        var policy = CreateRuntimePolicy(confirmedFalLimit: 40);
        var pending = new HashSet<ProviderStageWork>(
            fixture.ImageJobIds.Select(id => new ProviderStageWork(
                    id,
                    TemplateGenerationProviderAttemptStage.ImageGeneration))
                .Concat(fixture.VideoJobIds.Select(id => new ProviderStageWork(
                    id,
                    TemplateGenerationProviderAttemptStage.VideoPreprocessing))));
        var completed = new HashSet<ProviderStageWork>();
        var attemptStages = new Dictionary<Guid, ProviderStageWork>();
        var maxActive = 0;
        var safetyIterations = 0;

        try
        {
            while (pending.Count > 0)
            {
                Assert.True(++safetyIterations < 100, "Durable load acceptance did not converge.");
                var reserved = await ReserveConcurrentlyAsync(options, policy, pending);
                Assert.NotEmpty(reserved);

                foreach (var (work, attemptId) in reserved)
                {
                    Assert.True(pending.Remove(work));
                    Assert.True(attemptStages.TryAdd(attemptId, work));
                }

                if (completed.Count == 0)
                {
                    var first = reserved.First();
                    var duplicateReservations = await ReserveSameStageConcurrentlyAsync(
                        options,
                        policy,
                        first.Key,
                        count: 4);
                    Assert.All(duplicateReservations, attempt =>
                        Assert.Equal(first.Value, attempt?.Id));
                }

                await using (var verificationContext = new TemplatesDbContext(options))
                {
                    var activeCount = await verificationContext.TemplateGenerationProviderAttempts.CountAsync(
                        attempt => fixture.AllJobIds.Contains(attempt.GenerationJobId)
                            && ActiveStates.Contains(attempt.State));
                    maxActive = Math.Max(maxActive, activeCount);
                    Assert.True(activeCount <= 38, $"Active durable attempts {activeCount} exceeded 38.");
                }

                foreach (var (work, attemptId) in reserved)
                {
                    await AcceptSubmissionAsync(options, policy, attemptId);
                }

                for (var completedInWave = 0; completedInWave < reserved.Count; completedInWave++)
                {
                    var claim = await CompleteNextDueAttemptAsync(options, policy);
                    Assert.NotNull(claim);
                    Assert.True(attemptStages.TryGetValue(claim.AttemptId, out var work));
                    Assert.True(completed.Add(work));
                    if (work.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing)
                    {
                        Assert.True(pending.Add(new ProviderStageWork(
                            work.JobId,
                            TemplateGenerationProviderAttemptStage.VideoGeneration)));
                    }
                }
            }

            Assert.Equal(38, maxActive);
            Assert.Equal(250, completed.Count);
            Assert.Equal(50, fixture.UserIds.Length);

            await using var finalContext = new TemplatesDbContext(options);
            var attempts = await finalContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(attempt => fixture.AllJobIds.Contains(attempt.GenerationJobId))
                .ToArrayAsync();
            Assert.Equal(250, attempts.Length);
            Assert.All(attempts, attempt =>
                Assert.Equal(TemplateGenerationProviderAttemptState.Completed, attempt.State));
            Assert.DoesNotContain(
                attempts.GroupBy(attempt => new { attempt.GenerationJobId, attempt.Stage }),
                group => group.Count() != 1);
        }
        finally
        {
            await CleanupMixedLoadAsync(options, fixture);
        }
    }

    [Fact]
    public async Task ImageBacklog_ShouldLeaveTwoRealDurableSlotsForVideoAtEffectiveGlobalEightOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        Assert.True(
            await HasIsolatedProviderCapacityAsync(options),
            "PostgreSQL video-reserve acceptance requires an isolated database without active provider attempts.");

        var fixture = await SeedMixedLoadAsync(options, imageJobs: 20, videoJobs: 20);
        var policy = CreateRuntimePolicy(confirmedFalLimit: 10);
        try
        {
            var imageWork = fixture.ImageJobIds.Select(id => new ProviderStageWork(
                id,
                TemplateGenerationProviderAttemptStage.ImageGeneration));
            var reservedImages = await ReserveConcurrentlyAsync(options, policy, imageWork);
            Assert.Equal(6, reservedImages.Count);

            var preprocessing = new ProviderStageWork(
                fixture.VideoJobIds[0],
                TemplateGenerationProviderAttemptStage.VideoPreprocessing);
            var motion = new ProviderStageWork(
                fixture.VideoJobIds[1],
                TemplateGenerationProviderAttemptStage.VideoGeneration);
            var reservedVideos = await ReserveConcurrentlyAsync(options, policy, [preprocessing, motion]);
            Assert.Equal(2, reservedVideos.Count);

            var duplicateReservations = await ReserveSameStageConcurrentlyAsync(
                options,
                policy,
                reservedImages.First().Key,
                count: 4);
            Assert.All(duplicateReservations, attempt =>
                Assert.Equal(reservedImages.First().Value, attempt?.Id));

            await using var verificationContext = new TemplatesDbContext(options);
            var activeAttempts = await verificationContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(attempt => fixture.AllJobIds.Contains(attempt.GenerationJobId)
                    && ActiveStates.Contains(attempt.State))
                .ToArrayAsync();
            Assert.Equal(8, activeAttempts.Length);
            Assert.Equal(
                6,
                activeAttempts.Count(attempt =>
                    attempt.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration));
            Assert.Equal(
                2,
                activeAttempts.Count(attempt =>
                    attempt.Stage is TemplateGenerationProviderAttemptStage.VideoPreprocessing
                        or TemplateGenerationProviderAttemptStage.VideoGeneration));
            Assert.Single(activeAttempts, attempt =>
                attempt.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing);
        }
        finally
        {
            await CleanupMixedLoadAsync(options, fixture);
        }
    }

    [Fact]
    public async Task ClaimedVideoWithoutAttempt_ShouldStillProtectGuaranteedCapacityOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        Assert.True(
            await HasIsolatedProviderCapacityAsync(options),
            "PostgreSQL claimed-video reserve acceptance requires an isolated database without active provider attempts.");

        var fixture = await SeedMixedLoadAsync(options, imageJobs: 7, videoJobs: 1);
        var policy = CreateRuntimePolicy(confirmedFalLimit: 10);
        try
        {
            await using (var claimContext = new TemplatesDbContext(options))
            {
                var claimedVideo = await claimContext.TemplateGenerationJobs
                    .SingleAsync(job => job.Id == fixture.VideoJobIds[0]);
                claimedVideo.Status = TemplateGenerationStatus.Processing;
                claimedVideo.LockedAtUtc = DateTime.UtcNow;
                claimedVideo.LockedBy = "scheduler-v2-video-dispatch";
                await claimContext.SaveChangesAsync();
            }

            var imageWork = fixture.ImageJobIds.Select(id => new ProviderStageWork(
                id,
                TemplateGenerationProviderAttemptStage.ImageGeneration));
            var reservedImages = await ReserveConcurrentlyAsync(options, policy, imageWork);

            Assert.Equal(6, reservedImages.Count);

            await using var videoContext = new TemplatesDbContext(options);
            var videoAttempt = await CreateAttemptStore(videoContext, policy).TryReserveAsync(
                CreateReservation(
                    fixture.VideoJobIds[0],
                    TemplateGenerationProviderAttemptStage.VideoPreprocessing,
                    $"{fixture.VideoJobIds[0]:N}:claimed-video"),
                CancellationToken.None);
            Assert.NotNull(videoAttempt);

            await using var verificationContext = new TemplatesDbContext(options);
            var activeAttempts = await verificationContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(attempt => fixture.AllJobIds.Contains(attempt.GenerationJobId)
                    && ActiveStates.Contains(attempt.State))
                .ToArrayAsync();
            Assert.Equal(7, activeAttempts.Length);
            Assert.Equal(
                6,
                activeAttempts.Count(attempt =>
                    attempt.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration));
            Assert.Single(activeAttempts, attempt =>
                attempt.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing);
        }
        finally
        {
            await CleanupMixedLoadAsync(options, fixture);
        }
    }

    [Fact]
    public async Task ConcurrentVideoPreprocessingReservations_ShouldRespectStageMaximumOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        Assert.True(
            await HasIsolatedProviderCapacityAsync(options),
            "PostgreSQL preprocessing-limit acceptance requires an isolated database without active provider attempts.");

        var fixture = await SeedMixedLoadAsync(options, imageJobs: 0, videoJobs: 8);
        var policy = CreateRuntimePolicy(confirmedFalLimit: 10);
        try
        {
            var preprocessingWork = fixture.VideoJobIds.Select(id => new ProviderStageWork(
                id,
                TemplateGenerationProviderAttemptStage.VideoPreprocessing));
            var reserved = await ReserveConcurrentlyAsync(options, policy, preprocessingWork);

            Assert.Single(reserved);

            await using var verificationContext = new TemplatesDbContext(options);
            var activePreprocessing = await verificationContext.TemplateGenerationProviderAttempts.CountAsync(
                attempt => fixture.VideoJobIds.Contains(attempt.GenerationJobId)
                    && ActiveStates.Contains(attempt.State)
                    && attempt.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing);
            Assert.Equal(1, activePreprocessing);
        }
        finally
        {
            await CleanupMixedLoadAsync(options, fixture);
        }
    }

    [Fact]
    public async Task ClaimedImageWithoutAttempt_ShouldStillProtectImageCapacityOnPostgres()
    {
        var options = TryCreatePostgresOptions();
        if (options is null)
        {
            return;
        }

        Assert.True(
            await HasIsolatedProviderCapacityAsync(options),
            "PostgreSQL claimed-image reserve acceptance requires an isolated database without active provider attempts.");

        var fixture = await SeedMixedLoadAsync(options, imageJobs: 1, videoJobs: 4);
        var profile = new TemplateGenerationConcurrencyProfile(
            GlobalMaxConcurrentGenerations: 8,
            ImageReservedConcurrentGenerations: 5,
            ImageProtectedConcurrentGenerations: 5,
            ImageMaxConcurrentGenerations: 7,
            VideoReservedConcurrentGenerations: 2,
            VideoMaxConcurrentGenerations: 4,
            VideoBorrowMaxConcurrentGenerations: 2,
            VideoPreprocessingMaxConcurrentGenerations: 1);
        var policy = new TemplateGenerationRuntimePolicySnapshot(
            Revision: 1,
            AdmissionEnabled: true,
            ConfirmedFalConcurrencyLimit: 10,
            ConfirmedAtUtc: DateTime.UtcNow,
            ReservedHeadroom: 2,
            ApplicationHardCeiling: 8,
            BaseProfile: profile,
            EffectiveProfile: profile);
        try
        {
            await using (var claimContext = new TemplatesDbContext(options))
            {
                var claimedImage = await claimContext.TemplateGenerationJobs
                    .SingleAsync(job => job.Id == fixture.ImageJobIds[0]);
                claimedImage.Status = TemplateGenerationStatus.Processing;
                claimedImage.LockedAtUtc = DateTime.UtcNow;
                claimedImage.LockedBy = "scheduler-v2-image-dispatch";
                await claimContext.SaveChangesAsync();
            }

            var motionWork = fixture.VideoJobIds.Select(id => new ProviderStageWork(
                id,
                TemplateGenerationProviderAttemptStage.VideoGeneration));
            var reservedVideos = await ReserveConcurrentlyAsync(options, policy, motionWork);

            Assert.Equal(3, reservedVideos.Count);

            await using var verificationContext = new TemplatesDbContext(options);
            var activeVideos = await verificationContext.TemplateGenerationProviderAttempts.CountAsync(
                attempt => fixture.VideoJobIds.Contains(attempt.GenerationJobId)
                    && ActiveStates.Contains(attempt.State)
                    && attempt.Stage == TemplateGenerationProviderAttemptStage.VideoGeneration);
            Assert.Equal(3, activeVideos);
        }
        finally
        {
            await CleanupMixedLoadAsync(options, fixture);
        }
    }

    private static DbContextOptions<TemplatesDbContext>? TryCreatePostgresOptions()
    {
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString)
            ? null
            : new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql(connectionString)
                .Options;
    }

    private static async Task<bool> HasIsolatedProviderCapacityAsync(
        DbContextOptions<TemplatesDbContext> options)
    {
        await using var dbContext = new TemplatesDbContext(options);
        return !await dbContext.TemplateGenerationProviderAttempts.AnyAsync(attempt =>
            ActiveStates.Contains(attempt.State));
    }

    private static TemplateGenerationRuntimePolicySnapshot CreateRuntimePolicy(int confirmedFalLimit)
    {
        var policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);
        policy.AdmissionEnabled = true;
        policy.ConfirmedFalConcurrencyLimit = confirmedFalLimit;
        return TemplateGenerationRuntimePolicyCalculator.Calculate(policy);
    }

    private static async Task<Dictionary<ProviderStageWork, Guid>> ReserveConcurrentlyAsync(
        DbContextOptions<TemplatesDbContext> options,
        TemplateGenerationRuntimePolicySnapshot policy,
        IEnumerable<ProviderStageWork> pending)
    {
        var reserved = new ConcurrentDictionary<ProviderStageWork, Guid>();
        await Parallel.ForEachAsync(
            pending,
            new ParallelOptions { MaxDegreeOfParallelism = 4 },
            async (work, cancellationToken) =>
            {
                await using var workerContext = new TemplatesDbContext(options);
                var store = CreateAttemptStore(workerContext, policy);
                var attempt = await store.TryReserveAsync(
                    CreateReservation(work.JobId, work.Stage, $"{work.JobId:N}:{work.Stage}"),
                    cancellationToken);
                if (attempt is not null)
                {
                    reserved.TryAdd(work, attempt.Id);
                }
            });
        return reserved.ToDictionary();
    }

    private static async Task<TemplateGenerationProviderAttempt?[]> ReserveSameStageConcurrentlyAsync(
        DbContextOptions<TemplatesDbContext> options,
        TemplateGenerationRuntimePolicySnapshot policy,
        ProviderStageWork work,
        int count)
    {
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks = Enumerable.Range(0, count).Select(async _ =>
        {
            await using var workerContext = new TemplatesDbContext(options);
            var store = CreateAttemptStore(workerContext, policy);
            await start.Task;
            return await store.TryReserveAsync(
                CreateReservation(work.JobId, work.Stage, $"{work.JobId:N}:{work.Stage}"),
                CancellationToken.None);
        }).ToArray();
        start.TrySetResult();
        return await Task.WhenAll(tasks);
    }

    private static async Task AcceptSubmissionAsync(
        DbContextOptions<TemplatesDbContext> options,
        TemplateGenerationRuntimePolicySnapshot policy,
        Guid attemptId)
    {
        await using var workerContext = new TemplatesDbContext(options);
        var store = CreateAttemptStore(workerContext, policy);
        await store.MarkSubmissionAcceptedAsync(
            attemptId,
            $"fake-load-{attemptId:N}",
            statusUrl: null,
            responseUrl: null,
            cancelUrl: null,
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);
    }

    private static async Task<TemplateGenerationProviderAttemptClaim?> CompleteNextDueAttemptAsync(
        DbContextOptions<TemplatesDbContext> options,
        TemplateGenerationRuntimePolicySnapshot policy)
    {
        await using var workerContext = new TemplatesDbContext(options);
        var store = CreateAttemptStore(workerContext, policy);
        var claim = await store.ClaimDueAsync(
            "scheduler-v2-load-acceptance",
            TimeSpan.FromSeconds(90),
            CancellationToken.None);
        if (claim is not null)
        {
            await store.UpdateClaimedStateAsync(
                claim.AttemptId,
                claim.ClaimToken,
                TemplateGenerationProviderAttemptState.Completed,
                nextPollAtUtc: null,
                lastErrorCode: null,
                providerCompleted: true,
                CancellationToken.None);
        }

        return claim;
    }

    private static TemplateGenerationProviderAttemptStore CreateAttemptStore(
        TemplatesDbContext dbContext,
        TemplateGenerationRuntimePolicySnapshot policy) => new(
            dbContext,
            new StaticRuntimePolicyProvider(policy),
            new StaticRuntimeSnapshotService(CreateFreshBalanceSnapshot()),
            CreateStoreOptions());

    private static TemplatesOptions CreateStoreOptions() => new()
    {
        PublicBaseUrl = "https://api.example.test",
        LocalMediaRootPath = "wwwroot/templates-media",
        DefaultImagePrompt = "Create a pet portrait.",
        DefaultPreprocessingPrompt = "Normalize the pet image.",
        DefaultKlingPrompt = "Animate the pet.",
        AllowedImageModels = ["fake-image-model"],
        AllowedPreprocessingModels = ["fake-preprocessing-model"],
        AllowedKlingModels = ["fake-motion-model"],
        SupportedLocalizationLocales = ["ru"]
    };

    private static async Task<Guid[]> SeedJobsAsync(
        TemplatesDbContext dbContext,
        Guid templateId,
        int count)
    {
        var now = DateTime.UtcNow;
        dbContext.TemplateItems.Add(new TemplateItem
        {
            Id = templateId,
            Version = 1,
            TemplateType = TemplateType.Image,
            Title = $"Scheduler V2 concurrency {templateId:N}",
            ShortDescription = "PostgreSQL provider capacity fixture.",
            Category = "Concurrency",
            Tags = "scheduler-v2,concurrency",
            TokenCost = 20,
            Status = TemplateStatus.Active,
            ImageModel = "fake-image-model",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            PublishedAtUtc = now,
            UpdatedAtUtc = now
        });
        var jobs = Enumerable.Range(0, count)
            .Select(_ => new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Processing,
                QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = "https://cdn.example.test/source.jpg",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now
            })
            .ToArray();
        dbContext.TemplateGenerationJobs.AddRange(jobs);
        await dbContext.SaveChangesAsync();
        return jobs.Select(job => job.Id).ToArray();
    }

    private static TemplateGenerationProviderAttemptReservation CreateReservation(
        Guid jobId,
        string tokenMaterial)
    {
        return CreateReservation(
            jobId,
            TemplateGenerationProviderAttemptStage.ImageGeneration,
            tokenMaterial);
    }

    private static TemplateGenerationProviderAttemptReservation CreateReservation(
        Guid jobId,
        TemplateGenerationProviderAttemptStage stage,
        string tokenMaterial)
    {
        var now = DateTime.UtcNow;
        var tokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(tokenMaterial)));
        return new TemplateGenerationProviderAttemptReservation(
            jobId,
            stage,
            "fal",
            tokenHash,
            now.AddMinutes(3),
            now.AddMinutes(30),
            now.AddMinutes(40));
    }

    private static async Task<MixedLoadFixture> SeedMixedLoadAsync(
        DbContextOptions<TemplatesDbContext> options,
        int imageJobs,
        int videoJobs)
    {
        await using var dbContext = new TemplatesDbContext(options);
        var now = DateTime.UtcNow;
        var imageTemplate = new TemplateItem
        {
            Id = Guid.NewGuid(),
            Version = 1,
            TemplateType = TemplateType.Image,
            Title = $"Scheduler V2 image load {Guid.NewGuid():N}",
            ShortDescription = "PostgreSQL image load acceptance fixture.",
            Category = "Concurrency",
            Tags = "scheduler-v2,load",
            TokenCost = 20,
            Status = TemplateStatus.Active,
            ImageModel = "fake-image-model",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            PublishedAtUtc = now,
            UpdatedAtUtc = now
        };
        var videoTemplate = new TemplateItem
        {
            Id = Guid.NewGuid(),
            Version = 1,
            TemplateType = TemplateType.Video,
            Title = $"Scheduler V2 video load {Guid.NewGuid():N}",
            ShortDescription = "PostgreSQL video load acceptance fixture.",
            Category = "Concurrency",
            Tags = "scheduler-v2,load",
            TokenCost = 30,
            Status = TemplateStatus.Active,
            PreprocessingModel = "fake-preprocessing-model",
            PreprocessingPrompt = "Normalize the source pet.",
            KlingModel = "fake-motion-model",
            KlingPrompt = "Animate the pet.",
            CreatedAtUtc = now,
            PublishedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateItems.AddRange(imageTemplate, videoTemplate);

        var userIds = Enumerable.Range(0, 50).Select(_ => Guid.NewGuid()).ToArray();
        var imageRows = Enumerable.Range(0, imageJobs)
            .Select(index => CreateLoadJob(
                userIds[index % userIds.Length],
                imageTemplate.Id,
                TemplateGenerationQueue.MediaTypeImage,
                now.AddMilliseconds(index)))
            .ToArray();
        var videoRows = Enumerable.Range(0, videoJobs)
            .Select(index => CreateLoadJob(
                userIds[(imageJobs + index) % userIds.Length],
                videoTemplate.Id,
                TemplateGenerationQueue.MediaTypeVideo,
                now.AddMilliseconds(imageJobs + index)))
            .ToArray();
        dbContext.TemplateGenerationJobs.AddRange(imageRows);
        dbContext.TemplateGenerationJobs.AddRange(videoRows);
        await dbContext.SaveChangesAsync();

        return new MixedLoadFixture(
            [imageTemplate.Id, videoTemplate.Id],
            imageRows.Select(job => job.Id).ToArray(),
            videoRows.Select(job => job.Id).ToArray(),
            userIds);
    }

    private static TemplateGenerationJob CreateLoadJob(
        Guid userId,
        Guid templateId,
        string mediaType,
        DateTime queuedAtUtc) => new()
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = templateId,
            Status = TemplateGenerationStatus.Queued,
            QueueMediaType = mediaType,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.test/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = queuedAtUtc,
            QueuedAtUtc = queuedAtUtc,
            UpdatedAtUtc = queuedAtUtc
        };

    private static TemplateProviderRuntimeSnapshot CreateFreshBalanceSnapshot()
    {
        var now = DateTime.UtcNow;
        return new TemplateProviderRuntimeSnapshot
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Fresh,
            StatusChangedAtUtc = now,
            CurrentBalanceUsd = 20m,
            LastSuccessfulAtUtc = now,
            CheckedAtUtc = now,
            UpdatedAtUtc = now
        };
    }

    private static async Task CleanupAsync(
        DbContextOptions<TemplatesDbContext>? options,
        Guid templateId,
        IReadOnlyCollection<Guid> jobIds)
    {
        if (options is null)
        {
            return;
        }

        await using var dbContext = new TemplatesDbContext(options);
        if (jobIds.Count > 0)
        {
            await dbContext.TemplateProviderWebhookInbox
                .Where(inbox => inbox.GenerationJobId != null && jobIds.Contains(inbox.GenerationJobId.Value))
                .ExecuteDeleteAsync();
            await dbContext.TemplateGenerationProviderAttempts
                .Where(attempt => jobIds.Contains(attempt.GenerationJobId))
                .ExecuteDeleteAsync();
            await dbContext.TemplateGenerationJobs
                .Where(job => jobIds.Contains(job.Id))
                .ExecuteDeleteAsync();
        }

        await dbContext.TemplateItems
            .Where(template => template.Id == templateId)
            .ExecuteDeleteAsync();
    }

    private static async Task CleanupMixedLoadAsync(
        DbContextOptions<TemplatesDbContext> options,
        MixedLoadFixture fixture)
    {
        await using var dbContext = new TemplatesDbContext(options);
        await dbContext.TemplateProviderWebhookInbox
            .Where(inbox => inbox.GenerationJobId != null
                && fixture.AllJobIds.Contains(inbox.GenerationJobId.Value))
            .ExecuteDeleteAsync();
        await dbContext.TemplateGenerationProviderAttempts
            .Where(attempt => fixture.AllJobIds.Contains(attempt.GenerationJobId))
            .ExecuteDeleteAsync();
        await dbContext.TemplateGenerationJobs
            .Where(job => fixture.AllJobIds.Contains(job.Id))
            .ExecuteDeleteAsync();
        await dbContext.TemplateItems
            .Where(template => fixture.TemplateIds.Contains(template.Id))
            .ExecuteDeleteAsync();
    }

    private sealed record ProviderStageWork(
        Guid JobId,
        TemplateGenerationProviderAttemptStage Stage);

    private sealed record MixedLoadFixture(
        Guid[] TemplateIds,
        Guid[] ImageJobIds,
        Guid[] VideoJobIds,
        Guid[] UserIds)
    {
        public Guid[] AllJobIds { get; } = [.. ImageJobIds, .. VideoJobIds];
    }

    private sealed class StaticRuntimePolicyProvider(TemplateGenerationRuntimePolicySnapshot policy)
        : ITemplateGenerationRuntimePolicyProvider
    {
        public Task<TemplateGenerationRuntimePolicySnapshot> GetRuntimePolicyAsync(
            CancellationToken cancellationToken) => Task.FromResult(policy);
    }

    private sealed class StaticRuntimeSnapshotService(TemplateProviderRuntimeSnapshot snapshot)
        : IFalProviderRuntimeSnapshotService
    {
        public Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken) =>
            Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(snapshot);
    }
}
