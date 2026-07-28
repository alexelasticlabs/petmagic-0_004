using System.Text.Json;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminGenerationControlServiceTests
{
    [Fact]
    public async Task UpdateAsync_WithCurrentVersion_ShouldPersistTargetProfileAndDurableAudit()
    {
        await using var fixture = await ControlFixture.CreateAsync();
        var actorUserId = Guid.NewGuid();
        var command = CreateTargetCommand(actorUserId) with
        {
            Reason = "  Approve production generation capacity  "
        };

        var result = await fixture.Service.UpdateAsync(command, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Settings.Version);
        Assert.Equal(8, result.Value.Settings.GlobalMaxConcurrent);
        Assert.Equal(7, result.Value.Settings.ImageMaxConcurrent);
        Assert.Equal(2, result.Value.Settings.VideoGuaranteedConcurrent);
        Assert.Equal(4, result.Value.Settings.VideoMaxConcurrent);
        Assert.Equal(2, result.Value.Settings.VideoBorrowMaxConcurrent);
        Assert.Equal(actorUserId, result.Value.Settings.UpdatedByAdminId);

        fixture.DbContext.ChangeTracker.Clear();
        var persisted = await fixture.DbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .SingleAsync(item => item.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId);
        Assert.Equal(2, persisted.Version);
        Assert.Equal("Approve production generation capacity", persisted.LastChangeReason);
        Assert.Equal(actorUserId, persisted.UpdatedByAdminId);

        var message = await fixture.DbContext.PushOutboxMessages
            .AsNoTracking()
            .SingleAsync(item => item.Kind == TemplateAdminAuditOutbox.Kind);
        Assert.Equal(PushOutboxStatus.Queued, message.Status);
        Assert.StartsWith("templates_admin_audit:", message.DeduplicationKey, StringComparison.Ordinal);

        var audit = TemplateAdminAuditOutbox.Deserialize(message.PayloadJson);
        Assert.Equal("templates.generation_control.updated", audit.Action);
        Assert.Equal("template_generation_runtime_settings", audit.TargetType);
        Assert.Equal(persisted.Id.ToString("D"), audit.TargetId);
        Assert.Equal("Approve production generation capacity", audit.Details);
        Assert.Equal(actorUserId, audit.ActorUserId);
        Assert.Equal("Admin", audit.ActorRole);
        Assert.Equal(command.CorrelationId, audit.CorrelationId);
        Assert.NotNull(audit.EventId);

        using var oldValue = JsonDocument.Parse(audit.OldValue!);
        using var newValue = JsonDocument.Parse(audit.NewValue!);
        Assert.Equal(1, oldValue.RootElement.GetProperty("version").GetInt64());
        Assert.Equal(2, newValue.RootElement.GetProperty("version").GetInt64());
        Assert.Equal(8, newValue.RootElement.GetProperty("globalMaxConcurrent").GetInt32());
    }

    [Fact]
    public async Task UpdateAsync_WithStaleExpectedVersion_ShouldReturnConflictWithoutOverwriteOrAudit()
    {
        await using var fixture = await ControlFixture.CreateAsync();
        var command = CreateTargetCommand(Guid.NewGuid()) with
        {
            ExpectedVersion = 2,
            GlobalMaxConcurrent = 6,
            ImageMaxConcurrent = 5
        };

        var result = await fixture.Service.UpdateAsync(command, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.generation_control_version_conflict", result.Error.Code);

        fixture.DbContext.ChangeTracker.Clear();
        var persisted = await fixture.DbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .SingleAsync(item => item.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId);
        Assert.Equal(1, persisted.Version);
        Assert.Equal(8, persisted.GlobalMaxConcurrent);
        Assert.Equal(7, persisted.ImageMaxConcurrent);
        Assert.Null(persisted.LastChangeReason);
        Assert.Null(persisted.UpdatedByAdminId);
        Assert.False(await fixture.DbContext.PushOutboxMessages
            .AsNoTracking()
            .AnyAsync(item => item.Kind == TemplateAdminAuditOutbox.Kind));
    }

    [Fact]
    public async Task UpdateAsync_ShouldRejectUnsafeTargetValuesBeforePersistence()
    {
        await using var fixture = await ControlFixture.CreateAsync();
        var target = CreateTargetCommand(Guid.NewGuid());
        var cases = new[]
        {
            (Command: target with { ExpectedVersion = 0 }, Field: "expectedVersion"),
            (Command: target with { GlobalMaxConcurrent = 9 }, Field: "falReservedConcurrency"),
            (Command: target with { ImageMaxConcurrent = 9 }, Field: "laneConcurrency"),
            (Command: target with { VideoGuaranteedConcurrent = 5 }, Field: "laneConcurrency"),
            (Command: target with { VideoBorrowMaxConcurrent = 1 }, Field: "laneConcurrency"),
            (Command: target with { WorkerLoopsPerInstance = 3 }, Field: "workerLoopsPerInstance"),
            (Command: target with { FalBalanceCriticalThresholdUsd = 11m }, Field: "falBalanceThresholds"),
            (Command: target with { Reason = "x" }, Field: "reason")
        };

        foreach (var testCase in cases)
        {
            var result = await fixture.Service.UpdateAsync(testCase.Command, CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.generation_control_invalid", result.Error.Code);
            Assert.Equal(testCase.Field, result.Error.Metadata!["field"]);
        }

        fixture.DbContext.ChangeTracker.Clear();
        var persisted = await fixture.DbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .SingleAsync(item => item.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId);
        Assert.Equal(1, persisted.Version);
        Assert.False(await fixture.DbContext.PushOutboxMessages
            .AsNoTracking()
            .AnyAsync(item => item.Kind == TemplateAdminAuditOutbox.Kind));
    }

    [Fact]
    public async Task GetAsync_WithFreshWorkerOnStaleRevision_ShouldExposeDegradedCapacityAndAlerts()
    {
        await using var fixture = await ControlFixture.CreateAsync();
        var now = DateTime.UtcNow;
        fixture.DbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
        {
            Id = Guid.NewGuid(),
            Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
            ProfileName = "production",
            Checksum = Guid.NewGuid().ToString("N"),
            ConfigJson = "{}",
            StartedAtUtc = now.AddMinutes(-1),
            LastSeenAtUtc = now,
            AppliedSettingsVersion = 0,
            ConfiguredLoops = 2,
            NewClaimsPaused = false
        });
        await fixture.DbContext.SaveChangesAsync();
        await fixture.AlertService.EvaluateAsync(CancellationToken.None);

        var result = await fixture.Service.GetAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("degraded", result.Value.Status.Health);
        Assert.Equal(8, result.Value.Settings.GlobalMaxConcurrent);
        var worker = Assert.Single(result.Value.Workers);
        Assert.False(worker.IsStale);
        Assert.False(worker.IsConfigCurrent);
        Assert.Equal(0, worker.AppliedSettingsVersion);
        Assert.Equal(2, worker.ConfiguredLoops);

        var revisionAlert = Assert.Single(
            result.Value.Alerts,
            alert => alert.Code == "runtime_config_not_applied" && alert.IsActive);
        Assert.Equal("warning", revisionAlert.Severity);
        var capacityAlert = Assert.Single(
            result.Value.Alerts,
            alert => alert.Code == "worker_capacity_insufficient" && alert.IsActive);
        Assert.Contains("2 loops", capacityAlert.Message, StringComparison.Ordinal);
        Assert.Contains("global limit of 8", capacityAlert.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task AcknowledgeAlertAsync_WhenAlertWasReactivated_ShouldReplaceStaleAcknowledgement()
    {
        await using var fixture = await ControlFixture.CreateAsync();
        var adminUserId = Guid.NewGuid();
        var oldActivation = DateTime.UtcNow.AddMinutes(-10);
        var currentActivation = DateTime.UtcNow.AddMinutes(-1);
        var alert = new TemplateGenerationOperationalAlert
        {
            Id = Guid.NewGuid(),
            Code = "test_reactivated_alert",
            Severity = "warning",
            Title = "Reactivated alert",
            Message = "Alert activation changed.",
            ActivatedAtUtc = currentActivation,
            LastObservedAtUtc = currentActivation,
            UpdatedAtUtc = currentActivation
        };
        fixture.DbContext.TemplateGenerationOperationalAlerts.Add(alert);
        fixture.DbContext.TemplateGenerationOperationalAlertAcknowledgements.Add(
            new TemplateGenerationOperationalAlertAcknowledgement
            {
                AlertId = alert.Id,
                AdminUserId = adminUserId,
                AlertActivatedAtUtc = oldActivation,
                AcknowledgedAtUtc = oldActivation
            });
        await fixture.DbContext.SaveChangesAsync();
        fixture.DbContext.ChangeTracker.Clear();

        var before = await fixture.Service.GetAsync(adminUserId, CancellationToken.None);

        Assert.True(before.IsSuccess);
        var unread = Assert.Single(before.Value.Alerts, item => item.Id == alert.Id);
        Assert.False(unread.IsAcknowledged);
        Assert.Null(unread.AcknowledgedAtUtc);

        var acknowledged = await fixture.Service.AcknowledgeAlertAsync(
            alert.Id,
            adminUserId,
            CancellationToken.None);

        Assert.True(acknowledged.IsSuccess);
        Assert.True(acknowledged.Value.IsAcknowledged);
        var persisted = await fixture.DbContext.TemplateGenerationOperationalAlertAcknowledgements
            .AsNoTracking()
            .SingleAsync(item => item.AlertId == alert.Id && item.AdminUserId == adminUserId);
        Assert.Equal(currentActivation, persisted.AlertActivatedAtUtc);
        Assert.True(persisted.AcknowledgedAtUtc > oldActivation);
    }

    [Fact]
    public async Task GetAsync_WhenStoppedRenderInstancesStillHaveFreshHeartbeats_ShouldCapObservedCapacity()
    {
        var renderClient = new FixedTopologyRenderClient(activeInstances: 1);
        await using var fixture = await ControlFixture.CreateAsync(renderClient);
        var now = DateTime.UtcNow;
        for (var index = 0; index < 4; index++)
        {
            fixture.DbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = "production",
                Checksum = Guid.NewGuid().ToString("N"),
                ConfigJson = "{}",
                StartedAtUtc = now.AddMinutes(-1),
                LastSeenAtUtc = now,
                AppliedSettingsVersion = 1,
                ConfiguredLoops = 2,
                NewClaimsPaused = false
            });
        }

        await fixture.DbContext.SaveChangesAsync();
        await fixture.AlertService.EvaluateAsync(CancellationToken.None);

        var result = await fixture.Service.GetAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("degraded", result.Value.Status.Health);
        Assert.Equal(1, result.Value.Render?.ActiveInstances);
        var capacityAlert = Assert.Single(
            result.Value.Alerts,
            alert => alert.Code == "worker_capacity_insufficient" && alert.IsActive);
        Assert.Contains("2 loops", capacityAlert.Message, StringComparison.Ordinal);
    }

    private static UpdateAdminGenerationControlCommand CreateTargetCommand(Guid actorUserId) => new(
        ExpectedVersion: 1,
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
        Reason: "Approve production generation capacity",
        ActorUserId: actorUserId,
        ActorRole: "Admin",
        CorrelationId: Guid.NewGuid().ToString("N"));

    private sealed class ControlFixture : IAsyncDisposable
    {
        private ControlFixture(
            SqliteConnection connection,
            TemplatesDbContext dbContext,
            DatabaseRuntimeSettingsProvider runtimeSettings,
            GenerationOperationalAlertService alertService,
            IRenderGenerationWorkerClient? renderClient)
        {
            Connection = connection;
            DbContext = dbContext;
            RuntimeSettings = runtimeSettings;
            AlertService = alertService;
            Service = new AdminGenerationControlService(
                dbContext,
                runtimeSettings,
                providerMonitor: null!,
                alertService,
                adminAuditLog: null,
                NullLogger<AdminGenerationControlService>.Instance,
                renderClient);
        }

        private SqliteConnection Connection { get; }

        public TemplatesDbContext DbContext { get; }

        public DatabaseRuntimeSettingsProvider RuntimeSettings { get; }

        public GenerationOperationalAlertService AlertService { get; }

        public AdminGenerationControlService Service { get; }

        public static async Task<ControlFixture> CreateAsync(
            IRenderGenerationWorkerClient? renderClient = null)
        {
            var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            var options = new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseSqlite(connection)
                .Options;
            var dbContext = new TemplatesDbContext(options);
            await dbContext.Database.EnsureCreatedAsync();

            var now = DateTime.UtcNow;
            dbContext.TemplateGenerationRuntimeSettings.Add(new TemplateGenerationRuntimeSettings
            {
                Id = TemplateGenerationRuntimeSettingsProvider.SettingsId,
                Version = 1,
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
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
            dbContext.TemplateFalProviderHealthSnapshots.Add(new TemplateFalProviderHealthSnapshot
            {
                Id = FalProviderHealthMonitor.SnapshotId,
                BalanceUsd = 20m,
                Status = "healthy",
                CheckedAtUtc = now,
                LastSuccessAtUtc = now,
                UpdatedAtUtc = now
            });
            await dbContext.SaveChangesAsync();
            dbContext.ChangeTracker.Clear();

            var runtimeSettings = new DatabaseRuntimeSettingsProvider(dbContext);
            await runtimeSettings.RefreshAsync(CancellationToken.None);
            var alertService = new GenerationOperationalAlertService(dbContext, runtimeSettings, renderClient);
            return new ControlFixture(connection, dbContext, runtimeSettings, alertService, renderClient);
        }

        public async ValueTask DisposeAsync()
        {
            await DbContext.DisposeAsync();
            await Connection.DisposeAsync();
        }
    }

    private sealed class FixedTopologyRenderClient(int activeInstances) : IRenderGenerationWorkerClient
    {
        public bool IsConfigured => true;

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
                    activeInstances,
                    false)));

        public Task<Result<IReadOnlyList<RenderGenerationWorkerInstance>>> ListInstancesAsync(
            CancellationToken cancellationToken) => Task.FromResult(Result.Success<IReadOnlyList<RenderGenerationWorkerInstance>>(
                Enumerable.Range(0, activeInstances)
                    .Select(index => new RenderGenerationWorkerInstance($"instance-{index}", DateTime.UtcNow))
                    .ToArray()));

        public Task<Result<RenderScaleAccepted>> ScaleAsync(
            int targetInstances,
            CancellationToken cancellationToken) => throw new NotSupportedException();
    }

    private sealed class DatabaseRuntimeSettingsProvider(TemplatesDbContext dbContext)
        : ITemplateGenerationRuntimeSettingsProvider
    {
        public TemplateGenerationRuntimeSnapshot Current { get; private set; } = null!;

        public async Task RefreshAsync(CancellationToken cancellationToken)
        {
            var row = await dbContext.TemplateGenerationRuntimeSettings
                .AsNoTracking()
                .SingleAsync(
                    item => item.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId,
                    cancellationToken);
            Current = new TemplateGenerationRuntimeSnapshot(
                row.Version,
                row.GlobalMaxConcurrent,
                row.ImageMaxConcurrent,
                row.ImageProtectedConcurrent,
                row.VideoGuaranteedConcurrent,
                row.VideoMaxConcurrent,
                row.VideoBorrowMaxConcurrent,
                row.WorkerLoopsPerInstance,
                row.FalConfiguredConcurrency,
                row.FalReservedConcurrency,
                row.FalBalanceLowThresholdUsd,
                row.FalBalanceCriticalThresholdUsd,
                row.NewClaimsPaused,
                row.DrainOperationId,
                row.UpdatedAtUtc);
        }
    }
}

public sealed class AdminGenerationControlEndpointSecurityTests
{
    [Fact]
    public void GenerationControlEndpoints_ShouldRemainAdminOnlyAndNoStore()
    {
        var source = File.ReadAllText(Path.Combine(
                FindRepositoryRoot(),
                "src",
                "Modules",
                "Templates",
                "PetMagic.Modules.Templates.Api",
                "Endpoints",
                "AdminTemplateEndpoints.cs"))
            .Replace("\r\n", "\n", StringComparison.Ordinal);
        var routes = new[]
        {
            "group.MapGet(\"/generation-control\", GetGenerationControlAsync)",
            "group.MapPut(\"/generation-control\", UpdateGenerationControlAsync)",
            "group.MapPost(\"/generation-control/provider/refresh\", RefreshGenerationProviderAsync)",
            "group.MapPost(\"/generation-control/alerts/{alertId:guid}/acknowledge\", AcknowledgeGenerationAlertAsync)",
            "group.MapPost(\"/generation-control/render/scale\", RequestGenerationWorkerScaleAsync)",
            "group.MapGet(\"/generation-control/render/operations/{operationId:guid}\", GetGenerationWorkerScaleOperationAsync)",
            "group.MapPost(\"/generation-control/render/operations/{operationId:guid}/cancel\", CancelGenerationWorkerScaleOperationAsync)"
        };

        foreach (var route in routes)
        {
            var routeStart = source.IndexOf(route, StringComparison.Ordinal);
            Assert.True(routeStart >= 0, $"Missing generation-control route: {route}");
            var routeTerminator = source.IndexOf(';', routeStart);
            Assert.True(routeTerminator > routeStart, $"Incomplete generation-control route: {route}");
            var routeRegistration = source[routeStart..(routeTerminator + 1)];
            Assert.Contains(".RequireAuthorization(\"AdminOnly\")", routeRegistration, StringComparison.Ordinal);
        }

        Assert.Contains(
            ".AddEndpointFilter(ApplyPrivateAdminTemplateResponseHeadersAsync)",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "context.HttpContext.Response.Headers.CacheControl = \"no-store\";",
            source,
            StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName
            ?? throw new DirectoryNotFoundException("Could not locate the PetMagic repository root.");
    }
}
