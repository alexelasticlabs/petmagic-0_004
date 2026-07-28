using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminGenerationRenderControlServiceTests
{
    [Fact]
    public async Task RequestScaleAsync_WhenCancelledDrainCleanupIsPending_ShouldRejectWithoutInsertOrAudit()
    {
        await using var fixture = await CancelFixture.CreateAsync();
        var cancelResult = await fixture.Service.CancelOperationAsync(
            fixture.ActorUserId,
            fixture.OperationId,
            "Operator cancelled scale review",
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);
        Assert.True(cancelResult.IsSuccess);
        Assert.Equal(AdminGenerationRenderControlService.StatusCancelled, cancelResult.Value.Status);

        var operationCountBeforeRequest = await fixture.DbContext.TemplateRenderScaleOperations.CountAsync();
        var auditCountBeforeRequest = await fixture.DbContext.PushOutboxMessages
            .CountAsync(item => item.Kind == TemplateAdminAuditOutbox.Kind);

        var result = await fixture.Service.RequestScaleAsync(
            Guid.NewGuid(),
            Guid.NewGuid().ToString("N"),
            new AdminRenderScaleCommand(
                TargetInstances: 4,
                ExpectedCurrentInstances: 1,
                Reason: "Retry scale before drain cleanup",
                Confirmed: true),
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(AdminGenerationRenderControlErrors.OperationInProgress.Code, result.Error.Code);
        Assert.Equal(operationCountBeforeRequest, await fixture.DbContext.TemplateRenderScaleOperations.CountAsync());
        Assert.Equal(
            auditCountBeforeRequest,
            await fixture.DbContext.PushOutboxMessages
                .CountAsync(item => item.Kind == TemplateAdminAuditOutbox.Kind));
        Assert.False(await fixture.DbContext.TemplateRenderScaleOperations
            .AnyAsync(item => item.Status == AdminGenerationRenderControlService.StatusRequested));
    }

    [Fact]
    public async Task RequestScaleAsync_WhenCancelledCleanupIsPendingBeforeDrainPause_ShouldReject()
    {
        await using var fixture = await CancelFixture.CreateAsync();
        var cancelResult = await fixture.Service.CancelOperationAsync(
            fixture.ActorUserId,
            fixture.OperationId,
            "Operator cancelled before drain pause",
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);
        Assert.True(cancelResult.IsSuccess);
        await fixture.DbContext.TemplateGenerationRuntimeSettings
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(item => item.NewClaimsPaused, false)
                .SetProperty(item => item.DrainOperationId, (Guid?)null));

        var result = await fixture.Service.RequestScaleAsync(
            Guid.NewGuid(),
            Guid.NewGuid().ToString("N"),
            new AdminRenderScaleCommand(4, 1, "Retry before cleanup completes", true),
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(AdminGenerationRenderControlErrors.OperationInProgress.Code, result.Error.Code);
        Assert.Single(await fixture.DbContext.TemplateRenderScaleOperations.ToArrayAsync());
    }

    [Fact]
    public async Task RequestScaleAsync_WhenExpectedCurrentInstancesIsMissing_ShouldReject()
    {
        await using var fixture = await CancelFixture.CreateAsync();

        var result = await fixture.Service.RequestScaleAsync(
            Guid.NewGuid(),
            Guid.NewGuid().ToString("N"),
            new AdminRenderScaleCommand(4, null, "Missing topology baseline", true),
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(AdminGenerationRenderControlErrors.InvalidRequest.Code, result.Error.Code);
    }

    [Fact]
    public async Task CancelOperationAsync_WhenProcessorAdvancesOperationConcurrently_ShouldReturnConflict()
    {
        await using var fixture = await CancelFixture.CreateAsync();
        fixture.Interceptor.AdvanceToScaling(fixture.OperationId);

        var result = await fixture.Service.CancelOperationAsync(
            fixture.ActorUserId,
            fixture.OperationId,
            "Operator cancelled scale review",
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(AdminGenerationRenderControlErrors.CancellationNotAllowed.Code, result.Error.Code);

        var operation = await fixture.DbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .SingleAsync(item => item.Id == fixture.OperationId);
        Assert.Equal(AdminGenerationRenderControlService.StatusScaling, operation.Status);
        Assert.Null(operation.CancelledAtUtc);
    }

    [Fact]
    public async Task CancelOperationAsync_WhenOperationIsDeletedConcurrently_ShouldReturnNotFound()
    {
        await using var fixture = await CancelFixture.CreateAsync();
        fixture.Interceptor.Delete(fixture.OperationId);

        var result = await fixture.Service.CancelOperationAsync(
            fixture.ActorUserId,
            fixture.OperationId,
            "Operator cancelled scale review",
            Guid.NewGuid().ToString("N"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(AdminGenerationRenderControlErrors.OperationNotFound.Code, result.Error.Code);
        Assert.False(await fixture.DbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .AnyAsync(item => item.Id == fixture.OperationId));
    }

    private sealed class CancelFixture : IAsyncDisposable
    {
        private CancelFixture(
            SqliteConnection anchorConnection,
            TemplatesDbContext dbContext,
            ConcurrentOperationMutationInterceptor interceptor,
            Guid actorUserId,
            Guid operationId)
        {
            AnchorConnection = anchorConnection;
            DbContext = dbContext;
            Interceptor = interceptor;
            ActorUserId = actorUserId;
            OperationId = operationId;
            Service = new AdminGenerationRenderControlService(
                dbContext,
                new UnusedRenderClient(),
                new FixedRuntimeSettings());
        }

        private SqliteConnection AnchorConnection { get; }

        public TemplatesDbContext DbContext { get; }

        public ConcurrentOperationMutationInterceptor Interceptor { get; }

        public Guid ActorUserId { get; }

        public Guid OperationId { get; }

        public AdminGenerationRenderControlService Service { get; }

        public static async Task<CancelFixture> CreateAsync()
        {
            var connectionString = $"Data Source=render-cancel-{Guid.NewGuid():N};Mode=Memory;Cache=Shared";
            var anchorConnection = new SqliteConnection(connectionString);
            await anchorConnection.OpenAsync();

            var mutationOptions = new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseSqlite(connectionString)
                .Options;
            var interceptor = new ConcurrentOperationMutationInterceptor(mutationOptions);
            var serviceOptions = new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseSqlite(connectionString)
                .AddInterceptors(interceptor)
                .Options;
            var dbContext = new TemplatesDbContext(serviceOptions);
            await dbContext.Database.EnsureCreatedAsync();

            var now = DateTime.UtcNow;
            var actorUserId = Guid.NewGuid();
            var operation = new TemplateRenderScaleOperation
            {
                Id = Guid.NewGuid(),
                ActorUserId = actorUserId,
                IdempotencyKey = Guid.NewGuid().ToString("N"),
                RequestHash = Guid.NewGuid().ToString("N"),
                Status = AdminGenerationRenderControlService.StatusRequested,
                InitialInstances = 1,
                TargetInstances = 4,
                LoopsPerInstance = 2,
                Reason = "Increase generation capacity",
                CorrelationId = Guid.NewGuid().ToString("N"),
                NextAttemptAtUtc = now,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };
            dbContext.TemplateRenderScaleOperations.Add(operation);
            dbContext.TemplateGenerationRuntimeSettings.Add(new TemplateGenerationRuntimeSettings
            {
                Id = TemplateGenerationRuntimeSettingsProvider.SettingsId,
                Version = 2,
                GlobalMaxConcurrent = 8,
                ImageMaxConcurrent = 7,
                ImageProtectedConcurrent = 4,
                VideoGuaranteedConcurrent = 2,
                VideoMaxConcurrent = 4,
                VideoBorrowMaxConcurrent = 2,
                WorkerLoopsPerInstance = 2,
                FalConfiguredConcurrency = 10,
                FalReservedConcurrency = 2,
                FalBalanceLowThresholdUsd = 10m,
                FalBalanceCriticalThresholdUsd = 5m,
                NewClaimsPaused = true,
                DrainOperationId = operation.Id,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
            await dbContext.SaveChangesAsync();
            dbContext.ChangeTracker.Clear();

            return new CancelFixture(anchorConnection, dbContext, interceptor, actorUserId, operation.Id);
        }

        public async ValueTask DisposeAsync()
        {
            await DbContext.DisposeAsync();
            await AnchorConnection.DisposeAsync();
        }
    }

    private sealed class ConcurrentOperationMutationInterceptor(
        DbContextOptions<TemplatesDbContext> mutationOptions) : SaveChangesInterceptor
    {
        private Guid operationId;
        private Mutation mutation;
        private int applied;

        public void AdvanceToScaling(Guid id)
        {
            operationId = id;
            mutation = Mutation.AdvanceToScaling;
        }

        public void Delete(Guid id)
        {
            operationId = id;
            mutation = Mutation.Delete;
        }

        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (mutation == Mutation.None || Interlocked.Exchange(ref applied, 1) != 0)
            {
                return result;
            }

            await using var concurrentContext = new TemplatesDbContext(mutationOptions);
            if (mutation == Mutation.Delete)
            {
                await concurrentContext.TemplateRenderScaleOperations
                    .Where(item => item.Id == operationId)
                    .ExecuteDeleteAsync(cancellationToken);
            }
            else
            {
                await concurrentContext.TemplateRenderScaleOperations
                    .Where(item => item.Id == operationId)
                    .ExecuteUpdateAsync(
                        setters => setters
                            .SetProperty(item => item.Status, AdminGenerationRenderControlService.StatusScaling)
                            .SetProperty(item => item.Version, item => item.Version + 1)
                            .SetProperty(item => item.UpdatedAtUtc, DateTime.UtcNow),
                        cancellationToken);
            }

            return result;
        }

        private enum Mutation
        {
            None,
            AdvanceToScaling,
            Delete
        }
    }

    private sealed class UnusedRenderClient : IRenderGenerationWorkerClient
    {
        public bool IsConfigured => true;

        public Task<Result<RenderGenerationWorkerTargetStatus>> GetTargetStatusAsync(
            CancellationToken cancellationToken) => throw new NotSupportedException();

        public Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
            CancellationToken cancellationToken) => throw new NotSupportedException();

        public Task<Result<RenderScaleAccepted>> ScaleAsync(
            int targetInstances,
            CancellationToken cancellationToken) => throw new NotSupportedException();
    }

    private sealed class FixedRuntimeSettings : ITemplateGenerationRuntimeSettingsProvider
    {
        public TemplateGenerationRuntimeSnapshot Current { get; } = new(
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
            UpdatedAtUtc: DateTime.UtcNow);

        public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
