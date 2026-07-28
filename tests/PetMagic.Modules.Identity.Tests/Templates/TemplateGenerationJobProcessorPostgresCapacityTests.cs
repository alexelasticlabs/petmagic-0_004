using System.Collections.Concurrent;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplateGenerationJobProcessorTests
{
    private const string PostgresSchedulerFixturePrefix = "https://scheduler.test/";

    [Fact]
    public async Task ProcessNextAsync_FourInstancesWithTwoLoops_ShouldRespectGlobalEightAndClaimEachJobOnce_OnPostgres()
    {
        var options = TryCreateGenerationSchedulerPostgresOptions();
        if (options is null)
        {
            return;
        }

        var imageTemplate = CreateReadyImageTemplate();
        var videoTemplate = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var jobs = Enumerable.Range(0, 11)
            .Select(index =>
            {
                var job = CreateGenerationJob(imageTemplate, TemplateGenerationStatus.Queued, now);
                job.CompletedAtUtc = null;
                job.QueuedAtUtc = now.AddMinutes(-30).AddSeconds(index);
                job.SourceImageUrl = $"{PostgresSchedulerFixturePrefix}{job.Id:N}.jpg";
                return job;
            })
            .ToList();
        var videoJob = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.Queued, now);
        videoJob.CompletedAtUtc = null;
        videoJob.QueuedAtUtc = now;
        videoJob.SourceImageUrl = $"{PostgresSchedulerFixturePrefix}{videoJob.Id:N}.jpg";
        jobs.Add(videoJob);

        var templateIds = new[] { imageTemplate.Id, videoTemplate.Id };
        var jobIds = jobs.Select(job => job.Id).ToArray();
        var contexts = new List<TemplatesDbContext>();
        var processingTasks = Array.Empty<Task<bool>>();
        var probe = new PostgresSchedulerConcurrencyProbe(expectedConcurrent: 8);

        try
        {
            await using (var seedContext = new TemplatesDbContext(options))
            {
                var staleFixtureTemplateIds = await seedContext.TemplateGenerationJobs
                    .Where(job => job.SourceImageUrl.StartsWith(PostgresSchedulerFixturePrefix))
                    .Select(job => job.TemplateId)
                    .Distinct()
                    .ToArrayAsync();
                if (staleFixtureTemplateIds.Length > 0)
                {
                    await seedContext.TemplateGenerationJobs
                        .Where(job => job.SourceImageUrl.StartsWith(PostgresSchedulerFixturePrefix))
                        .ExecuteDeleteAsync();
                    await seedContext.TemplateItems
                        .Where(template => staleFixtureTemplateIds.Contains(template.Id))
                        .ExecuteDeleteAsync();
                }

                var databaseIsBusy = await seedContext.TemplateGenerationJobs.AnyAsync(job =>
                        job.Status == TemplateGenerationStatus.Queued
                        || TemplateGenerationJobStatusSets.Processing.Contains(job.Status))
                    || await seedContext.TemplateGenerationBillingCommands.AnyAsync(command =>
                        command.Status == TemplateGenerationBillingCommandStatuses.Pending);
                if (databaseIsBusy)
                {
                    return;
                }

                seedContext.TemplateItems.AddRange(imageTemplate, videoTemplate);
                seedContext.TemplateGenerationJobs.AddRange(jobs);
                await seedContext.SaveChangesAsync();
            }

            var runtimeSettings = new FixedPostgresRuntimeSettingsProvider(new TemplateGenerationRuntimeSnapshot(
                Version: 1,
                GlobalMaxConcurrent: 8,
                ImageMaxConcurrent: 7,
                ImageProtectedConcurrent: 1,
                VideoGuaranteedConcurrent: 2,
                VideoMaxConcurrent: 4,
                VideoBorrowMaxConcurrent: 2,
                WorkerLoopsPerInstance: 2,
                FalConfiguredConcurrency: 10,
                FalReservedConcurrency: 2,
                FalBalanceLowThresholdUsd: 10m,
                FalBalanceCriticalThresholdUsd: 5m,
                NewClaimsPaused: false,
                DrainOperationId: null,
                UpdatedAtUtc: now));
            var imageGenerator = new PostgresConcurrencyImageGenerator(probe);
            var videoGenerator = new PostgresConcurrencyVideoGenerator(probe);

            contexts.AddRange(Enumerable.Range(0, 8).Select(_ => new TemplatesDbContext(options)));
            processingTasks = contexts
                .Select(context => CreateProcessor(
                        context,
                        imageGenerator: imageGenerator,
                        videoMotionGenerator: videoGenerator,
                        runtimeSettings: runtimeSettings)
                    .ProcessNextAsync(CancellationToken.None))
                .ToArray();

            await probe.ExpectedConcurrencyReached.Task.WaitAsync(TimeSpan.FromSeconds(20));

            await using (var ninthLoopContext = new TemplatesDbContext(options))
            {
                var ninthLoopProcessed = await CreateProcessor(
                        ninthLoopContext,
                        imageGenerator: imageGenerator,
                        videoMotionGenerator: videoGenerator,
                        runtimeSettings: runtimeSettings)
                    .ProcessNextAsync(CancellationToken.None)
                    .WaitAsync(TimeSpan.FromSeconds(10));

                Assert.False(ninthLoopProcessed);
            }

            Assert.Equal(8, probe.MaxConcurrent);
            Assert.Equal(8, probe.DistinctInputs.Count);
        }
        finally
        {
            probe.Release();
            if (processingTasks.Length > 0)
            {
                await Task.WhenAll(processingTasks).WaitAsync(TimeSpan.FromSeconds(20));
            }

            foreach (var context in contexts)
            {
                await context.DisposeAsync();
            }

            await using var verificationContext = new TemplatesDbContext(options);
            var persistedJobs = await verificationContext.TemplateGenerationJobs
                .Where(job => jobIds.Contains(job.Id))
                .Select(job => new { job.Status, job.AttemptCount })
                .ToArrayAsync();

            await verificationContext.TemplateGenerationJobs
                .Where(job => jobIds.Contains(job.Id))
                .ExecuteDeleteAsync();
            await verificationContext.TemplateItems
                .Where(template => templateIds.Contains(template.Id))
                .ExecuteDeleteAsync();

            if (persistedJobs.Length > 0)
            {
                // The shared no-op media fixtures intentionally reuse output URLs, so concurrent
                // post-claim completion may finish or fail on storage deduplication. This test's
                // boundary is the PostgreSQL scheduler claim and lease path. AttemptCount is the
                // durable claim marker and therefore the canonical assertion here.
                Assert.Equal(8, persistedJobs.Count(job => job.AttemptCount == 2));
                Assert.Equal(4, persistedJobs.Count(job => job.AttemptCount == 1));
                Assert.DoesNotContain(persistedJobs, job => job.AttemptCount > 2);
            }
        }
    }

    private static DbContextOptions<TemplatesDbContext>? TryCreateGenerationSchedulerPostgresOptions()
    {
        // This scheduler test must use a disposable database that is not connected to a running
        // API or worker. A dedicated variable prevents accidental claims from the developer DB.
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_SCHEDULER_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString)
            ? null
            : new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql(connectionString)
                .Options;
    }

    private sealed class FixedPostgresRuntimeSettingsProvider(TemplateGenerationRuntimeSnapshot current)
        : ITemplateGenerationRuntimeSettingsProvider
    {
        public TemplateGenerationRuntimeSnapshot Current { get; } = current;

        public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class PostgresSchedulerConcurrencyProbe(int expectedConcurrent)
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private int active;
        private int maxConcurrent;

        public ConcurrentDictionary<string, byte> DistinctInputs { get; } = new(StringComparer.Ordinal);

        public TaskCompletionSource ExpectedConcurrencyReached { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public int MaxConcurrent => Volatile.Read(ref maxConcurrent);

        public async Task EnterAsync(string input, CancellationToken cancellationToken)
        {
            DistinctInputs.TryAdd(input, 0);
            var current = Interlocked.Increment(ref active);
            UpdateMaxConcurrent(current);
            if (current >= expectedConcurrent)
            {
                ExpectedConcurrencyReached.TrySetResult();
            }

            try
            {
                await release.Task.WaitAsync(cancellationToken);
            }
            finally
            {
                Interlocked.Decrement(ref active);
            }
        }

        public void Release() => release.TrySetResult();

        private void UpdateMaxConcurrent(int current)
        {
            while (true)
            {
                var observed = Volatile.Read(ref maxConcurrent);
                if (current <= observed || Interlocked.CompareExchange(ref maxConcurrent, current, observed) == observed)
                {
                    return;
                }
            }
        }
    }

    private sealed class PostgresConcurrencyImageGenerator(PostgresSchedulerConcurrencyProbe probe) : IImageGenerator
    {
        public async Task<Result<ImageGenerationResult>> CreateAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            await probe.EnterAsync(sourceImageUrl, cancellationToken);
            return Result.Success(new ImageGenerationResult(sourceImageUrl, null, null));
        }
    }

    private sealed class PostgresConcurrencyVideoGenerator(PostgresSchedulerConcurrencyProbe probe) : IVideoMotionGenerator
    {
        public async Task<Result<VideoMotionGenerationResult>> CreateAsync(
            string normalizedImageUrl,
            string referenceVideoUrl,
            string characterOrientation,
            bool keepOriginalSound,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            await probe.EnterAsync(normalizedImageUrl, cancellationToken);
            return Result.Success(new VideoMotionGenerationResult(referenceVideoUrl, null, null));
        }
    }
}
