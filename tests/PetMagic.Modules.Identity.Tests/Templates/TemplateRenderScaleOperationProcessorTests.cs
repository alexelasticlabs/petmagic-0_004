using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateRenderScaleOperationProcessorTests
{
    [Fact]
    public async Task ProcessNextAsync_Upscale_PersistsOneStepAndVerifiesObservedInstances()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 1);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusRequested,
            targetInstances: 4,
            initialInstances: 1);
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        var afterValidation = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusScaling, afterValidation.Status);
        Assert.Equal(0, fixture.Render.ScaleCalls);

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        var afterScaleRequest = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusVerifying, afterScaleRequest.Status);
        Assert.Equal(1, fixture.Render.ScaleCalls);

        fixture.Clock.Advance(TimeSpan.FromSeconds(5));
        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        var completed = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusCompleted, completed.Status);
        Assert.NotNull(completed.CompletedAtUtc);
        Assert.Equal(4, fixture.Render.Instances.Count);
    }

    [Fact]
    public async Task ProcessNextAsync_Downscale_WaitsForEveryFreshWorkerToApplyDrain()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 2);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusRequested,
            targetInstances: 1,
            initialInstances: 2);
        fixture.DbContext.TemplateRuntimeConfigFingerprints.AddRange(
            CreateFingerprint(fixture.Clock.UtcNow, appliedVersion: 2, paused: true),
            CreateFingerprint(fixture.Clock.UtcNow, appliedVersion: 1, paused: false));
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        var draining = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusDraining, draining.Status);
        Assert.Equal(0, fixture.Runtime.PauseCalls);
        Assert.Null(draining.DrainRuntimeVersion);

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        draining = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(1, fixture.Runtime.PauseCalls);
        Assert.Equal(2, draining.DrainRuntimeVersion);

        fixture.Clock.Advance(TimeSpan.FromSeconds(5));
        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(
            AdminGenerationRenderControlService.StatusDraining,
            (await fixture.LoadOperationAsync(operation.Id)).Status);
        Assert.Equal(0, fixture.Render.ScaleCalls);

        await fixture.DbContext.TemplateRuntimeConfigFingerprints.ExecuteUpdateAsync(setters => setters
            .SetProperty(item => item.AppliedSettingsVersion, 2L)
            .SetProperty(item => item.NewClaimsPaused, true)
            .SetProperty(item => item.LastSeenAtUtc, fixture.Clock.UtcNow));
        fixture.Clock.Advance(TimeSpan.FromSeconds(5));

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(
            AdminGenerationRenderControlService.StatusScaling,
            (await fixture.LoadOperationAsync(operation.Id)).Status);
        Assert.Equal(0, fixture.Render.ScaleCalls);
    }

    [Fact]
    public async Task ProcessNextAsync_ScaleFailure_ResumesDrainAndPersistsAlertAndAudit()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 1);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusScaling,
            targetInstances: 4,
            initialInstances: 1);
        operation.DrainRuntimeVersion = 7;
        operation.DrainStartedAtUtc = fixture.Clock.UtcNow;
        operation.VerificationDeadlineAtUtc = fixture.Clock.UtcNow.AddMinutes(20);
        fixture.Runtime.SetPaused(operation.Id, version: 7);
        fixture.Render.ScaleFailure = RenderGenerationWorkerErrors.PermissionDenied;
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));

        var failed = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusFailed, failed.Status);
        Assert.Equal(RenderGenerationWorkerErrors.PermissionDenied.Code, failed.ErrorCode);
        Assert.Equal(1, fixture.Runtime.ResumeCalls);
        Assert.False(fixture.Runtime.Current.NewClaimsPaused);
        var alert = await fixture.DbContext.TemplateGenerationOperationalAlerts
            .AsNoTracking()
            .SingleAsync(item => item.Code == "render_scale_failed");
        Assert.Null(alert.ResolvedAtUtc);
        Assert.Contains(
            await fixture.DbContext.PushOutboxMessages.AsNoTracking().ToArrayAsync(),
            message => message.Kind == TemplateAdminAuditOutbox.Kind
                && message.PayloadJson.Contains("admin.templates.render_scale.failed", StringComparison.Ordinal));
    }

    [Fact]
    public async Task ProcessNextAsync_CancelledDownscale_ReleasesPersistedDrain()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 2);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusCancelled,
            targetInstances: 1,
            initialInstances: 2);
        operation.DrainRuntimeVersion = 5;
        operation.DrainStartedAtUtc = fixture.Clock.UtcNow;
        operation.CancelledAtUtc = fixture.Clock.UtcNow;
        fixture.Runtime.SetPaused(operation.Id, version: 5);
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));

        var cancelled = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusCancelled, cancelled.Status);
        Assert.Equal(1, fixture.Runtime.ResumeCalls);
        Assert.False(fixture.Runtime.Current.NewClaimsPaused);
        Assert.True(cancelled.NextAttemptAtUtc > fixture.Clock.UtcNow.AddYears(100));
    }

    [Fact]
    public async Task ProcessNextAsync_CancelledDownscale_ReleasesCrashWindowDrainWithoutPersistedVersion()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 2);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusCancelled,
            targetInstances: 1,
            initialInstances: 2);
        operation.DrainRuntimeVersion = null;
        operation.DrainStartedAtUtc = fixture.Clock.UtcNow;
        operation.CancelledAtUtc = fixture.Clock.UtcNow;
        fixture.Runtime.SetPaused(operation.Id, version: 5);
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));

        var cancelled = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusCancelled, cancelled.Status);
        Assert.Equal(1, fixture.Runtime.ResumeCalls);
        Assert.False(fixture.Runtime.Current.NewClaimsPaused);
        Assert.True(cancelled.NextAttemptAtUtc > fixture.Clock.UtcNow.AddYears(100));
    }

    [Fact]
    public async Task ProcessNextAsync_Requested_RetriesTransientTopologyFailure()
    {
        await using var fixture = await ProcessorFixture.CreateAsync(initialInstances: 1);
        var operation = fixture.AddOperation(
            AdminGenerationRenderControlService.StatusRequested,
            targetInstances: 4,
            initialInstances: 1);
        fixture.Render.TargetFailure = RenderGenerationWorkerErrors.UpstreamUnavailable("network_error");
        await fixture.DbContext.SaveChangesAsync();

        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));

        var retrying = await fixture.LoadOperationAsync(operation.Id);
        Assert.Equal(AdminGenerationRenderControlService.StatusRequested, retrying.Status);
        Assert.Equal(RenderGenerationWorkerErrors.UpstreamUnavailable("network_error").Code, retrying.ErrorCode);
        Assert.Equal(fixture.Clock.UtcNow.AddSeconds(5), retrying.NextAttemptAtUtc);
        Assert.Empty(await fixture.DbContext.TemplateGenerationOperationalAlerts.AsNoTracking().ToArrayAsync());

        fixture.Render.TargetFailure = null;
        fixture.Clock.Advance(TimeSpan.FromSeconds(5));
        Assert.True(await fixture.Processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(
            AdminGenerationRenderControlService.StatusScaling,
            (await fixture.LoadOperationAsync(operation.Id)).Status);
    }

    private static TemplateRuntimeConfigFingerprint CreateFingerprint(
        DateTime now,
        long appliedVersion,
        bool paused) => new()
    {
        Id = Guid.NewGuid(),
        Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
        ProfileName = "production",
        Checksum = Guid.NewGuid().ToString("N"),
        ConfigJson = "{}",
        StartedAtUtc = now.AddMinutes(-1),
        LastSeenAtUtc = now,
        AppliedSettingsVersion = appliedVersion,
        ConfiguredLoops = 2,
        NewClaimsPaused = paused
    };

    private sealed class ProcessorFixture : IAsyncDisposable
    {
        private ProcessorFixture(
            SqliteConnection connection,
            TemplatesDbContext dbContext,
            FakeRenderClient render,
            FakeRuntimeSettings runtime,
            ManualTimeProvider clock)
        {
            Connection = connection;
            DbContext = dbContext;
            Render = render;
            Runtime = runtime;
            Clock = clock;
            Processor = new TemplateRenderScaleOperationProcessor(
                dbContext,
                render,
                runtime,
                runtime,
                NullLogger<TemplateRenderScaleOperationProcessor>.Instance)
            {
                TimeProvider = clock
            };
        }

        public SqliteConnection Connection { get; }

        public TemplatesDbContext DbContext { get; }

        public FakeRenderClient Render { get; }

        public FakeRuntimeSettings Runtime { get; }

        public ManualTimeProvider Clock { get; }

        public TemplateRenderScaleOperationProcessor Processor { get; }

        public static async Task<ProcessorFixture> CreateAsync(int initialInstances)
        {
            var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            var options = new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseSqlite(connection)
                .Options;
            var dbContext = new TemplatesDbContext(options);
            await dbContext.Database.EnsureCreatedAsync();
            var clock = new ManualTimeProvider(new DateTimeOffset(2026, 7, 28, 12, 0, 0, TimeSpan.Zero));
            var runtime = new FakeRuntimeSettings(clock.UtcNow);
            var render = new FakeRenderClient(initialInstances, clock);
            return new ProcessorFixture(connection, dbContext, render, runtime, clock);
        }

        public TemplateRenderScaleOperation AddOperation(string status, int targetInstances, int? initialInstances)
        {
            var operation = new TemplateRenderScaleOperation
            {
                Id = Guid.NewGuid(),
                ActorUserId = Guid.NewGuid(),
                IdempotencyKey = Guid.NewGuid().ToString("N"),
                RequestHash = Guid.NewGuid().ToString("N"),
                Status = status,
                InitialInstances = initialInstances,
                TargetInstances = targetInstances,
                LoopsPerInstance = 2,
                Reason = "capacity test",
                CorrelationId = Guid.NewGuid().ToString("N"),
                NextAttemptAtUtc = Clock.UtcNow,
                CreatedAtUtc = Clock.UtcNow,
                UpdatedAtUtc = Clock.UtcNow
            };
            DbContext.TemplateRenderScaleOperations.Add(operation);
            return operation;
        }

        public async Task<TemplateRenderScaleOperation> LoadOperationAsync(Guid operationId)
        {
            DbContext.ChangeTracker.Clear();
            return await DbContext.TemplateRenderScaleOperations
                .AsNoTracking()
                .SingleAsync(item => item.Id == operationId);
        }

        public async ValueTask DisposeAsync()
        {
            await DbContext.DisposeAsync();
            await Connection.DisposeAsync();
        }
    }

    private sealed class FakeRenderClient(int initialInstances, ManualTimeProvider clock)
        : IRenderGenerationWorkerClient
    {
        public bool IsConfigured => true;

        public int ScaleCalls { get; private set; }

        public Error? ScaleFailure { get; set; }

        public Error? TargetFailure { get; set; }

        public int DesiredInstances { get; private set; } = initialInstances;

        public List<RenderGenerationWorkerInstance> Instances { get; } = Enumerable
            .Range(0, initialInstances)
            .Select(index => new RenderGenerationWorkerInstance($"instance-{index}", clock.UtcNow))
            .ToList();

        public Task<Result<RenderGenerationWorkerTargetStatus>> GetTargetStatusAsync(
            CancellationToken cancellationToken) => Task.FromResult(TargetFailure is null
                ? Result.Success(new RenderGenerationWorkerTargetStatus(
                    "srv-worker",
                    "petmagic-production-generation-worker",
                    "background_worker",
                    "owner",
                    "https://github.com/alexelasticlabs/petmagic-0_004",
                    "standard",
                    "frankfurt",
                    DesiredInstances,
                    AutoscalingEnabled: false))
                : Result.Failure<RenderGenerationWorkerTargetStatus>(TargetFailure));

        public Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
            CancellationToken cancellationToken) => Task.FromResult(
                Result.Success<IReadOnlyList<RenderGenerationWorkerInstance>>(Instances.ToArray()));

        public Task<Result<RenderScaleAccepted>> ScaleAsync(
            int targetInstances,
            CancellationToken cancellationToken)
        {
            ScaleCalls++;
            if (ScaleFailure is not null)
            {
                return Task.FromResult(Result.Failure<RenderScaleAccepted>(ScaleFailure));
            }

            DesiredInstances = targetInstances;
            Instances.Clear();
            Instances.AddRange(Enumerable
                .Range(0, targetInstances)
                .Select(index => new RenderGenerationWorkerInstance($"instance-{index}", clock.UtcNow)));
            return Task.FromResult(Result.Success(new RenderScaleAccepted(targetInstances, clock.UtcNow)));
        }
    }

    private sealed class FakeRuntimeSettings(DateTime now)
        : ITemplateGenerationRuntimeSettingsProvider, ITemplateGenerationDrainController
    {
        public TemplateGenerationRuntimeSnapshot Current { get; private set; } = CreateSnapshot(now);

        public int PauseCalls { get; private set; }

        public int ResumeCalls { get; private set; }

        public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public Task<bool> TryPauseNewClaimsAsync(Guid operationId, CancellationToken cancellationToken)
        {
            PauseCalls++;
            if (Current.NewClaimsPaused && Current.DrainOperationId != operationId)
            {
                return Task.FromResult(false);
            }

            Current = Current with
            {
                Version = Current.Version + 1,
                NewClaimsPaused = true,
                DrainOperationId = operationId
            };
            return Task.FromResult(true);
        }

        public Task<bool> TryResumeNewClaimsAsync(Guid operationId, CancellationToken cancellationToken)
        {
            ResumeCalls++;
            if (!Current.NewClaimsPaused || Current.DrainOperationId != operationId)
            {
                return Task.FromResult(false);
            }

            Current = Current with
            {
                Version = Current.Version + 1,
                NewClaimsPaused = false,
                DrainOperationId = null
            };
            return Task.FromResult(true);
        }

        public void SetPaused(Guid operationId, long version)
        {
            Current = Current with
            {
                Version = version,
                NewClaimsPaused = true,
                DrainOperationId = operationId
            };
        }

        private static TemplateGenerationRuntimeSnapshot CreateSnapshot(DateTime now) => new(
            Version: 1,
            GlobalMaxConcurrent: 8,
            ImageMaxConcurrent: 7,
            ImageProtectedConcurrent: 4,
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
            UpdatedAtUtc: now);
    }

    private sealed class ManualTimeProvider(DateTimeOffset now) : TimeProvider
    {
        private DateTimeOffset current = now;

        public DateTime UtcNow => current.UtcDateTime;

        public override DateTimeOffset GetUtcNow() => current;

        public void Advance(TimeSpan interval) => current = current.Add(interval);
    }
}
