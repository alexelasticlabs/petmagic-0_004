using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class RenderGenerationWorkerMonitorTests
{
    [Fact]
    public async Task RefreshAsync_ShouldActivateAndResolveStableDriftAlert()
    {
        var services = new ServiceCollection();
        var dbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseInMemoryDatabase($"render-monitor-{Guid.NewGuid():N}")
                .Options);
        services.AddSingleton(dbContext);
        await using var serviceProvider = services.BuildServiceProvider();
        var client = new FakeRenderClient { DesiredInstances = 4, ObservedInstances = 1 };
        var monitor = new RenderGenerationWorkerMonitor(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            client,
            NullLogger<RenderGenerationWorkerMonitor>.Instance);

        await monitor.RefreshAsync(CancellationToken.None);

        var alert = await dbContext.TemplateGenerationOperationalAlerts.SingleAsync();
        Assert.Equal("render_instance_drift", alert.Code);
        Assert.Null(alert.ResolvedAtUtc);
        Assert.Contains("1 active", alert.Message, StringComparison.Ordinal);
        Assert.Contains("4 are desired", alert.Message, StringComparison.Ordinal);

        client.ObservedInstances = 4;
        await monitor.RefreshAsync(CancellationToken.None);

        dbContext.ChangeTracker.Clear();
        alert = await dbContext.TemplateGenerationOperationalAlerts.SingleAsync();
        Assert.NotNull(alert.ResolvedAtUtc);
    }

    [Fact]
    public async Task RefreshAsync_ShouldPreserveDriftUntilTopologyCanBeVerified()
    {
        var services = new ServiceCollection();
        var dbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseInMemoryDatabase($"render-monitor-{Guid.NewGuid():N}")
                .Options);
        services.AddSingleton(dbContext);
        await using var serviceProvider = services.BuildServiceProvider();
        var client = new FakeRenderClient { DesiredInstances = 4, ObservedInstances = 1 };
        var monitor = new RenderGenerationWorkerMonitor(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            client,
            NullLogger<RenderGenerationWorkerMonitor>.Instance);

        await monitor.RefreshAsync(CancellationToken.None);

        client.ObservedInstances = 4;
        client.Configured = false;
        await monitor.RefreshAsync(CancellationToken.None);
        dbContext.ChangeTracker.Clear();
        Assert.Null((await dbContext.TemplateGenerationOperationalAlerts.SingleAsync()).ResolvedAtUtc);

        client.Configured = true;
        dbContext.TemplateRenderScaleOperations.Add(new TemplateRenderScaleOperation
        {
            Id = Guid.NewGuid(),
            ActorUserId = Guid.NewGuid(),
            IdempotencyKey = Guid.NewGuid().ToString("N"),
            RequestHash = Guid.NewGuid().ToString("N"),
            Status = AdminGenerationRenderControlService.StatusRequested,
            TargetInstances = 4,
            LoopsPerInstance = 2,
            Reason = "monitor test",
            CorrelationId = Guid.NewGuid().ToString("N"),
            NextAttemptAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        await monitor.RefreshAsync(CancellationToken.None);
        dbContext.ChangeTracker.Clear();
        Assert.Null((await dbContext.TemplateGenerationOperationalAlerts.SingleAsync()).ResolvedAtUtc);
    }

    private sealed class FakeRenderClient : IRenderGenerationWorkerClient
    {
        public bool Configured { get; set; } = true;

        public bool IsConfigured => Configured;

        public int DesiredInstances { get; init; }

        public int ObservedInstances { get; set; }

        public Task<Result<RenderGenerationWorkerTargetStatus>> GetTargetStatusAsync(
            CancellationToken cancellationToken) => Task.FromResult(Result.Success(
                new RenderGenerationWorkerTargetStatus(
                    "srv-generation-worker",
                    "petmagic-production-generation-worker",
                    "background_worker",
                    "owner",
                    "https://github.com/alexelasticlabs/petmagic-0_004",
                    "standard",
                    "frankfurt",
                    DesiredInstances,
                    AutoscalingEnabled: false)));

        public Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
            CancellationToken cancellationToken) => Task.FromResult(Result.Success<IReadOnlyList<RenderGenerationWorkerInstance>>(
                Enumerable.Range(0, ObservedInstances)
                    .Select(index => new RenderGenerationWorkerInstance($"instance-{index}", DateTime.UtcNow))
                    .ToArray()));

        public Task<Result<RenderScaleAccepted>> ScaleAsync(
            int targetInstances,
            CancellationToken cancellationToken) => throw new InvalidOperationException("Monitor must be read-only.");
    }
}
